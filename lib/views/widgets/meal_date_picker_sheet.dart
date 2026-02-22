import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../constants/gaps.dart';
import '../../constants/sizes.dart';

Future<DateTime?> showMealDatePickerSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: _MealDatePickerSheet(
            initialDate: initialDate,
            firstDate: firstDate,
            lastDate: lastDate,
          ),
        ),
      );
    },
  );
}

class _MealDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _MealDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_MealDatePickerSheet> createState() => _MealDatePickerSheetState();
}

class _MealDatePickerSheetState extends State<_MealDatePickerSheet> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;

  double _calcRowHeight(double availableHeight) {
    const headerHeight = 44.0;
    const dowHeight = 24.0;
    final body = availableHeight - headerHeight - dowHeight;
    final raw = body / 6;
    if (raw < 38) return 38;
    if (raw > 52) return 52;
    return raw;
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDate;
    _focusedDay = widget.initialDate;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Gaps.v16,
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Gaps.v16,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '사용일 선택',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Gaps.v8,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final rowHeight = _calcRowHeight(constraints.maxHeight);
                  return TableCalendar(
                    locale: 'ko_KR',
                    firstDay: widget.firstDate,
                    lastDay: widget.lastDate,
                    focusedDay: _focusedDay,
                    startingDayOfWeek: StartingDayOfWeek.sunday,
                    calendarFormat: CalendarFormat.month,
                    availableGestures: AvailableGestures.horizontalSwipe,
                    rowHeight: rowHeight,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      Navigator.of(context).pop(_selectedDay);
                    },
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextFormatter: (date, locale) =>
                          DateFormat('y년 M월', 'ko_KR').format(date),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      dowTextFormatter: (date, locale) {
                        const labels = {
                          DateTime.sunday: '일',
                          DateTime.monday: '월',
                          DateTime.tuesday: '화',
                          DateTime.wednesday: '수',
                          DateTime.thursday: '목',
                          DateTime.friday: '금',
                          DateTime.saturday: '토',
                        };
                        return labels[date.weekday] ?? '';
                      },
                    ),
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Gaps.v16,
        ],
      ),
    );
  }
}
