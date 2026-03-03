import 'meal_option_group.dart';
import 'meal_option_user.dart';

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
                  (e) => MealOptionUser.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList()
            : <MealOptionUser>[];
    final groups =
        rawGroups is List
            ? rawGroups
                .whereType<Map>()
                .map(
                  (e) => MealOptionGroup.fromJson(Map<String, dynamic>.from(e)),
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
