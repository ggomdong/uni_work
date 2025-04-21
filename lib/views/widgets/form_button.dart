import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/sizes.dart';
import '../../view_models/settings_view_model.dart';

class FormButton extends ConsumerWidget {
  const FormButton({
    super.key,
    required this.disabled,
    required this.text,
    required this.onTap,
  });

  final bool disabled;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isDark = ref.watch(settingsProvider).darkMode;
    return GestureDetector(
      onTap: onTap,
      child: FractionallySizedBox(
        widthFactor: 1,
        child: AnimatedContainer(
          padding: EdgeInsets.symmetric(vertical: Sizes.size16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color:
                disabled
                    ? isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade600
                    : Theme.of(context).primaryColor,
          ),
          duration: const Duration(milliseconds: 500),
          child: AnimatedDefaultTextStyle(
            duration: Duration(microseconds: 500),
            style: TextStyle(
              color: disabled ? Colors.grey.shade400 : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: Sizes.size16,
            ),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
