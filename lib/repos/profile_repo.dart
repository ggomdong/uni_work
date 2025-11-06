import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repos/authentication_repo.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<ProfileModel> fetchProfile() async {
    final res = await _dio.get('/api/profile/');
    return ProfileModel.fromJson(res.data as Map<String, dynamic>);
  }
}

final profileRepo = Provider<ProfileRepository>((ref) {
  final authRepository = ref.read(authRepo);
  return ProfileRepository(authRepository.dio);
});
