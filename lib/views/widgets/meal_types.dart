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
  final int userId;
  final String name;
  final int amount;

  const MealParticipant({
    required this.userId,
    required this.name,
    required this.amount,
  });

  MealParticipant copyWith({int? userId, String? name, int? amount}) {
    return MealParticipant(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
    );
  }

  factory MealParticipant.fromJson(Map<String, dynamic> json) {
    return MealParticipant(
      userId: _parseInt(json['user_id']),
      name: (json['name'] as String?) ?? '',
      amount: _parseInt(json['amount']),
    );
  }

  factory MealParticipant.fromDetailJson(Map<String, dynamic> json) {
    return MealParticipant(
      userId: _parseInt(json['user_id']),
      name: (json['emp_name'] as String?) ?? '',
      amount: _parseInt(json['amount']),
    );
  }
}

class MealOptionUser {
  final int id;
  final String empName;
  final String dept;
  final String position;

  const MealOptionUser({
    required this.id,
    required this.empName,
    required this.dept,
    required this.position,
  });

  factory MealOptionUser.fromJson(Map<String, dynamic> json) {
    return MealOptionUser(
      id: _parseInt(json['id']),
      empName: (json['emp_name'] as String?) ?? '',
      dept: (json['dept'] as String?) ?? '',
      position: (json['position'] as String?) ?? '',
    );
  }
}

class MealOptionGroup {
  final String dept;
  final List<MealOptionUser> members;

  const MealOptionGroup({required this.dept, required this.members});

  factory MealOptionGroup.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'];
    final members =
        rawMembers is List
            ? rawMembers
                .whereType<Map>()
                .map(
                  (e) => MealOptionUser.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
            : <MealOptionUser>[];
    return MealOptionGroup(
      dept: (json['dept'] as String?) ?? '',
      members: members,
    );
  }
}

class MealOptions {
  final String ym;
  final List<MealOptionUser> users;
  final List<MealOptionGroup> groups;

  const MealOptions({
    required this.ym,
    required this.users,
    required this.groups,
  });

  factory MealOptions.fromJson(Map<String, dynamic> json) {
    final rawUsers = json['users'];
    final rawGroups = json['groups'];
    final users =
        rawUsers is List
            ? rawUsers
                .whereType<Map>()
                .map(
                  (e) => MealOptionUser.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
            : <MealOptionUser>[];
    final groups =
        rawGroups is List
            ? rawGroups
                .whereType<Map>()
                .map(
                  (e) => MealOptionGroup.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
            : <MealOptionGroup>[];
    return MealOptions(
      ym: (json['ym'] as String?) ?? '',
      users: users,
      groups: groups,
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
  final int createdById;
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
    required this.createdById,
    required this.createdByName,
    required this.canEdit,
    required this.canDelete,
    required this.participantsCount,
    required this.participantsSum,
    required this.participants,
  });

  factory MealClaimItem.fromJson(Map<String, dynamic> json) {
    final createdBy = _parseCreatedBy(json);
    return MealClaimItem(
      id: _parseInt(json['id']),
      ym: (json['ym'] as String?) ?? '',
      usedDate: _parseDate(json['used_date']),
      merchantName: (json['merchant_name'] as String?) ?? '',
      approvalNo: (json['approval_no'] as String?) ?? '',
      totalAmount: _parseInt(json['total_amount']),
      myAmount: _parseInt(json['my_amount']),
      createdById: createdBy.id,
      createdByName: createdBy.name,
      canEdit: _parseBool(json['can_edit']),
      canDelete: _parseBool(json['can_delete']),
      participantsCount: _parseInt(json['participants_count']),
      participantsSum: _parseInt(json['participants_sum']),
      participants: const <MealParticipant>[],
    );
  }

  factory MealClaimItem.fromDetailJson(Map<String, dynamic> json) {
    final createdBy = _parseCreatedBy(json);
    final rawParticipants = json['participants'];
    final participants =
        rawParticipants is List
            ? rawParticipants
                .whereType<Map>()
                .map(
                  (e) => MealParticipant.fromDetailJson(
                    Map<String, dynamic>.from(e),
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
      createdById: createdBy.id,
      createdByName: createdBy.name,
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
    int? createdById,
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
      createdById: createdById ?? this.createdById,
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

String _parseCreatedByName(Map<String, dynamic> json) {
  return (json['created_by_name'] as String?) ?? '';
}

_CreatedBy _parseCreatedBy(Map<String, dynamic> json) {
  final createdBy = json['created_by'];
  if (createdBy is Map) {
    final m = Map<String, dynamic>.from(createdBy);
    final id =
        _parseInt(m['id'] ?? m['user_id'] ?? m['emp_id'] ?? m['employee_id']);
    final name =
        (m['emp_name'] as String?) ??
        (m['name'] as String?) ??
        (m['full_name'] as String?) ??
        '';
    return _CreatedBy(id: id, name: name);
  }
  // 하위호환(혹시 예전 키가 있을 경우)
  return _CreatedBy(id: 0, name: _parseCreatedByName(json));
}

class _CreatedBy {
  final int id;
  final String name;

  const _CreatedBy({required this.id, required this.name});
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
