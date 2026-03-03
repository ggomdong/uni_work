import '../utils/meal_utils.dart';

class MealSummaryModel {
  final String? ym;
  final int totalAmount;
  final int usedAmount;
  final int balance;
  final int claimCount;

  const MealSummaryModel({
    required this.ym,
    required this.totalAmount,
    required this.usedAmount,
    required this.balance,
    required this.claimCount,
  });

  factory MealSummaryModel.fromJson(Map<String, dynamic> json) {
    return MealSummaryModel(
      ym: json['ym']?.toString(),
      totalAmount: parseInt(json['total_amount']),
      usedAmount: parseInt(json['used_amount']),
      balance: parseInt(json['balance']),
      claimCount: parseInt(json['claim_count']),
    );
  }
}
