import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<bool?> showPlatformConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String cancelText = '아니오',
  String confirmText = '네',
  bool isDestructive = false,
}) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS) {
    return showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelText),
            ),
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(true),
              isDestructiveAction: isDestructive,
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmText),
          ),
        ],
      );
    },
  );
}

void showConfirmationDialog(BuildContext context, message, action) async {
  final result = await showPlatformConfirm(
    context: context,
    title: '확인',
    message: message.toString(),
  );
  if (result == true) {
    action();
  }
}
