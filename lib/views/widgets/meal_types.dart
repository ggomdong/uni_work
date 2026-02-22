import 'package:intl/intl.dart';

class MealSummary {
  final String ym;
  final int totalAmount;
  final int usedAmount;
  final int balance;
  final int claimCount;

  const MealSummary({
    required this.ym,
    required this.totalAmount,
    required this.usedAmount,
    required this.balance,
    required this.claimCount,
  });
}

class MealParticipant {
  final String name;
  final int amount;

  const MealParticipant({required this.name, required this.amount});

  factory MealParticipant.fromJson(Map<String, dynamic> json) {
    return MealParticipant(
      name: (json['name'] as String?) ?? '',
      amount: _parseInt(json['amount']),
    );
  }
}

class MealClaimItem {
  final int id;
  final String ym;
  final DateTime usedDate;
  final String merchantName;
  final String approvalNo;
  final int totalAmount;
  final int myAmount;
  final String createdByName;
  final bool canEdit;
  final bool canDelete;
  final int participantsCount;
  final int participantsSum;
  final List<MealParticipant> participants;

  const MealClaimItem({
    required this.id,
    required this.ym,
    required this.usedDate,
    required this.merchantName,
    required this.approvalNo,
    required this.totalAmount,
    required this.myAmount,
    required this.createdByName,
    required this.canEdit,
    required this.canDelete,
    required this.participantsCount,
    required this.participantsSum,
    required this.participants,
  });

  factory MealClaimItem.fromJson(Map<String, dynamic> json) {
    return MealClaimItem(
      id: _parseInt(json['id']),
      ym: (json['ym'] as String?) ?? '',
      usedDate: _parseDate(json['used_date']),
      merchantName: (json['merchant_name'] as String?) ?? '',
      approvalNo: (json['approval_no'] as String?) ?? '',
      totalAmount: _parseInt(json['total_amount']),
      myAmount: _parseInt(json['my_amount']),
      createdByName: (json['created_by_name'] as String?) ?? '',
      canEdit: _parseBool(json['can_edit']),
      canDelete: _parseBool(json['can_delete']),
      participantsCount: _parseInt(json['participants_count']),
      participantsSum: _parseInt(json['participants_sum']),
      participants: const <MealParticipant>[],
    );
  }

  factory MealClaimItem.fromDetailJson(Map<String, dynamic> json) {
    final rawParticipants = json['participants'];
    final participants =
        rawParticipants is List
            ? rawParticipants
                .whereType<Map>()
                .map(
                  (e) => MealParticipant(
                    name: (e['emp_name'] as String?) ?? '',
                    amount: _parseInt(e['amount']),
                  ),
                )
                .toList()
            : <MealParticipant>[];
    final count = _parseInt(json['participants_count']);
    final sum = _parseInt(json['participants_sum']);

    return MealClaimItem(
      id: _parseInt(json['id']),
      ym: (json['ym'] as String?) ?? '',
      usedDate: _parseDate(json['used_date']),
      merchantName: (json['merchant_name'] as String?) ?? '',
      approvalNo: (json['approval_no'] as String?) ?? '',
      totalAmount: _parseInt(json['total_amount']),
      myAmount: _parseInt(json['my_amount']),
      createdByName: (json['created_by_name'] as String?) ?? '',
      canEdit: _parseBool(json['can_edit']),
      canDelete: _parseBool(json['can_delete']),
      participantsCount: count != 0 ? count : participants.length,
      participantsSum:
          sum != 0 ? sum : participants.fold(0, (s, p) => s + p.amount),
      participants: participants,
    );
  }

  MealClaimItem copyWith({
    int? id,
    String? ym,
    DateTime? usedDate,
    String? merchantName,
    String? approvalNo,
    int? totalAmount,
    int? myAmount,
    String? createdByName,
    bool? canEdit,
    bool? canDelete,
    int? participantsCount,
    int? participantsSum,
    List<MealParticipant>? participants,
  }) {
    return MealClaimItem(
      id: id ?? this.id,
      ym: ym ?? this.ym,
      usedDate: usedDate ?? this.usedDate,
      merchantName: merchantName ?? this.merchantName,
      approvalNo: approvalNo ?? this.approvalNo,
      totalAmount: totalAmount ?? this.totalAmount,
      myAmount: myAmount ?? this.myAmount,
      createdByName: createdByName ?? this.createdByName,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
      participantsCount: participantsCount ?? this.participantsCount,
      participantsSum: participantsSum ?? this.participantsSum,
      participants: participants ?? this.participants,
    );
  }
}

int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

bool _parseBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    return v == 'true' || v == '1';
  }
  return false;
}

DateTime _parseDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  return DateTime(1970);
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
