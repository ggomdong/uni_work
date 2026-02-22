import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/meal_repo.dart';
import '../views/widgets/meal_types.dart';

enum MealItemsType { created, used }

class MealItemsQuery {
  final String ym;
  final MealItemsType type;

  const MealItemsQuery({required this.ym, required this.type});

  @override
  bool operator ==(Object other) {
    return other is MealItemsQuery && other.ym == ym && other.type == type;
  }

  @override
  int get hashCode => Object.hash(ym, type);
}

class MealItemsViewModel
    extends FamilyAsyncNotifier<List<MealClaimItem>, MealItemsQuery> {
  MealRepository get _repo => ref.read(mealRepoProvider);

  @override
  Future<List<MealClaimItem>> build(MealItemsQuery query) async {
    return await _fetch(query);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _fetch(arg));
  }

  Future<List<MealClaimItem>> _fetch(MealItemsQuery query) async {
    if (query.type == MealItemsType.created) {
      return await _repo.getMyCreated(ym: query.ym);
    }
    return await _repo.getMyItems(ym: query.ym);
  }
}

final mealItemsProvider = AsyncNotifierProviderFamily<
  MealItemsViewModel,
  List<MealClaimItem>,
  MealItemsQuery
>(MealItemsViewModel.new);
