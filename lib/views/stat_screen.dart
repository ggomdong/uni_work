import '../status_theme.dart';
import '../models/monthly_attendance_model.dart';
import '../view_models/monthly_attendance_view_model.dart';
import '../constants/gaps.dart';
import '../constants/sizes.dart';
import '../views/widgets/common_app_bar.dart';
import '../views/widgets/stat_item.dart';
import '../views/widgets/stat_day_cell.dart';
import '../utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

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
    if (records.isEmpty) return "0회";
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
    return count == 0 ? "$count회" : "$count회, ${_secondsToHms(totalSeconds)}";
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
      await ref.read(monthlyAttendanceProvider(ym).notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("월간 출결 정보를 갱신했어요.")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("갱신 실패: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(ref);
    final size = MediaQuery.of(context).size;

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
        error: (err, _) => Center(child: Text("에러 발생: $err")),
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

          final items = [
            StatItemMini(
              icon: Icons.check_circle,
              title: "정상",
              value:
                  "${records.where((r) => (r.statusCodes?.contains('NORMAL') ?? false)).length} 일",
              isLong: false,
              color: themeOf("NORMAL").fg,
            ),
            StatItemMini(
              icon: Icons.cancel,
              title: "오류",
              value:
                  "${records.where((r) => (r.statusCodes?.contains('ERROR') ?? false)).length} 일",
              isLong: false,
              color: themeOf("ERROR").fg,
            ),
            StatItemMini(
              icon: Icons.timer_off,
              title: "지각",
              value: formatCountAndSeconds(
                records,
                (r) => r.lateSeconds,
                (r) => (r.statusCodes?.contains('LATE') ?? false),
              ),
              isLong: hasLongValue(
                records,
                (r) => r.lateSeconds,
                (r) => (r.statusCodes?.contains('LATE') ?? false),
              ),
              color: themeOf("LATE").fg,
            ),
            StatItemMini(
              icon: Icons.logout,
              title: "조퇴",
              value: formatCountAndSeconds(
                records,
                (r) => r.earlySeconds,
                (r) => (r.statusCodes?.contains('EARLY') ?? false),
              ),
              isLong: hasLongValue(
                records,
                (r) => r.earlySeconds,
                (r) => (r.statusCodes?.contains('EARLY') ?? false),
              ),
              color: themeOf("EARLY").fg,
            ),
            StatItemMini(
              icon: Icons.more_time,
              title: "연장",
              value: formatCountAndSeconds(
                records,
                (r) => r.overtimeSeconds,
                (r) => (r.statusCodes?.contains('OVERTIME') ?? false),
              ),
              isLong: hasLongValue(
                records,
                (r) => r.overtimeSeconds,
                (r) => (r.statusCodes?.contains('OVERTIME') ?? false),
              ),
              color: themeOf("OVERTIME").fg,
            ),
            StatItemMini(
              icon: Icons.holiday_village,
              title: "휴근",
              value: formatCountAndSeconds(
                records,
                (r) => r.holidaySeconds,
                (r) => (r.statusCodes?.contains('HOLIDAY') ?? false),
              ),
              isLong: hasLongValue(
                records,
                (r) => r.holidaySeconds,
                (r) => (r.statusCodes?.contains('HOLIDAY') ?? false),
              ),
              color: themeOf("HOLIDAY").fg,
            ),
          ];

          return Column(
            children: [
              Gaps.v32,

              StatGrid(items: items),

              Gaps.v16,

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
                        locale: 'ko_KR',
                        rowHeight: size.height * 0.04,
                        daysOfWeekHeight: 24,
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.utc(2050, 12, 31),
                        focusedDay: _focusedDay,
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
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(
                child: ValueListenableBuilder<MonthlyAttendanceModel?>(
                  valueListenable: _selectedAttendance,
                  builder: (context, record, _) {
                    // DB에 row가 없거나, NOSCHEDULE인 경우는 동일하게 스케쥴없음으로 처리
                    if (record == null ||
                        (record.statusCodes?.contains('NOSCHEDULE') ?? false)) {
                      return const Center(child: Text("근무 스케쥴이 없습니다."));
                    }

                    // 상태 리스트 준비
                    final List<String> codes =
                        (record.statusCodes ?? const <String>[]);
                    final List<String> labels =
                        (record.statusLabels ??
                            (record.status != null
                                ? <String>[record.status!]
                                : const <String>[]));

                    // 칩 위젯들 구성 (codes와 labels 길이가 다를 수도 있으니 방어)
                    final int chipCount = labels.length;
                    final chips = List<Widget>.generate(chipCount, (i) {
                      final label = labels[i];
                      final code = (i < codes.length) ? codes[i] : null;

                      final bg = resolveChipBg(code); // 팔레트 기반 옅은 배경
                      final theme = themeOf(code); // fg/border 등 접근
                      final side =
                          theme.border != null
                              ? BorderSide(color: theme.border!)
                              : BorderSide.none;
                      return Chip(
                        label: Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        backgroundColor: bg,
                        side: side,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      );
                    });

                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Card(
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
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 날짜
                                  Expanded(
                                    child: Text(
                                      DateFormat(
                                        'yyyy-MM-dd (E)',
                                        'ko_KR',
                                      ).format(record.recordDay),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  // 칩들 (오른쪽 정렬 + 여러 줄 래핑)
                                  Flexible(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: chips,
                                      ),
                                    ),
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
                      ),
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
