import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/attendance_repo.dart';
import '../models/monthly_attendance_model.dart';

typedef YM = ({int year, int month});

class MonthlyAttendanceViewModel
    extends FamilyAsyncNotifier<List<MonthlyAttendanceModel>, YM> {
  AttendanceRepository get _repo => ref.read(attendanceRepo);

  @override
  Future<List<MonthlyAttendanceModel>> build(YM arg) async {
    return await _repo.fetchMonthlyAttendance(year: arg.year, month: arg.month);
  }

  Future<void> refresh() async {
    final arg = this.arg; // 현재 family 인자
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () async =>
          await _repo.fetchMonthlyAttendance(year: arg.year, month: arg.month),
    );
  }
}

final monthlyAttendanceProvider = AsyncNotifierProvider.family<
  MonthlyAttendanceViewModel,
  List<MonthlyAttendanceModel>,
  YM
>(MonthlyAttendanceViewModel.new);

final nonBusinessDayProvider = FutureProvider.family<NonBusinessDayInfo, YM>((
  ref,
  ym,
) async {
  final repo = ref.read(attendanceRepo);
  return repo.fetchNonBusinessDays(year: ym.year, month: ym.month);
});
