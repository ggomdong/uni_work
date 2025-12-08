import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:intl/intl.dart';
import '../view_models/settings_view_model.dart';
import '../repos/authentication_repo.dart';

bool isDarkMode(WidgetRef ref) => ref.watch(settingsProvider).darkMode;

// 텍스트 편집 업데이트를 처리하기 위해 formatEditUpdate 메서드를 재정의
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    String formatted = digits;
    if (digits.length > 4) {
      formatted =
          '${digits.substring(0, 4)}-${digits.substring(4, digits.length)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// initialUsername 을 가져올때 포맷팅하는 유틸함수
String? formatInitialPhone(String? fullPhone) {
  if (fullPhone == null) return null;
  final digits = fullPhone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('010')) {
    final body = digits.substring(3); // '12345678'
    return PhoneInputFormatter()
        .formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(text: body),
        )
        .text;
  }
  return null;
}

void triggerHaptic(BuildContext context) async {
  try {
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      HapticFeedback.heavyImpact();
    } else {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(duration: 40);
      }
    }
  } catch (_) {
    // 플랫폼 예외 무시
  }
}

String formatTime(DateTime? time) {
  if (time == null) return "-";
  return DateFormat('HH:mm:ss').format(time);
}

TimeOfDay parseTimeOfDay(String timeStr) {
  final parts = timeStr.split(":");
  return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
}

Future<void> openPrivacy(WidgetRef ref) async {
  final authRepository = ref.read(authRepo);
  final baseUrl =
      authRepository.dio.options.baseUrl; // ex) https://wsnuni.co.kr/
  final uri = Uri.parse(
    '${baseUrl}wtm/privacy/',
  ); // → https://wsnuni.co.kr/wtm/privacy/

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

  if (!ok) {
    // 필요하면 스낵바 등으로 안내
    throw '개인정보처리방침 페이지를 열 수 없습니다.';
  }
}
