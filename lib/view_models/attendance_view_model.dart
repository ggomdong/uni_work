import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/attendance_repo.dart';
import '../models/attendance_model.dart';

class AttendanceViewModel extends AsyncNotifier<AttendanceModel> {
  late final AttendanceRepository _repo;
  Timer? _pollingTimer;

  @override
  Future<AttendanceModel> build() async {
    _repo = ref.read(attendanceRepo);
    // 자동 새로고침을 위한 polling 세팅 : 사용 x
    // _startPolling();
    // ref.onDispose(() {
    //   _pollingTimer?.cancel();
    // });
    return await _repo.fetchTodayAttendance();
  }

  void _startPolling() {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      refresh();
    });
  }

  Future<void> submitWork() async {
    try {
      await _repo.submitWork();

      await refresh();
    } catch (e) {
      throw Exception("출결 처리 중 오류 발생: $e");
    }
  }

  Future<void> refresh() async {
    // 깜박이는게 싫으면 AsyncValue.loading()을 주석처리해야함
    // state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () async => await _repo.fetchTodayAttendance(),
    );
  }
}

final attendanceProvider =
    AsyncNotifierProvider<AttendanceViewModel, AttendanceModel>(
      () => AttendanceViewModel(),
    );
