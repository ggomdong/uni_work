import 'package:intl/intl.dart';

int parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

DateTime parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime(1970);
}

CreatedBy parseCreatedBy(Map<String, dynamic> json) {
  final createdBy = json['created_by'];
  if (createdBy is Map) {
    final m = Map<String, dynamic>.from(createdBy);
    final id = parseInt(
      m['id'] ?? m['user_id'] ?? m['emp_id'] ?? m['employee_id'],
    );
    final name =
        (m['emp_name'] as String?) ??
        (m['name'] as String?) ??
        (m['full_name'] as String?) ??
        '';
    return CreatedBy(id: id, name: name);
  }
  return CreatedBy(id: 0, name: _parseCreatedByName(json));
}

String _parseCreatedByName(Map<String, dynamic> json) {
  return (json['created_by_name'] as String?) ?? '';
}

class CreatedBy {
  final int id;
  final String name;

  const CreatedBy({required this.id, required this.name});
}

String formatMealAmount(int amount) {
  final formatter = NumberFormat('#,###');
  return formatter.format(amount);
}

String formatYearMonth(String ym) {
  if (ym.length != 6) return ym;
  return '${ym.substring(0, 4)}${ym.substring(4, 6)}';
}

String formatYearMonthDisplay(String ym) {
  if (ym.length != 6) return ym;
  final year = ym.substring(0, 4);
  final month = int.tryParse(ym.substring(4, 6)) ?? 0;
  if (month == 0) return ym;
  return '$year년 $month월';
}
