import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meal_summary_model.dart';
import '../repos/authentication_repo.dart';
import '../views/widgets/meal_types.dart';

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

  Future<List<MealClaimItem>> getMyItems({required String ym}) async {
    final response = await _dio.get(
      'api/v1/meals/my/items/',
      queryParameters: {'ym': ym},
    );
    return _parseItems(response.data);
  }

  Future<List<MealClaimItem>> getMyCreated({required String ym}) async {
    final response = await _dio.get(
      'api/v1/meals/my/created/',
      queryParameters: {'ym': ym},
    );
    return _parseItems(response.data);
  }

  Future<MealClaimItem> getClaimDetail({required int claimId}) async {
    final response = await _dio.get('api/v1/meals/claims/$claimId/');
    final data = response.data;
    if (data is! Map) throw Exception('Invalid claim detail response');
    return MealClaimItem.fromDetailJson(Map<String, dynamic>.from(data));
  }

  List<MealClaimItem> _parseItems(dynamic data) {
    if (data is! Map) return <MealClaimItem>[];
    final items = data['items'];
    if (items is! List) return <MealClaimItem>[];
    return items
        .whereType<Map>()
        .map((e) => MealClaimItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final mealRepoProvider = Provider<MealRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return MealRepository(authRepository.dio);
});
