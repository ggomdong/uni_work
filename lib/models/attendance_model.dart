class AttendanceModel {
  final String empName;
  // final String dept;
  // final String position;
  final String? workStart;
  final String? workEnd;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final bool isEarlyCheckout;
  // final List<String> notices; // 공지사항 목록
  final bool canBypassBeacon;

  AttendanceModel({
    required this.empName,
    // required this.dept,
    // required this.position,
    this.workStart,
    this.workEnd,
    this.checkinTime,
    this.checkoutTime,
    required this.isEarlyCheckout,
    // required this.notices,
    this.canBypassBeacon = false,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      empName: json['emp_name'] ?? '',
      // dept: json['dept'] ?? '',
      // position: json['position'] ?? '',
      workStart: json['work_start'],
      workEnd: json['work_end'],
      checkinTime: DateTime.tryParse(json['checkin_time'] ?? ''),
      checkoutTime: DateTime.tryParse(json['checkout_time'] ?? ''),
      isEarlyCheckout: json['is_early_checkout'] ?? false,
      // notices: List<String>.from(json['notices'] ?? []),
      canBypassBeacon: json['can_bypass_beacon'] as bool? ?? false,
    );
  }
}
