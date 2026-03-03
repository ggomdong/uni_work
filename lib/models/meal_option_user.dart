import '../utils/meal_utils.dart';

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
      id: parseInt(json['id']),
      empName: (json['emp_name'] as String?) ?? '',
      dept: (json['dept'] as String?) ?? '',
      position: (json['position'] as String?) ?? '',
    );
  }
}
