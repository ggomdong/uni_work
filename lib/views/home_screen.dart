import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
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

  // late final Ticker _progressTicker;
  // final ValueNotifier<double> progressNotifier = ValueNotifier(0.0);

  bool beaconDetected = true; // 비콘 인식 여부
  bool isCheckedIn = false; // 출근 여부
  bool isEarlyCheckout = true; // 조퇴여부
  TimeOfDay? workEnd;
  Timer? _statusChecker;

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
          if (!isCheckedIn && workEnd == null) {
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

  void _startCheckoutStatusChecker() {
    _statusChecker?.cancel();

    _statusChecker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!isCheckedIn || !mounted || workEnd == null) return;

      final now = TimeOfDay.now();
      final nowMinutes = now.hour * 60 + now.minute;
      final endMinutes = workEnd!.hour * 60 + workEnd!.minute;

      final newStatus = nowMinutes < endMinutes;

      if (newStatus != isEarlyCheckout) {
        setState(() {
          isEarlyCheckout = newStatus;
        });
      }
    });
  }

  void _refresh() {
    ref.read(attendanceProvider.notifier).refresh();
  }

  // double calculateWorkProgress() {
  //   if (checkInTime == null) return 0.0;

  //   final workStartMinutes = workStart.hour * 60 + workStart.minute;
  //   final workEndMinutes = workEnd.hour * 60 + workEnd.minute;
  //   final totalWorkDuration = workEndMinutes - workStartMinutes;

  //   final checkInMinutes = checkInTime!.hour * 60 + checkInTime!.minute;

  //   // 퇴근했으면 현재 시간을 퇴근 시간으로 고정
  //   final now = TimeOfDay.now();
  //   final nowMinutes =
  //       checkOutTime != null
  //           ? checkOutTime!.hour * 60 + checkOutTime!.minute
  //           : now.hour * 60 + now.minute;

  //   // 퇴근 시간이 근무 종료보다 늦어도 최대값은 1.0
  //   if (nowMinutes <= workStartMinutes) return 0.0;
  //   if (nowMinutes >= workEndMinutes) return 1.0;

  //   // 정시 출근 또는 조기 출근
  //   if (checkInMinutes <= workStartMinutes) {
  //     return (nowMinutes - workStartMinutes) / totalWorkDuration;
  //   }

  //   // 지각 출근한 경우
  //   final adjustedDuration = workEndMinutes - checkInMinutes;
  //   final adjustedProgress = (nowMinutes - checkInMinutes) / adjustedDuration;

  //   return adjustedProgress.clamp(0.0, 1.0);
  // }

  @override
  void initState() {
    super.initState();
    _airflowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (beaconDetected) {
      _airflowController.repeat();
    }

    // _progressTicker = createTicker((_) {
    //   if (checkInTime != null && checkOutTime == null) {
    //     final newProgress = calculateWorkProgress();
    //     if ((newProgress - progressNotifier.value).abs() > 0.001) {
    //       progressNotifier.value = newProgress;
    //     }
    //   }
    // });

    // _progressTicker.start();
  }

  @override
  void dispose() {
    _airflowController.dispose();
    _statusChecker?.cancel();
    // _progressTicker.dispose();
    // progressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final progress = 0.0;
    const notice = "[공지] YOU&I 근태관리 앱이 오픈되었습니다.";
    final attendance = ref.watch(attendanceProvider);

    return attendance.when(
      data: (data) {
        final today = DateTime.now();
        // final today = DateTime.parse('2025-08-06');
        final schedule =
            (data.workStart == null && data.workEnd == null)
                ? '근무 OFF'
                : "${data.workStart} ~ ${data.workEnd}";
        final empName = data.empName;
        final checkinTime = data.checkinTime;
        final checkoutTime = data.checkoutTime;

        isCheckedIn = data.checkinTime != null;
        isEarlyCheckout = data.isEarlyCheckout;
        workEnd =
            (data.workEnd != null && data.workEnd!.isNotEmpty)
                ? parseTimeOfDay(data.workEnd!)
                : null;
        // 출근했고, 근무스케쥴(종료시간)이 등록되어 있으면 조퇴/연장근무 판단을 위해 지속적인 갱신 수행
        // 가급적 백엔드에 부담을 주는 작업은 지양하기 위해 일단 보류
        // if (isCheckedIn && workEnd != null) {
        //   _startCheckoutStatusChecker();
        // }

        final content = contentBody(
          primaryColor,
          today,
          schedule,
          empName,
          progress,
          notice,
          isEarlyCheckout,
          checkinTime,
          checkoutTime,
        );

        return Scaffold(
          appBar: CommonAppBar(),
          body:
              beaconDetected
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
    double progress,
    String notice,
    bool isEarlyCheckout,
    DateTime? checkinTime,
    DateTime? checkoutTime,
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
                GestureDetector(
                  onTap: _canRefresh ? _onRefreshTap : null,
                  child: Opacity(
                    opacity: _canRefresh ? 1.0 : 0.4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor,
                      ),
                      child: const Icon(
                        Icons.refresh_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
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
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // if (isCheckedIn)
                    //   SizedBox(
                    //     width: 160,
                    //     height: 160,
                    //     child: ValueListenableBuilder<double>(
                    //       valueListenable: progressNotifier,
                    //       builder: (context, progress, _) {
                    //         return CustomPaint(
                    //           painter: DonutProgressPainter(
                    //             progress,
                    //             primaryColor,
                    //           ),
                    //         );
                    //       },
                    //     ),
                    //   ),
                    GestureDetector(
                      onTapUp: (_) {
                        triggerHaptic(context);
                        _refresh();
                        _confirmCheckInOut();
                      },
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
                  ],
                ),
              ),
            ),
            WorkTimeCard(checkinTime: checkinTime, checkoutTime: checkoutTime),
          ],
        ),
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

class DonutProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  DonutProgressPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 16.0;
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // 배경 원
    final backgroundPaint =
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    // 진행 원
    final foregroundPaint =
        Paint()
          ..color =
              color // 단색
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round; // 둥글게 끝남

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final startAngle = -pi / 2; // 12시 방향
    final sweepAngle = 2 * pi * progress;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(covariant DonutProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
