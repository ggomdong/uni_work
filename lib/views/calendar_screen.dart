import '../models/monthly_attendance_model.dart';
import '../view_models/monthly_attendance_view_model.dart';
import '../constants/gaps.dart';
import '../views/widgets/common_app_bar.dart';
import '../views/widgets/stat_item.dart';
import '../views/widgets/month_date_selector.dart';
import '../utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  final ValueNotifier<DateTime> _selectedDay = ValueNotifier(DateTime.now());
  final ValueNotifier<List<MonthlyAttendanceModel>> _selectedAttendance =
      ValueNotifier([]);
  Map<int, List<MonthlyAttendanceModel>> attendanceMap = {};
  bool _isFirstLoading = true;

  // 상태에 따른 색상 세팅
  Color resolveStatusColor(BuildContext context, String? status) {
    switch (status) {
      case "스케쥴없음":
        return Colors.grey.shade100;
      case "OFF":
      case "무급휴무":
      case "유급휴무":
        return Colors.white;
      case "정상":
        return Colors.green.shade100;
      case "결근":
        return Colors.red.shade100;
      case "지각":
        return Colors.orange.shade100;
      case "조퇴":
        return Colors.purple.shade100;
      case "연장":
        return Colors.blue.shade100;
      case "휴일근무":
        return Colors.teal.shade200;
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(ref);

    final monthly = ref.watch(
      monthlyAttendanceProvider((
        year: _focusedDay.year,
        month: _focusedDay.month,
      )),
    );

    return Scaffold(
      appBar: CommonAppBar(),
      body: monthly.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (err, _) => Center(child: Text("에러 발생: $err")),
        data: (records) {
          attendanceMap.clear();
          // 월간 데이터(records)를 날짜별로 그룹화해서 attendanceMap 에 저장
          for (var record in records) {
            final key =
                DateTime(
                  record.recordDay.year,
                  record.recordDay.month,
                  record.recordDay.day,
                ).millisecondsSinceEpoch;
            attendanceMap.putIfAbsent(key, () => []).add(record);
          }

          // 최초 로딩시 오늘 날짜의 출결 기록을 _selectedAttendance 에 세팅
          if (_isFirstLoading) {
            final todayMillis =
                DateTime(
                  _selectedDay.value.year,
                  _selectedDay.value.month,
                  _selectedDay.value.day,
                ).millisecondsSinceEpoch;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _selectedAttendance.value = attendanceMap[todayMillis] ?? [];
            });

            _isFirstLoading = false;
          }

          return Column(
            children: [
              Gaps.v48,

              // Row(
              //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              //   children: [
              //     StatItem(
              //       icon: Icons.check_circle,
              //       title: "정상",
              //       value: "${records.where((r) => r.status == '정상').length} 일",
              //       color: Colors.green,
              //     ),
              //     StatItem(
              //       icon: Icons.cancel,
              //       title: "결근",
              //       value: "${records.where((r) => r.status == '결근').length} 일",
              //       color: Colors.redAccent,
              //     ),
              //     StatItem(
              //       icon: Icons.timer_off,
              //       title: "지각",
              //       value: "${records.where((r) => r.status == '지각').length} 일",
              //       color: Colors.orange,
              //     ),
              //     StatItem(
              //       icon: Icons.logout,
              //       title: "조퇴",
              //       value: "${records.where((r) => r.status == '조퇴').length} 일",
              //       color: Colors.purpleAccent,
              //     ),
              //     StatItem(
              //       icon: Icons.alarm,
              //       title: "연장",
              //       value: "${records.where((r) => r.status == '연장').length} 일",
              //       color: Colors.blue,
              //     ),
              //     StatItem(
              //       icon: Icons.schedule,
              //       title: "휴일",
              //       value:
              //           "${records.where((r) => r.status == '휴일근무').length} 일",
              //       color: Colors.black,
              //     ),
              //   ],
              // ),
              // Gaps.v52,
              MonthDateSelector(
                currentMonth: _focusedDay,
                selectedDate: _selectedDay.value,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDay.value = date;
                    final key =
                        DateTime(
                          date.year,
                          date.month,
                          date.day,
                        ).millisecondsSinceEpoch;
                    _selectedAttendance.value = attendanceMap[key] ?? [];
                  });
                },
                onPreviousMonth: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month - 1,
                      1,
                    );
                  });
                },
                onNextMonth: () {
                  setState(() {
                    _focusedDay = DateTime(
                      _focusedDay.year,
                      _focusedDay.month + 1,
                      1,
                    );
                  });
                },
                onToday: () {
                  setState(() {
                    _focusedDay = DateTime.now();
                    _selectedDay.value = DateTime.now();
                    final key = DateTime.now().millisecondsSinceEpoch;
                    _selectedAttendance.value = attendanceMap[key] ?? [];
                  });
                },
              ),

              Gaps.v16,

              Expanded(
                child: ValueListenableBuilder<List<MonthlyAttendanceModel>>(
                  valueListenable: _selectedAttendance,
                  builder: (context, records, _) {
                    if (records.isEmpty) {
                      return const Center(child: Text("근무 스케쥴이 없습니다."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];

                        final statusColor = resolveStatusColor(
                          context,
                          record.status,
                        );

                        return Card(
                          color: Colors.white,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 날짜 + 상태
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat(
                                        'yyyy-MM-dd (E)',
                                        'ko_KR',
                                      ).format(record.recordDay),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        record.status!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      backgroundColor: statusColor,
                                    ),
                                  ],
                                ),
                                Gaps.v1,

                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_note,
                                      size: 18,
                                      color: Colors.blueGrey,
                                    ),
                                    Gaps.h4,
                                    Text(
                                      "근무: ${record.workCat ?? ''} (${record.workName ?? ''})",
                                    ),
                                  ],
                                ),
                                Gaps.v4,

                                // 근무시간
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 18,
                                      color: Colors.black,
                                    ),
                                    Gaps.h4,
                                    Text(
                                      "일정: ${record.workStart ?? '--'} ~ ${record.workEnd ?? '--'}",
                                    ),
                                  ],
                                ),
                                Gaps.v4,

                                // 출근
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.login,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                    Gaps.h4,
                                    Text("출근: ${record.checkinTime ?? '--'}"),
                                  ],
                                ),
                                Gaps.v4,

                                // 퇴근
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.logout,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    Gaps.h4,
                                    Text("퇴근: ${record.checkoutTime ?? '--'}"),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
