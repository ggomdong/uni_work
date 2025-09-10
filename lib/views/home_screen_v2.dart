import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../utils.dart';
import '../constants/gaps.dart';
import '../views/widgets/common_app_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool beaconDetected = true; // 비콘 인식 여부

  bool isCheckedIn = false; // 출근 여부
  TimeOfDay? checkInTime;
  TimeOfDay? checkOutTime;

  bool _pressed = false; // 버튼 눌림 여부

  void _confirmCheckInOut() {
    showCupertinoDialog(
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
            title: Text(isCheckedIn ? "퇴근하시겠어요?" : "출근하시겠어요?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("취소"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    final now = TimeOfDay.now();
                    if (!isCheckedIn) {
                      checkInTime = now;
                      isCheckedIn = true;
                    } else {
                      checkOutTime = now;
                      isCheckedIn = false;
                    }
                  });
                },
                child: const Text("확인"),
              ),
            ],
          ),
    );
  }

  double calculateWorkProgress() {
    final now = TimeOfDay.now();
    final currentMinutes = now.hour * 60 + now.minute;
    const workStart = 9 * 60 + 30;
    const workEnd = 17 * 60;
    final total = workEnd - workStart;

    if (currentMinutes <= workStart) return 0.0;
    if (currentMinutes >= workEnd) return 1.0;
    return (currentMinutes - workStart) / total;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    if (beaconDetected) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final now = TimeOfDay.now();
    final today = DateFormat('yyyy년 M월 d일 (E)', 'ko_KR').format(DateTime.now());
    const schedule = "09:30 ~ 17:00";
    final progress = calculateWorkProgress();

    const notice = "[공지] 6월 3일은 점심시간이 13시로 조정됩니다.";

    return Scaffold(
      appBar: CommonAppBar(),
      body:
          beaconDetected
              ? AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CustomPaint(
                    painter: AirflowBackgroundPainter(animation: _controller),
                    child: child,
                  );
                },
                child: contentBody(
                  primaryColor,
                  today,
                  now,
                  schedule,
                  progress,
                  notice,
                ),
              )
              : contentBody(
                primaryColor,
                today,
                now,
                schedule,
                progress,
                notice,
              ),
    );
  }

  Widget contentBody(
    Color primaryColor,
    String today,
    TimeOfDay now,
    String schedule,
    double progress,
    String notice,
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
                  "📅 $today",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Gaps.h20,
                Text(
                  "🕒 $schedule",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            Gaps.v10,
            const Text(
              "💆🏻‍♀️ 안녕하세요, 김솔잎님",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Gaps.v8,
            const Text(
              "오늘도 행복한 하루 되세요!",
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapUp: (_) {
                    setState(() => _pressed = false);
                    triggerHaptic(context);
                    _confirmCheckInOut();
                  },
                  onTapCancel: () => setState(() => _pressed = false),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const SweepGradient(
                        startAngle: 0,
                        endAngle: 3.14 * 2,
                        colors: [
                          Color(0xFFF0F0F0), // 밝은 메탈
                          Color(0xFFD0D0D0), // 중간톤
                          Color(0xFFA0A0A0), // 그림자
                          Color(0xFFF0F0F0), // 다시 밝은 메탈
                        ],
                        stops: [0.0, 0.5, 0.8, 1.0],
                        transform: GradientRotation(0.8), // 반사광 방향 조정
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.white,
                          offset: Offset(-2, -2),
                          blurRadius: 4,
                        ),
                        BoxShadow(
                          color: Color(0xFFB0B0B0),
                          offset: Offset(3, 3),
                          blurRadius: 8,
                        ),
                      ],
                    ),

                    child: Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors:
                                _pressed
                                    ? [
                                      Color(0xFFBBBBBB), // 중심 회색
                                      Color(0xFFEEEEEE), // 외곽 밝게
                                      Color(0xFFFFFFFF), // 하이라이트 테두리
                                    ]
                                    : [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFE0E0E0),
                                      Color(0xFFCACACA),
                                    ],
                            stops:
                                _pressed ? [0.3, 0.85, 1.0] : [0.6, 0.85, 1.0],
                            center: Alignment.topLeft,
                            radius: 1.2,
                          ),
                          border:
                              _pressed
                                  ? Border.all(
                                    color: Color(0xFFAAAAAA), // 외곽 테두리 살짝 진하게
                                    width: 1,
                                  )
                                  : null,
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
                                isCheckedIn ? "퇴근하기" : "출근하기",
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
                ),
              ),
            ),
            // Expanded(
            //   child: Center(
            //     child: Container(
            //       width: 260,
            //       height: 260,
            //       decoration: BoxDecoration(
            //         gradient: RadialGradient(
            //           colors: [Colors.white, Colors.grey.shade100],
            //           center: Alignment.topLeft,
            //           radius: 1.2,
            //         ),
            //         shape: BoxShape.circle,
            //         boxShadow: [
            //           BoxShadow(
            //             color: Colors.white.withValues(alpha: 0.6),
            //             blurRadius: 30,
            //             spreadRadius: -10,
            //             offset: const Offset(-10, -10),
            //           ),
            //           BoxShadow(
            //             color: Colors.black.withValues(alpha: 0.1),
            //             blurRadius: 30,
            //             spreadRadius: -5,
            //             offset: const Offset(10, 10),
            //           ),
            //         ],
            //       ),
            //       child: CustomPaint(
            //         painter: DonutProgressPainter(progress, primaryColor),
            //         child: Center(
            //           child: Column(
            //             mainAxisSize: MainAxisSize.min,
            //             children: [
            //               Icon(
            //                 Icons.local_hospital,
            //                 size: 50,
            //                 color: primaryColor,
            //               ),
            //               Gaps.v8,
            //               Text(
            //                 now.format(context),
            //                 style: const TextStyle(
            //                   fontSize: 32,
            //                   fontWeight: FontWeight.bold,
            //                   color: Colors.black,
            //                 ),
            //               ),
            //               Gaps.v6,
            //               const Text(
            //                 "근무 중",
            //                 style: TextStyle(fontSize: 16, color: Colors.grey),
            //               ),
            //             ],
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
            // ),
            // Text("🕒 오늘 근무시간: $schedule", style: const TextStyle(fontSize: 16)),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            //   decoration: BoxDecoration(
            //     color: Colors.white.withValues(alpha: 0.9),
            //     borderRadius: BorderRadius.circular(16),
            //     boxShadow: [
            //       BoxShadow(
            //         color: Colors.black12,
            //         blurRadius: 8,
            //         offset: Offset(0, 4),
            //       ),
            //     ],
            //   ),
            //   child: Row(
            //     children: [
            //       const Icon(Icons.campaign, color: Colors.teal),
            //       Gaps.v12,
            //       Expanded(
            //         child: Text(
            //           notice,
            //           style: const TextStyle(
            //             fontSize: 14,
            //             fontWeight: FontWeight.w500,
            //           ),
            //           overflow: TextOverflow.ellipsis,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class DonutProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  DonutProgressPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 16.0;
    final radius = size.width / 2;

    final backgroundPaint =
        Paint()
          ..color = Colors.grey.shade200
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final foregroundPaint =
        Paint()
          ..shader = SweepGradient(
            startAngle: -pi / 2,
            endAngle: 3 * pi / 2,
            colors: [
              color.withValues(alpha: 0.4),
              color,
              color.withValues(alpha: 0.4),
            ],
            stops: [0.0, 0.5, 1.0],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: radius,
            ),
          )
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );
    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;

    canvas.drawCircle(center, radius - strokeWidth / 2, backgroundPaint);
    canvas.drawArc(rect, startAngle, sweepAngle, false, foregroundPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
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
