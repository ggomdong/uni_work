import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/attendance_repo.dart';
import '../models/attendance_model.dart';

class AttendanceViewModel extends AsyncNotifier<AttendanceModel> {
  AttendanceRepository get _repo => ref.read(attendanceRepo);
  // Timer? _pollingTimer;

  @override
  Future<AttendanceModel> build() async {
    return await _repo.fetchTodayAttendance();
  }

  Future<void> submitWork() async {
    // throw 하지 말고, 성공/실패를 state로만 표현한다.
    state = await AsyncValue.guard(() async {
      await _repo.submitWork();
      // refresh()는 내부에서 fetch를 또 하니, 여기서 바로 fetch로 갱신해도 됨
      return await _repo.fetchTodayAttendance();
    });
  }

  Future<void> refresh() async {
    // 출퇴근 버튼 누를때마다 refresh를 하므로, 그때마다 깜박이는건 좋지않아서 여긴 주석처리함
    //state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => await _repo.fetchTodayAttendance(),
    );
  }
}

final attendanceProvider =
    AsyncNotifierProvider<AttendanceViewModel, AttendanceModel>(
      () => AttendanceViewModel(),
    );
