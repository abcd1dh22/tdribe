import 'package:flutter/material.dart';

class AppColors {
  static const p = Color(0xFF5B5BF0);
  static const p2 = Color(0xFF9A5CF6);
  static const danger = Color(0xFFE5484D);
}

ThemeData buildTheme(Brightness b) {
  final d = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.p, brightness: b)
      .copyWith(primary: AppColors.p, surface: d ? const Color(0xFF161827) : Colors.white);
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    scaffoldBackgroundColor: d ? const Color(0xFF0B0C14) : const Color(0xFFF3F4FA),
  );
}
