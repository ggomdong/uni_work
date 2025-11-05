import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../constants/gaps.dart';

class MonthDateSelector extends StatefulWidget {
  final DateTime currentMonth;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;

  const MonthDateSelector({
    super.key,
    required this.currentMonth,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  @override
  State<MonthDateSelector> createState() => _MonthDateSelectorState();
}

class _MonthDateSelectorState extends State<MonthDateSelector> {
  final ScrollController _scrollController = ScrollController();
  static const double _fontSize = 24.0; // 날짜 글씨 크기
  static const double _itemHeight = 80.0; // 날짜 컨테이너 높이
  static const double _itemWidth = _fontSize * 3; // 날짜 너비

  List<DateTime> _getMonthDates(DateTime month) {
    // final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      lastDay.day,
      (index) => DateTime(month.year, month.month, index + 1),
    );
  }

  void _scrollToSelectedDate() {
    final dates = _getMonthDates(widget.currentMonth);
    final index = dates.indexWhere(
      (d) => DateUtils.isSameDay(d, widget.selectedDate),
    );
    if (index != -1) {
      final screenWidth = MediaQuery.of(context).size.width;
      final moveOffset = _itemWidth + 8;
      final offset =
          (index * moveOffset) - (screenWidth / 2) + (moveOffset / 2);
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void didUpdateWidget(covariant MonthDateSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final monthChanged =
        !DateUtils.isSameMonth(widget.currentMonth, oldWidget.currentMonth);
    final dateChanged =
        !DateUtils.isSameDay(widget.selectedDate, oldWidget.selectedDate);

    final isToday = DateUtils.isSameDay(widget.selectedDate, DateTime.now());

    if (monthChanged || dateChanged || isToday) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedDate();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DateUtils.isSameMonth(widget.currentMonth, widget.selectedDate)) {
        _scrollToSelectedDate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getMonthDates(widget.currentMonth);
    final monthLabel = DateFormat('yyyy년 M월').format(widget.currentMonth);

    return Column(
      children: [
        SizedBox(
          height: 30,
          width: double.infinity, // Stack 전체 너비 확보!
          child: Stack(
            children: [
              // 가운데 정렬된 년월 + 화살표
              Align(
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onPreviousMonth,
                    ),
                    Gaps.h4,
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Gaps.h4,
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, size: 28),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onNextMonth,
                    ),
                  ],
                ),
              ),

              // TODAY 버튼
              Positioned(
                right: 20,
                top: 0,
                bottom: 0,
                child: OutlinedButton(
                  onPressed: widget.onToday,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue),
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  child: const Text("TODAY"),
                ),
              ),
            ],
          ),
        ),

        Gaps.v8,
        Stack(
          children: [
            SizedBox(
              height: _itemHeight,
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children:
                        dates.map((date) {
                          final isToday = DateUtils.isSameDay(
                            date,
                            DateTime.now(),
                          );
                          final isSelected = DateUtils.isSameDay(
                            date,
                            widget.selectedDate,
                          );
                          final weekdayLabel =
                              ['일', '월', '화', '수', '목', '금', '토'][date.weekday %
                                  7];

                          return GestureDetector(
                            onTap: () => widget.onDateSelected(date),
                            child: Container(
                              width: _itemWidth,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? Colors.blue
                                        : isToday
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : null,
                                shape: BoxShape.circle,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '${date.day}',
                                    style: TextStyle(
                                      fontSize: _fontSize,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : isToday
                                              ? Colors.orange
                                              : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    weekdayLabel,
                                    style: TextStyle(
                                      fontSize: _fontSize - 8,
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : isToday
                                              ? Colors.orange
                                              : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),

            // ← 좌측 스크롤 버튼
            Positioned(
              left: 10,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    (_scrollController.offset - 150).clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8), // 밝은 반투명 배경
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.black54, // 진하지 않은 회색
                  ),
                ),
              ),
            ),

            // → 우측 스크롤 버튼
            Positioned(
              right: 10,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: () {
                  _scrollController.animateTo(
                    (_scrollController.offset + 150).clamp(
                      0.0,
                      _scrollController.position.maxScrollExtent,
                    ),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8), // 밝은 반투명 배경
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: Colors.black54, // 진하지 않은 회색
                  ),
                ),
              ),
            ),
          ],
        ),
        Gaps.v8,
      ],
    );
  }
}
