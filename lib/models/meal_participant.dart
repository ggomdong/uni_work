import '../utils/meal_utils.dart';

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
      userId: parseInt(json['user_id']),
      name: (json['emp_name'] as String?) ?? (json['name'] as String?) ?? '',
      amount: parseInt(json['amount']),
    );
  }
}
