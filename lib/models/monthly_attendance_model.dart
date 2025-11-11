class MonthlyAttendanceModel {
  final DateTime recordDay;

  // 근무스케쥴(HH:mm)
  final String? workStart;
  final String? workEnd;

  // 출퇴근 기록(HH:mm)
  final String? checkinTime;
  final String? checkoutTime;

  // 상태 문자열 (예: 정상 + 연장)
  final String?
  status; // 9가지 상태(스케쥴없음, OFF, 무급휴무, 유급휴무, 정상, 오류, 지각, 조퇴, 연장, 휴일근무)

  // 화면용 상태코드 ["NORMAL","LATE","EARLY","OVERTIME","HOLIDAY","ERROR","PAY","NOPAY","OFF","NOSCHEDULE"]
  final List<String>? statusCodes;
  // ["정상","지각","조퇴","연장",...]
  final List<String>? statusLabels;

  // 근무모듈
  final String? workCat; // 정규근무, 휴일근무 등
  final String? workName; // 평일(의사), 연차 등
  final int? workColorCode;
  final String? workColorHex;

  // 시간(초) 지표 (휴게 반영)
  final int? lateSeconds;
  final int? earlySeconds;
  final int? overtimeSeconds;
  final int? holidaySeconds;

  // 편의 boolean
  final bool? isLate;
  final bool? isEarlyCheckout;
  final bool? isOvertime;

  MonthlyAttendanceModel({
    required this.recordDay,
    this.workStart,
    this.workEnd,
    this.checkinTime,
    this.checkoutTime,
    this.status,
    this.statusCodes,
    this.statusLabels,
    this.workCat,
    this.workName,
    this.workColorCode,
    this.workColorHex,
    this.lateSeconds,
    this.earlySeconds,
    this.overtimeSeconds,
    this.holidaySeconds,
    this.isLate,
    this.isEarlyCheckout,
    this.isOvertime,
  });

  factory MonthlyAttendanceModel.fromJson(Map<String, dynamic> json) {
    List<String>? list(dynamic v) =>
        v == null ? null : List<String>.from(v as List);

    return MonthlyAttendanceModel(
      recordDay: DateTime.parse(json['record_day'] as String),
      workStart: json['work_start'] as String?,
      workEnd: json['work_end'] as String?,
      checkinTime: json['checkin_time'] as String?,
      checkoutTime: json['checkout_time'] as String?,
      status: json['status'] as String?,
      statusCodes: list(json['status_codes']),
      statusLabels: list(json['status_labels']),
      workCat: json['work_cat'] as String?,
      workName: json['work_name'] as String?,
      workColorCode: json['work_color_code'] as int?,
      workColorHex: json['work_color_hex'] as String?,
      lateSeconds: json['late_seconds'] as int?,
      earlySeconds: json['early_seconds'] as int?,
      overtimeSeconds: json['overtime_seconds'] as int?,
      holidaySeconds: json['holiday_seconds'] as int?,
      isLate: json['is_late'] as bool?,
      isEarlyCheckout: json['is_early_checkout'] as bool?,
      isOvertime: json['is_overtime'] as bool?,
    );
  }
}
