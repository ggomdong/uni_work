import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_summary_model.dart';
import '../repos/meal_repo.dart';

class MealSummaryViewModel
    extends FamilyAsyncNotifier<MealSummaryModel, String?> {
  MealRepository get _repo => ref.read(mealRepoProvider);

  @override
  Future<MealSummaryModel> build(String? ym) async {
    return await _repo.getMySummary(ym: ym);
  }

  Future<void> refresh() async {
    final ym = arg;
    state = await AsyncValue.guard(() => _repo.getMySummary(ym: ym));
  }
}

final mealSummaryProvider = AsyncNotifierProviderFamily<
  MealSummaryViewModel,
  MealSummaryModel,
  String?
>(MealSummaryViewModel.new);
