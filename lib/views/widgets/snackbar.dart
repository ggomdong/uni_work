import 'package:flutter/material.dart';

// message, color를 인수로 받아 SnackBar를 보여주는 함수
void showSnackBar(BuildContext context, String message, Color color) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message, textAlign: TextAlign.center),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: Duration(milliseconds: 1500),
    ),
  );
}
