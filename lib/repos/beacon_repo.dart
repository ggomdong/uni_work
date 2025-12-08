import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beacon_model.dart';
import '../repos/authentication_repo.dart';

class BeaconRepository {
  final Dio _dio;

  BeaconRepository(this._dio);

  Future<List<BeaconModel>> fetchBeacons() async {
    try {
      final response = await _dio.get('api/beacons/');

      // 응답은 List 형태라고 가정
      final data = response.data as List<dynamic>;
      return data
          .map((e) => BeaconModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 필요하면 DioException 분기해서 세부 처리도 가능
      throw Exception('비콘 정보 조회 중 오류 발생: $e');
    }
  }
}

final beaconRepo = Provider<BeaconRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return BeaconRepository(authRepository.dio);
});
