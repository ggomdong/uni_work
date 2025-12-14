import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../view_models/beacon_view_model.dart';
import '../view_models/attendance_view_model.dart';
import './widgets/common_app_bar.dart';
import './widgets/work_time_card.dart';
import '../utils.dart';
import '../constants/gaps.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _airflowController;

  BeaconNotifier? _beaconNotifier;

  bool isCheckedIn = false; // 출근 여부
  bool isEarlyCheckout = true; // 조퇴 여부
  bool hasTime = false; // 근무일 여부

  bool _canRefresh = true;

  void _onRefreshTap() {
    if (!_canRefresh) return;

    setState(() {
      _canRefresh = false;
    });

    _refresh();

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _canRefresh = true;
        });
      }
    });
  }

  void _confirmCheckInOut() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        DateTime displayTime = DateTime.now();
        late Timer timer;

        Widget getDialogContent() {
          if (!isCheckedIn && !hasTime) {
            return RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1, // 줄 간격 조절 (선택)
                ),
                children: [
                  TextSpan(
                    text: "근무일이 아닙니다!\n\n", // 줄바꿈 2번 = 한 줄 띄움
                    style: TextStyle(color: Colors.red),
                  ),
                  TextSpan(text: "그래도 출근 하시겠습니까?"),
                ],
              ),
            );
          } else {
            return Text(
              !isCheckedIn
                  ? "출근 하시겠습니까?"
                  : isEarlyCheckout
                  ? "조퇴 하시겠습니까?"
                  : "연장근무 후 퇴근하시겠습니까?",
            );
          }
        }

        return StatefulBuilder(
          builder: (context, setState) {
            timer = Timer.periodic(const Duration(seconds: 1), (_) {
              if (context.mounted) {
                setState(() {
                  displayTime = DateTime.now();
                });
              }
            });

            return CupertinoAlertDialog(
              title: Text(DateFormat('HH:mm:ss').format(displayTime)),
              content: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: getDialogContent(),
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text("취소"),
                  onPressed: () {
                    timer.cancel();
                    Navigator.of(context).pop();
                  },
                ),
                CupertinoDialogAction(
                  child: const Text("확인"),
                  onPressed: () {
                    timer.cancel();
                    Navigator.of(context).pop();
                    ref.read(attendanceProvider.notifier).submitWork();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _refresh() {
    ref.read(attendanceProvider.notifier).refresh();
  }

  @override
  void initState() {
    super.initState();
    _airflowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _beaconNotifier = ref.read(beaconProvider.notifier);
      _beaconNotifier!.addListenerRef();
    });

    // if (beaconDetected) {
    //   _airflowController.repeat();
    // }
  }

  @override
  void dispose() {
    _beaconNotifier?.removeListenerRef();
    _airflowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    const notice = "[공지] 유앤아이 근태관리 앱이 오픈되었습니다.";
    final attendance = ref.watch(attendanceProvider);

    final beaconDetected = ref.watch(isBeaconDetectedProvider);
    // final beaconDetected = true;
    final beacons = ref.watch(beaconListProvider);
    final beaconError = ref.watch(beaconErrorProvider);

    // 서버에서 내려온 "비콘 우회 권한" 여부 (없으면 false)
    final canBypassBeacon = attendance.value?.canBypassBeacon ?? false;

    // 실제 비콘이 잡히거나, 우회 권한이 있으면 true
    final effectiveBeacon = beaconDetected || canBypassBeacon;

    // 비콘 감지 상태에 따라 애니메이션 제어
    if (effectiveBeacon && !_airflowController.isAnimating) {
      _airflowController.repeat();
    } else if (!effectiveBeacon && _airflowController.isAnimating) {
      _airflowController.stop();
    }

    return attendance.when(
      data: (data) {
        final today = DateTime.now();
        // final today = DateTime.parse('2025-12-05');

        final workStart = data.workStart; // "HH:mm" 또는 null
        final workEnd = data.workEnd; // "HH:mm" 또는 null
        final moduleCat =
            data.moduleCat; // ex) "소정근로", "휴일근로", "유급휴무", "무급휴무", "OFF"
        final moduleName =
            data.moduleName; // ex) "연차", "경조휴가", "공가", "결근", "병가", "무급휴가" 등

        // 1) 근무일인지 판단
        String schedule;
        hasTime =
            workStart != null &&
            workEnd != null &&
            workStart.isNotEmpty &&
            workEnd.isNotEmpty;

        if (hasTime) {
          // 예: "정규근무 09:00 ~ 18:00"
          if (moduleCat != null && moduleCat.isNotEmpty) {
            schedule = "$moduleCat($workStart ~ $workEnd)";
          } else {
            // cat이 혹시 없으면 기존 형식으로 fallback
            schedule = "$workStart ~ $workEnd";
          }
        } else {
          // 2) 시간이 없는 날: cat + name
          if (moduleCat != null && moduleCat.isNotEmpty) {
            if (moduleCat == 'OFF') {
              schedule = moduleCat;
            } else if (moduleName != null && moduleName.isNotEmpty) {
              // 예: "유급휴무 (연차)", "무급휴무 (병가)"
              schedule = "$moduleCat($moduleName)";
            } else {
              // 이름이 없으면 cat만
              schedule = moduleCat;
            }
          } else {
            // 3) 모듈 자체가 없는 완전한 무스케줄: 기존 메시지 유지
            schedule = "(근무 스케쥴 없음)";
          }
        }

        final empName = data.empName;
        final checkinTime = data.checkinTime;
        final checkoutTime = data.checkoutTime;

        isCheckedIn = data.checkinTime != null;
        isEarlyCheckout = data.isEarlyCheckout;

        final content = contentBody(
          primaryColor,
          today,
          schedule,
          empName,
          notice,
          isEarlyCheckout,
          checkinTime,
          checkoutTime,
          effectiveBeacon,
          beacons,
          beaconError,
        );

        return Scaffold(
          appBar: CommonAppBar(
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  effectiveBeacon
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: effectiveBeacon ? Colors.green : Colors.grey,
                ),
              ),
              IconButton(
                tooltip: "새로고침",
                onPressed: _onRefreshTap,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          body:
              effectiveBeacon
                  ? AnimatedBuilder(
                    animation: _airflowController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: AirflowBackgroundPainter(
                          animation: _airflowController,
                        ),
                        child: child,
                      );
                    },
                    child: content,
                  )
                  : content,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text("오류 발생: $e")),
    );
  }

  Widget contentBody(
    Color primaryColor,
    DateTime today,
    String schedule,
    String empName,
    String notice,
    bool isEarlyCheckout,
    DateTime? checkinTime,
    DateTime? checkoutTime,
    bool effectiveBeacon,
    List beacons,
    String? beaconError,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Gaps.v20,
            Row(
              children: [
                Text(
                  DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(today),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Gaps.h12,
                Text(
                  schedule,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Gaps.h12,
              ],
            ),
            Gaps.v10,
            Text(
              "안녕하세요, $empName님",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Gaps.v20,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.campaign, color: Colors.teal),
                  Gaps.v12,
                  Expanded(
                    child: Text(
                      notice,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // 감지된 비콘 디버그 패널 (UUID/major/minor/거리)
            // if (beacons.isNotEmpty)
            //   Container(
            //     margin: const EdgeInsets.only(top: 12),
            //     padding: const EdgeInsets.all(12),
            //     decoration: BoxDecoration(
            //       color: Colors.white,
            //       borderRadius: BorderRadius.circular(12),
            //       boxShadow: const [
            //         BoxShadow(
            //           color: Colors.black12,
            //           blurRadius: 6,
            //           offset: Offset(0, 3),
            //         ),
            //       ],
            //     ),
            //     child: Column(
            //       crossAxisAlignment: CrossAxisAlignment.start,
            //       children: [
            //         Text(
            //           "감지된 비콘 (${beacons.length})",
            //           style: const TextStyle(
            //             fontSize: 13,
            //             fontWeight: FontWeight.w700,
            //           ),
            //         ),
            //         const SizedBox(height: 8),
            //         // 높이가 너무 커지지 않게 제한
            //         ConstrainedBox(
            //           constraints: const BoxConstraints(maxHeight: 160),
            //           child: ListView.separated(
            //             shrinkWrap: true,
            //             itemCount: beacons.length,
            //             separatorBuilder: (_, __) => const SizedBox(height: 6),
            //             itemBuilder: (_, i) {
            //               final b = beacons[i];
            //               final uuid = b.proximityUUID ?? "-";
            //               final major = b.major?.toString() ?? "-";
            //               final minor = b.minor?.toString() ?? "-";
            //               final rssi = b.rssi?.toString() ?? "-";
            //               final acc = _formatMeters(b.accuracy);

            //               return Container(
            //                 padding: const EdgeInsets.symmetric(
            //                   horizontal: 10,
            //                   vertical: 8,
            //                 ),
            //                 decoration: BoxDecoration(
            //                   color: const Color(0xFFF7F9FA),
            //                   borderRadius: BorderRadius.circular(10),
            //                   border: Border.all(
            //                     color: const Color(0xFFE6EAED),
            //                   ),
            //                 ),
            //                 child: Row(
            //                   children: [
            //                     // 좌측: UUID 요약 (길면 축약 표시)
            //                     Expanded(
            //                       child: Column(
            //                         crossAxisAlignment:
            //                             CrossAxisAlignment.start,
            //                         children: [
            //                           SelectableText(
            //                             uuid, // 전체 복사도 가능하게
            //                             style: const TextStyle(
            //                               fontSize: 12,
            //                               fontWeight: FontWeight.w600,
            //                             ),
            //                           ),
            //                           const SizedBox(height: 2),
            //                           Text(
            //                             "Major/Minor  $major / $minor",
            //                             style: const TextStyle(
            //                               fontSize: 11,
            //                               color: Colors.black54,
            //                             ),
            //                           ),
            //                         ],
            //                       ),
            //                     ),
            //                     const SizedBox(width: 8),
            //                     // 우측: 거리/RSSI
            //                     Column(
            //                       crossAxisAlignment: CrossAxisAlignment.end,
            //                       children: [
            //                         Text(
            //                           "거리 $acc",
            //                           style: const TextStyle(fontSize: 11),
            //                         ),
            //                         Text(
            //                           "RSSI $rssi dBm",
            //                           style: const TextStyle(
            //                             fontSize: 11,
            //                             color: Colors.black54,
            //                           ),
            //                         ),
            //                       ],
            //                     ),
            //                     const SizedBox(width: 6),
            //                     // 복사 버튼 (UUID 복사)
            //                     IconButton(
            //                       icon: const Icon(Icons.copy, size: 18),
            //                       onPressed: () async {
            //                         await Clipboard.setData(
            //                           ClipboardData(text: uuid),
            //                         );
            //                         if (context.mounted) {
            //                           ScaffoldMessenger.of(
            //                             context,
            //                           ).showSnackBar(
            //                             const SnackBar(
            //                               content: Text("UUID 복사됨"),
            //                             ),
            //                           );
            //                         }
            //                       },
            //                       tooltip: "UUID 복사",
            //                     ),
            //                   ],
            //                 ),
            //               );
            //             },
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            Gaps.v12,
            if (beaconError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC5B8)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_off, color: Color(0xFFD95C36)),
                    Gaps.h12,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "비콘 인식을 위해\n위치/블루투스 권한이 필요해요",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8A3A21),
                            ),
                          ),
                          Text(
                            "권한 설정 후 앱을 재시작해주세요.", // BeaconNotifier에서 내려준 에러 메시지
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.redAccent,
                            ),
                          ),
                          // Gaps.v4,
                          // Text(
                          //   beaconError, // BeaconNotifier에서 내려준 에러 메시지
                          //   style: const TextStyle(
                          //     fontSize: 12,
                          //     color: Color(0xFF8A3A21),
                          //   ),
                          // ),
                        ],
                      ),
                    ),
                    Gaps.h12,
                    TextButton(
                      onPressed: () async {
                        // 앱 권한 설정 화면으로 바로 이동
                        await openAppSettings();
                      },
                      child: const Text(
                        "권한 설정",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Expanded(
              child: Center(
                child:
                    (!hasTime && isCheckedIn)
                        // 1) 근무일 아님 + 출근 상태 → 메시지 카드
                        ? ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 12,
                                  offset: Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: primaryColor.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 아이콘 + 타이틀
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: primaryColor.withValues(
                                          alpha: 0.12,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: primaryColor,
                                      ),
                                    ),
                                    Gaps.h8,
                                    const Text(
                                      "근무표 변경 필요",
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                Gaps.v12,
                                // 본문 설명
                                const Text(
                                  "오늘은 근무일로 등록되어 있지 않습니다.\n"
                                  "관리자에게 근무표 수정을 요청해 주세요.",
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Colors.black54,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                Gaps.v16,
                                // 하단 태그 느낌 안내
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    "근무표 수정 후 퇴근 처리가 가능합니다.",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.redAccent,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        // 2) 그 외 → 기존 버튼 유지
                        : Stack(
                          alignment: Alignment.center,
                          children: [
                            GestureDetector(
                              onTapUp:
                                  effectiveBeacon
                                      ? (_) {
                                        triggerHaptic(context);
                                        _refresh();
                                        _confirmCheckInOut();
                                      }
                                      : null,
                              child: Opacity(
                                opacity: effectiveBeacon ? 1.0 : 0.5,
                                child: Container(
                                  width: 130,
                                  height: 130,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCheckedIn
                                              ? Icons.night_shelter
                                              : Icons.local_hospital,
                                          size: 36,
                                          color:
                                              isCheckedIn
                                                  ? Color(0xFFFF6B57)
                                                  : Color(0xFF02B3BB),
                                        ),
                                        Gaps.v4,
                                        Text(
                                          isCheckedIn
                                              ? isEarlyCheckout
                                                  ? "조퇴하기"
                                                  : "연장근무 후 퇴근"
                                              : "출근하기",
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                isCheckedIn
                                                    ? Color(0xFFB24030)
                                                    : Color(0xFF007B80),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
            ),
            // 바이패스 권한 있는 경우, 비콘 거리 / RSSI 간단 표시
            if (effectiveBeacon && beacons.isNotEmpty)
              _buildBeaconInfoRow(beacons),
            WorkTimeCard(checkinTime: checkinTime, checkoutTime: checkoutTime),
            // Flexible(
            //   child: Align(
            //     alignment: Alignment.bottomCenter,
            //     child: WorkTimeCard(
            //       checkinTime: checkinTime,
            //       checkoutTime: checkoutTime,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  /// 비콘 디버그 정보
  Widget _buildBeaconInfoRow(List beacons) {
    if (beacons.isEmpty) return const SizedBox.shrink();

    // 가장 가까운 비콘 하나만 기준으로 사용
    final sorted = [...beacons];
    sorted.sort((a, b) => a.accuracy.compareTo(b.accuracy));
    final nearest = sorted.first;

    String formatMeters(double accuracy) {
      if (accuracy <= 0) return '-';
      if (accuracy < 1) {
        return '${(accuracy * 100).toStringAsFixed(0)} cm';
      }
      return '${accuracy.toStringAsFixed(1)} m';
    }

    final distanceLabel = formatMeters(nearest.accuracy);
    final rssiLabel = '${nearest.rssi} dBm';

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.bluetooth_searching,
            size: 14,
            color: Colors.black38,
          ),
          Gaps.h16,
          Text(
            '최단거리 $distanceLabel · RSSI $rssiLabel',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class AirflowBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  AirflowBackgroundPainter({required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color.fromARGB(30, 2, 179, 187);
    final path = Path();

    final waveHeight = 40;
    final speed = animation.value * 2 * pi;
    final yOffset = size.height * 0.4;

    path.moveTo(0, yOffset);
    for (double x = 0; x <= size.width; x++) {
      final y = yOffset + sin((x / size.width * 2 * pi) + speed) * waveHeight;
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
