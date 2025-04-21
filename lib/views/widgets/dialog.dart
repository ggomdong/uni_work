import 'package:flutter/material.dart';

void showConfirmationDialog(BuildContext context, message, action) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('확인'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              action();
            },
            child: Text('네'),
          ),
        ],
      );
    },
  );
}
