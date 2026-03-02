import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view_models/attendance_view_model.dart';
import 'view_models/meal_items_view_model.dart';
import 'view_models/meal_summary_view_model.dart';
import 'view_models/profile_view_model.dart';
import 'view_models/monthly_attendance_view_model.dart'; // YM, monthlyAttendanceProvider, nonBusinessDayProvider

final appRefreshServiceProvider = Provider<AppRefreshService>((ref) {
  return AppRefreshService(ref);
});

class AppRefreshService {
  AppRefreshService(this.ref);
  final Ref ref;

  Future<void> refreshAll({YM? ym, List<String>? mealQueries}) async {
    // 1) 무효화: 현재 살아있는 화면들이면 즉시 재요청 유도
    ref.invalidate(attendanceProvider);
    ref.invalidate(profileViewModelProvider);

    if (ym != null) {
      ref.invalidate(monthlyAttendanceProvider(ym));
      ref.invalidate(nonBusinessDayProvider(ym));
    } else {
      // family 전체 무효화(살아있는 인스턴스들)
      ref.invalidate(monthlyAttendanceProvider);
      ref.invalidate(nonBusinessDayProvider);
    }

    if (ym != null) {
      ref.invalidate(mealSummaryProvider(_toMealYm(ym)));
    } else {
      ref.invalidate(mealSummaryProvider);
    }

    if (mealQueries != null && mealQueries.isNotEmpty) {
      for (final query in mealQueries) {
        ref.invalidate(mealItemsProvider(_toMealItemsQuery(query)));
      }
    } else {
      ref.invalidate(mealItemsProvider);
    }

    // 2) 즉시 재호출(버튼 누른 직후 바로 갱신 체감)
    final futures = <Future<void>>[
      ref.read(attendanceProvider.notifier).refresh(),
      ref.read(profileViewModelProvider.notifier).refresh(),

      if (ym != null)
        ref.read(monthlyAttendanceProvider(ym).notifier).refresh(),
      if (ym != null) ref.read(nonBusinessDayProvider(ym).future).then((_) {}),
      if (ym != null)
        ref.read(mealSummaryProvider(_toMealYm(ym)).notifier).refresh(),
      if (mealQueries != null)
        ...mealQueries.map(
          (query) =>
              ref
                  .read(mealItemsProvider(_toMealItemsQuery(query)).notifier)
                  .refresh(),
        ),
    ];

    await Future.wait(futures);
  }

  MealItemsQuery _toMealItemsQuery(String query) {
    final parts = query.split('|');
    final ym = parts.isNotEmpty ? parts.first : '';
    final type =
        parts.length > 1 && parts[1] == MealItemsType.used.name
            ? MealItemsType.used
            : MealItemsType.created;
    return MealItemsQuery(ym: ym, type: type);
  }

  String _toMealYm(YM ym) {
    final year = ym.year.toString().padLeft(4, '0');
    final month = ym.month.toString().padLeft(2, '0');
    return '$year$month';
  }
}
