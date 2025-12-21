import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'view_models/attendance_view_model.dart';
import 'view_models/profile_view_model.dart';
import 'view_models/monthly_attendance_view_model.dart'; // YM, monthlyAttendanceProvider, nonBusinessDayProvider

final appRefreshServiceProvider = Provider<AppRefreshService>((ref) {
  return AppRefreshService(ref);
});

class AppRefreshService {
  AppRefreshService(this.ref);
  final Ref ref;

  Future<void> refreshAll({YM? ym}) async {
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

    // 2) 즉시 재호출(버튼 누른 직후 바로 갱신 체감)
    final futures = <Future<void>>[
      ref.read(attendanceProvider.notifier).refresh(),
      ref.read(profileViewModelProvider.notifier).refresh(),

      if (ym != null)
        ref.read(monthlyAttendanceProvider(ym).notifier).refresh(),
      if (ym != null) ref.read(nonBusinessDayProvider(ym).future).then((_) {}),
    ];

    await Future.wait(futures);
  }
}
