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

  /// 비영업일(공휴일 + 비영업요일에 해당하는 날짜 + 비영업일 요일)을 가져옴
  Future<NonBusinessDayInfo> fetchNonBusinessDays({
    required int year,
    required int month,
  }) async {
    final res = await _dio.get(
      'api/non-business-days/',
      queryParameters: {"year": year, "month": month},
    );

    final data = res.data as Map<String, dynamic>;

    // 1) 날짜 리스트 파싱
    final List<dynamic> rawDates =
        data['non_business_days'] as List<dynamic>? ?? [];

    final days =
        rawDates.map<DateTime>((raw) {
          final s = raw as String; // "YYYY-MM-DD"
          final parts = s.split('-').map(int.parse).toList();
          return DateTime(parts[0], parts[1], parts[2]);
        }).toSet();

    // 2) 요일 리스트 파싱 (월=1, ..., 일=7)
    final rawWeekdays =
        (data['non_business_weekdays'] as List<dynamic>? ?? const []);
    final weekdays = rawWeekdays.map<int>((e) => (e as num).toInt()).toList();

    return NonBusinessDayInfo(days: days, weekdays: weekdays);
  }
}

final attendanceRepo = Provider<AttendanceRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return AttendanceRepository(authRepository.dio);
});
