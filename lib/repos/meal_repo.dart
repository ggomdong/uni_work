import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_summary_model.dart';
import '../repos/authentication_repo.dart';

class MealRepository {
  final Dio _dio;

  MealRepository(this._dio);

  Future<MealSummaryModel> getMySummary({String? ym}) async {
    final response = await _dio.get(
      'api/v1/meals/my/summary/',
      queryParameters: ym == null ? null : {'ym': ym},
    );
    return MealSummaryModel.fromJson(response.data as Map<String, dynamic>);
  }
}

final mealRepoProvider = Provider<MealRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return MealRepository(authRepository.dio);
});
