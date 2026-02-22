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
    required this.participants,
  });

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
      participants: participants ?? this.participants,
    );
  }
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
