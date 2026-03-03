import 'dart:async';

import 'package:flutter/material.dart';

class AppToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration? duration,
  }) {
    _removeCurrent();

    final overlay = Overlay.of(context, rootOverlay: true);

    final safeDuration = duration ?? const Duration(milliseconds: 1700);

    _entry = OverlayEntry(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Positioned(
          left: 16,
          right: 16,
          bottom: 16 + bottomInset,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Material(
              color: Colors.transparent,
              child: _ToastCard(
                message: message,
                backgroundColor: backgroundColor,
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);
    _timer = Timer(safeDuration, _removeCurrent);
  }

  static void _removeCurrent() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }
}

class _ToastCard extends StatelessWidget {
  final String message;
  final Color? backgroundColor;

  const _ToastCard({required this.message, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.black87,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
