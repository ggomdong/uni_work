import '../utils/meal_utils.dart';
import 'meal_participant.dart';

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
    final createdBy = parseCreatedBy(json);
    return MealClaimItem(
      id: parseInt(json['id']),
      ym: (json['ym'] as String?) ?? '',
      usedDate: parseDate(json['used_date']),
      merchantName: (json['merchant_name'] as String?) ?? '',
      approvalNo: (json['approval_no'] as String?) ?? '',
      totalAmount: parseInt(json['total_amount']),
      myAmount: parseInt(json['my_amount']),
      createdById: createdBy.id,
      createdByName: createdBy.name,
      canEdit: parseBool(json['can_edit']),
      canDelete: parseBool(json['can_delete']),
      participantsCount: parseInt(json['participants_count']),
      participantsSum: parseInt(json['participants_sum']),
      participants: const <MealParticipant>[],
    );
  }

  factory MealClaimItem.fromDetailJson(Map<String, dynamic> json) {
    final createdBy = parseCreatedBy(json);
    final rawParticipants = json['participants'];
    final participants =
        rawParticipants is List
            ? rawParticipants
                .whereType<Map>()
                .map(
                  (e) => MealParticipant.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : <MealParticipant>[];
    final count = parseInt(json['participants_count']);
    final sum = parseInt(json['participants_sum']);

    return MealClaimItem(
      id: parseInt(json['id']),
      ym: (json['ym'] as String?) ?? '',
      usedDate: parseDate(json['used_date']),
      merchantName: (json['merchant_name'] as String?) ?? '',
      approvalNo: (json['approval_no'] as String?) ?? '',
      totalAmount: parseInt(json['total_amount']),
      myAmount: parseInt(json['my_amount']),
      createdById: createdBy.id,
      createdByName: createdBy.name,
      canEdit: parseBool(json['can_edit']),
      canDelete: parseBool(json['can_delete']),
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
