import 'package:flutter/material.dart';

class StatusTheme {
  final Color fg;
  final Color dot;
  final Color? bg;
  final Color? border;
  const StatusTheme({required this.fg, Color? dot, this.bg, this.border})
    : dot = dot ?? fg;
}

const Map<String, StatusTheme> kStatusTheme = {
  "NORMAL": StatusTheme(fg: Color(0xFF10B981)),
  "ERROR": StatusTheme(fg: Color(0xFFEF4444)),
  "LATE": StatusTheme(fg: Colors.amber),
  "EARLY": StatusTheme(fg: Color(0xFFA78BFA)),
  "OVERTIME": StatusTheme(fg: Color(0xFF38BDF8)),
  "HOLIDAY": StatusTheme(
    fg: Colors.black,
    // dot: Color(0xFF65A30D),
    // bg: Color(0xFFF7FEE7),
    // border: Color(0xFFEAF7B1),
  ),
  "OFF": StatusTheme(fg: Colors.black12),
  "PAY": StatusTheme(fg: Colors.black12),
  "NOPAY": StatusTheme(fg: Colors.black12),
  "NOSCHEDULE": StatusTheme(fg: Color(0xFF9CA3AF)),
};

StatusTheme themeOf(String? code) =>
    kStatusTheme[code] ?? const StatusTheme(fg: Color(0xFF9CA3AF));

Color resolveStatusColor(BuildContext _, String? code) => themeOf(code).fg;
Color resolveDotColor(String? code) => themeOf(code).dot;
Color resolveChipBg(String? code) {
  final t = themeOf(code);
  return (t.bg ?? t.fg.withValues(alpha: 0.12));
}
