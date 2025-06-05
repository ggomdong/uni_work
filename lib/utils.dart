import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/settings_view_model.dart';

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
