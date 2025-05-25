import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/settings_view_model.dart';

bool isDarkMode(WidgetRef ref) => ref.watch(settingsProvider).darkMode;

class PhoneInputFormatter extends TextInputFormatter {
  // 텍스트 편집 업데이트를 처리하기 위해 formatEditUpdate 메서드를 재정의
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
