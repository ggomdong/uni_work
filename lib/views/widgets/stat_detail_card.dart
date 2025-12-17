import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../status_theme.dart';
import '../../constants/gaps.dart';
import '../../models/monthly_attendance_model.dart';

class StatDetailCard extends StatelessWidget {
  const StatDetailCard({
    super.key,
    required ValueNotifier<MonthlyAttendanceModel?> selectedAttendance,
  }) : _selectedAttendance = selectedAttendance;

  final ValueNotifier<MonthlyAttendanceModel?> _selectedAttendance;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: ValueListenableBuilder<MonthlyAttendanceModel?>(
        valueListenable: _selectedAttendance,
        builder: (context, record, _) {
          // DB에 row가 없거나, NOSCHEDULE인 경우는 동일하게 스케쥴없음으로 처리
          if (record == null ||
              (record.statusCodes?.contains('NOSCHEDULE') ?? false)) {
            return const Center(child: Text("근무 스케쥴이 없습니다."));
          }

          // 상태 리스트 준비
          final List<String> codes = (record.statusCodes ?? const <String>[]);
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
                        const Icon(Icons.login, size: 18, color: Colors.green),
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
    );
  }
}
