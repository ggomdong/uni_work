import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../repos/authentication_repo.dart';

class AttendanceRepository {
  final Dio _dio;

  AttendanceRepository(this._dio);

  Future<AttendanceModel> fetchTodayAttendance() async {
    final response = await _dio.get('api/attendance/');
    return AttendanceModel.fromJson(response.data);
  }

  Future<String> submitWork() async {
    try {
      final response = await _dio.post("/api/work/");

      final message = response.data["info"] as String? ?? "처리되었습니다.";
      return message;
    } catch (e) {
      throw Exception("출결 처리 중 오류 발생: $e");
    }
  }
}

final attendanceRepo = Provider<AttendanceRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return AttendanceRepository(authRepository.dio);
});
