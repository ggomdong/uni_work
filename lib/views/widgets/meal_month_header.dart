import 'package:flutter/material.dart';
import '../../constants/gaps.dart';
import '../../utils/meal_utils.dart';

class MealMonthHeader extends StatelessWidget {
  final String yearMonth;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;

  const MealMonthHeader({
    super.key,
    required this.yearMonth,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final display = formatYearMonthDisplay(yearMonth);

    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전달',
          iconSize: 22,
        ),
        Expanded(
          child: GestureDetector(
            onTap: onPick,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  display,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Gaps.h6,
                Icon(Icons.calendar_month, size: 18, color: primary),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음달',
          iconSize: 22,
        ),
      ],
    );
  }
}
