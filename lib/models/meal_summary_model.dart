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
      totalAmount: _parseInt(json['total_amount']),
      usedAmount: _parseInt(json['used_amount']),
      balance: _parseInt(json['balance']),
      claimCount: _parseInt(json['claim_count']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
