import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../app_refresh_service.dart';
import '../status_theme.dart';
import '../utils.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import '../models/monthly_attendance_model.dart';
import '../view_models/monthly_attendance_view_model.dart';
import './widgets/common_app_bar.dart';
import './widgets/error_view.dart';
import './widgets/stat_day_cell.dart';
import './widgets/stat_detail_card.dart';
import './widgets/stat_summary_bar.dart';

/// seconds 추출 함수 타입
typedef SecondsAccessor<T> = int? Function(T rec);

/// 지각/조퇴/연장/휴근이 존재하는지 판단하는 헬퍼 함수
bool hasLongValue<T>(
  List<T> records,
  SecondsAccessor<T> getSeconds,
  bool Function(T rec) isCountable,
) {
  for (final r in records) {
    if (isCountable(r) && (getSeconds(r) ?? 0) > 0) {
      return true; // 1회 이상 존재
    }
  }
  return false; // 전부 0초면 짧은 값(예: "0회")
}

class StatScreen extends ConsumerStatefulWidget {
  const StatScreen({super.key});

  @override
  ConsumerState<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends ConsumerState<StatScreen> {
  DateTime _focusedDay = DateTime.now();
  // _selectedDay는 오늘 자정을 기준으로 저장 00:00:00
  final ValueNotifier<DateTime> _selectedDay = ValueNotifier(
    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
  );
  final ValueNotifier<MonthlyAttendanceModel?> _selectedAttendance =
      ValueNotifier<MonthlyAttendanceModel?>(null);
  final Map<int, MonthlyAttendanceModel> attendanceMap = {};

  String _secondsToHms(int seconds) {
    if (seconds <= 0) return "00:00:00";
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final hh = h.toString().padLeft(2, '0');
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return "$hh:$mm:$ss";
  }

  /// (발생 횟수, 총 HH:MM:SS) 문자열로 반환: "n회, HH:MM:SS"
  String formatCountAndSeconds<T>(
    List<T> records,
    SecondsAccessor<T> getSeconds,
    bool Function(T rec) isCountable,
  ) {
    if (records.isEmpty) return "-";
    int totalSeconds = 0;
    int count = 0;
    for (final r in records) {
      if (isCountable(r)) {
        final s = getSeconds(r) ?? 0;
        if (s > 0) {
          count++;
          totalSeconds += s;
        }
      }
    }
    return count == 0 ? "-" : "$count회, ${_secondsToHms(totalSeconds)}";
  }

  List<String> _codesOf(int millis) {
    final record = attendanceMap[millis];
    // 백엔드 codes 우선, 없으면 레거시 status 1개를 codes로 대체
    return record?.statusCodes?.toList() ??
        (record?.status != null ? <String>[record!.status!] : const <String>[]);
  }

  Future<void> _refreshMonthly() async {
    final ym = (year: _focusedDay.year, month: _focusedDay.month);
    try {
      await ref.read(appRefreshServiceProvider).refreshAll(ym: ym);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("월간 통계 정보를 갱신했어요.")));
      }
    } catch (e) {
      if (mounted) {
        // 사용자에게는 정리된 메시지만 노출
        final msg = humanizeErrorMessage(e);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(ref);
    final size = MediaQuery.of(context).size;

    // 현재 포커스된 연월
    final ym = (year: _focusedDay.year, month: _focusedDay.month);

    // 비영업 정보(날짜 + 요일) 가져오기
    final nonBusinessInfo = ref
        .watch(nonBusinessDayProvider(ym))
        .maybeWhen(
          data: (value) => value,
          orElse:
              () => NonBusinessDayInfo(
                days: <DateTime>{},
                weekdays: const <int>[],
              ),
        );

    bool isNonBusinessDay(DateTime day) {
      final key = DateTime(day.year, day.month, day.day);
      return nonBusinessInfo.days.contains(key);
    }

    // 헤더 빨간색으로 표시할 요일들 (월=1, ..., 일=7)
    final weekendDays = nonBusinessInfo.weekdays;

    final monthly = ref.watch(
      monthlyAttendanceProvider((
        year: _focusedDay.year,
        month: _focusedDay.month,
      )),
    );

    return Scaffold(
      appBar: CommonAppBar(
        actions: [
          IconButton(
            tooltip: "새로고침",
            onPressed: _refreshMonthly,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: monthly.when(
        loading:
            () => const Center(child: CircularProgressIndicator.adaptive()),
        error:
            (err, st) => ErrorView(
              title: '통계 정보를 불러오지 못했습니다',
              icon: Icons.cloud_off,
              error: err,
              stackTrace: st,
              onRetry: _refreshMonthly, // 중앙 새로고침 버튼
            ),
        data: (records) {
          attendanceMap.clear();
          // 월간 데이터(records)를 날짜별로 매핑 (1일 = 1레코드)
          for (var record in records) {
            final key =
                DateTime(
                  record.recordDay.year,
                  record.recordDay.month,
                  record.recordDay.day,
                ).millisecondsSinceEpoch;
            attendanceMap[key] = record;
          }

          // 항상 최신 attendanceMap 기준으로 선택일 데이터를 갱신
          final selectedKey = _selectedDay.value.millisecondsSinceEpoch;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _selectedAttendance.value = attendanceMap[selectedKey];
          });

          final holidayValue = formatCountAndSeconds(
            records,
            (r) => r.holidaySeconds,
            (r) => (r.statusCodes?.contains('HOLIDAY') ?? false),
          );
          final holidayLong = hasLongValue(
            records,
            (r) => r.holidaySeconds,
            (r) => (r.statusCodes?.contains('HOLIDAY') ?? false),
          );

          final overtimeValue = formatCountAndSeconds(
            records,
            (r) => r.overtimeSeconds,
            (r) => (r.statusCodes?.contains('OVERTIME') ?? false),
          );
          final overtimeLong = hasLongValue(
            records,
            (r) => r.overtimeSeconds,
            (r) => (r.statusCodes?.contains('OVERTIME') ?? false),
          );

          final lateValue = formatCountAndSeconds(
            records,
            (r) => r.lateSeconds,
            (r) => (r.statusCodes?.contains('LATE') ?? false),
          );
          final lateLong = hasLongValue(
            records,
            (r) => r.lateSeconds,
            (r) => (r.statusCodes?.contains('LATE') ?? false),
          );

          final earlyValue = formatCountAndSeconds(
            records,
            (r) => r.earlySeconds,
            (r) => (r.statusCodes?.contains('EARLY') ?? false),
          );
          final earlyLong = hasLongValue(
            records,
            (r) => r.earlySeconds,
            (r) => (r.statusCodes?.contains('EARLY') ?? false),
          );

          return Column(
            children: [
              Gaps.v32,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
                child: StatSummaryBar(
                  holidayValue: holidayValue,
                  holidayLong: holidayLong,
                  overtimeValue: overtimeValue,
                  overtimeLong: overtimeLong,
                  lateValue: lateValue,
                  lateLong: lateLong,
                  earlyValue: earlyValue,
                  earlyLong: earlyLong,
                ),
              ),
              Gaps.v32,

              SizedBox(
                height: size.height * 0.35,
                child: ValueListenableBuilder<DateTime>(
                  valueListenable: _selectedDay,
                  builder: (context, selectedDay, _) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.size16,
                      ),
                      child: TableCalendar(
                        focusedDay: _focusedDay,
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(9999, 12, 31),
                        locale: 'ko_KR',
                        weekendDays: weekendDays,
                        daysOfWeekHeight: 24,
                        rowHeight: size.height * 0.04,
                        selectedDayPredicate:
                            (day) => isSameDay(selectedDay, day),
                        enabledDayPredicate: (day) {
                          return day.month == _focusedDay.month;
                        },
                        calendarFormat: CalendarFormat.month,
                        headerStyle: HeaderStyle(
                          titleCentered: true,
                          formatButtonVisible: false,
                        ),
                        onDaySelected: (selectedDay, focusedDay) {
                          final normalizedDay =
                              DateTime(
                                selectedDay.year,
                                selectedDay.month,
                                selectedDay.day,
                              ).millisecondsSinceEpoch;

                          _selectedDay.value = selectedDay;
                          _selectedAttendance.value =
                              attendanceMap[normalizedDay];
                        },
                        onPageChanged: (newFocusedDay) {
                          final newMonth = DateTime(
                            newFocusedDay.year,
                            newFocusedDay.month,
                          );

                          final today = DateTime.now();
                          final thisMonth = DateTime(today.year, today.month);

                          DateTime selected;
                          if (newMonth.year == thisMonth.year &&
                              newMonth.month == thisMonth.month) {
                            // 이번 달이면 오늘 날짜 선택
                            selected = DateTime(
                              today.year,
                              today.month,
                              today.day,
                            );
                          } else {
                            // 다른 달이면 1일 선택
                            selected = DateTime(
                              newMonth.year,
                              newMonth.month,
                              1,
                            );
                          }

                          setState(() {
                            _focusedDay = newMonth;
                            _selectedDay.value = selected;
                          });

                          // UI 빌드 이후에 _selectedAttendance 업데이트 (바로 하면 race condition 가능성 있음)
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _selectedAttendance.value =
                                attendanceMap[selected.millisecondsSinceEpoch];
                          });
                        },
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: TextStyle(
                            fontSize: Sizes.size14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          weekendStyle: TextStyle(
                            fontSize: Sizes.size14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.red.shade300 : Colors.red,
                          ),
                        ),
                        calendarBuilders: CalendarBuilders(
                          headerTitleBuilder: (context, date) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat.yMMMM('ko_KR').format(date),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Gaps.h16,
                                OutlinedButton(
                                  onPressed: () {
                                    final now = DateTime.now();
                                    final today = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                    );
                                    final todayMillis =
                                        today.millisecondsSinceEpoch;

                                    _focusedDay = today;
                                    _selectedDay.value = today;
                                    _selectedAttendance.value =
                                        attendanceMap[todayMillis];
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size(1, 1),
                                    side: const BorderSide(color: Colors.blue),
                                    foregroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    textStyle: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  child: const Text("TODAY"),
                                ),
                              ],
                            );
                          },

                          todayBuilder: (context, day, focusedDay) {
                            final millis =
                                DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                ).millisecondsSinceEpoch;

                            return StatDayCell(
                              day: day,
                              isToday: true,
                              isSelected: isSameDay(day, _selectedDay.value),
                              statusCodes: _codesOf(millis),
                              resolveStatusColor: resolveStatusColor,
                              isNonBusinessDay: isNonBusinessDay(day),
                            );
                          },

                          selectedBuilder: (context, day, focusedDay) {
                            final millis =
                                DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                ).millisecondsSinceEpoch;

                            return StatDayCell(
                              day: day,
                              isToday: isSameDay(day, DateTime.now()),
                              isSelected: true,
                              statusCodes: _codesOf(millis),
                              resolveStatusColor: resolveStatusColor,
                              isNonBusinessDay: isNonBusinessDay(day),
                            );
                          },

                          defaultBuilder: (context, day, focusedDay) {
                            final millis =
                                DateTime(
                                  day.year,
                                  day.month,
                                  day.day,
                                ).millisecondsSinceEpoch;
                            final isToday = isSameDay(day, DateTime.now());
                            final isSelected = isSameDay(
                              day,
                              _selectedDay.value,
                            );

                            return StatDayCell(
                              day: day,
                              isToday: isToday,
                              isSelected: isSelected,
                              statusCodes: _codesOf(millis),
                              resolveStatusColor: resolveStatusColor,
                              isNonBusinessDay: isNonBusinessDay(day),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              Gaps.v16,
              StatDetailCard(selectedAttendance: _selectedAttendance),
            ],
          );
        },
      ),
    );
  }
}
