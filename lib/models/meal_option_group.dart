import 'meal_option_user.dart';

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
                  (e) => MealOptionUser.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : <MealOptionUser>[];
    return MealOptionGroup(
      dept: (json['dept'] as String?) ?? '',
      members: members,
    );
  }
}
