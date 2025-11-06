import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile_model.dart';
import '../repos/profile_repo.dart';

final profileViewModelProvider =
    AsyncNotifierProvider<ProfileViewModel, ProfileModel?>(
      ProfileViewModel.new,
    );

class ProfileViewModel extends AsyncNotifier<ProfileModel?> {
  late final ProfileRepository _repo;

  @override
  Future<ProfileModel?> build() async {
    _repo = ref.read(profileRepo);
    return _repo.fetchProfile();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.fetchProfile());
  }
}
