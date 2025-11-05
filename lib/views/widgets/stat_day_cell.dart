import 'package:flutter/material.dart';

/// 점(밑점)에서 제외할 상태
const Set<String> kDotExcluded = {"NOSCHEDULE"};

/// 표시 순서(칩/점 공통)
const List<String> kStatusOrder = [
  "ERROR",
  "HOLIDAY",
  "LATE",
  "EARLY",
  "OVERTIME",
  "PAY",
  "NOPAY",
  "OFF",
  "NOSCHEDULE",
  "NORMAL",
];

class StatDayCell extends StatelessWidget {
  final DateTime day;
  final bool isToday;
  final bool isSelected;
  final List<String> statusCodes; // 그대로 보여줄 코드들
  final Color Function(BuildContext, String?) resolveStatusColor;

  const StatDayCell({
    super.key,
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.statusCodes,
    required this.resolveStatusColor,
  });

  @override
  Widget build(BuildContext context) {
    // 점에 표시할 코드: OFF/PAY/NOPAY 제외 + 순서 정렬
    final dotCodes =
        statusCodes.where((c) => !kDotExcluded.contains(c)).toList()..sort(
          (a, b) => kStatusOrder.indexOf(a).compareTo(kStatusOrder.indexOf(b)),
        );

    // 최대 3개 + 나머지는 "+n"
    const int maxDots = 3;
    final int overflow =
        dotCodes.length > maxDots ? dotCodes.length - maxDots : 0;
    final List<String> visibleDots = dotCodes
        .take(maxDots)
        .toList(growable: false);

    final borderColor =
        isSelected
            ? Colors
                .red // 선택일: 빨강
            : (isToday ? Colors.blue : Colors.grey.shade300); // 오늘: 파랑, 일반: 회색

    final borderWidth = isSelected ? 1.2 : (isToday ? 1.0 : 0.5);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: borderColor, // 조건부 색
          width: borderWidth, // 조건부 두께
        ),
        borderRadius: BorderRadius.circular(8), // 모서리 유지(있으면)
      ),
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 날짜
          Positioned(
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(6),
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),

          // 점 표시(복합 상태: 여러 점, OFF/PAY/NOPAY 제외, 크기/위치 고정)
          if (visibleDots.isNotEmpty || overflow > 0)
            Positioned(
              bottom: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...visibleDots.map(
                    (code) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: resolveStatusColor(context, code),
                      ),
                    ),
                  ),
                  if (overflow > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        '+$overflow',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
