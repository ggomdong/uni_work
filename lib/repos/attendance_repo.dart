import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/attendance_model.dart';
import '../models/monthly_attendance_model.dart';
import '../repos/authentication_repo.dart';

class AttendanceRepository {
  final Dio _dio;

  AttendanceRepository(this._dio);

  Future<AttendanceModel> fetchTodayAttendance() async {
    final response = await _dio.get('api/attendance/');
    return AttendanceModel.fromJson(response.data);
  }

  Future<List<MonthlyAttendanceModel>> fetchMonthlyAttendance({
    required int year,
    required int month,
  }) async {
    final res = await _dio.get(
      'api/attendance/monthly',
      queryParameters: {"year": year, "month": month},
    );

    final data = res.data;

    // 1) 완전 빈 응답 or null → []
    if (data == null) return <MonthlyAttendanceModel>[];

    // 2) 서버가 진짜 리스트([] 또는 [ {...}, {...} ])를 주는 정상 케이스
    if (data is List) {
      // 원소 타입 안전 캐스팅
      final list =
          data
              .whereType<Map<String, dynamic>>() // Map만 통과
              .map((j) => MonthlyAttendanceModel.fromJson(j))
              .toList();
      return list;
    }
    // 3) 그 외 예외 형태 → 빈 배열로 처리(또는 throw)
    return <MonthlyAttendanceModel>[];
  }

  Future<String> submitWork() async {
    try {
      final response = await _dio.post("api/work/");

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
