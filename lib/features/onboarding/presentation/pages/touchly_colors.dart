import 'package:flutter/material.dart';

/// Palette centralisée Touchly — à réutiliser partout au lieu de
/// redéfinir des constantes privées `_yellow`, `_navy`, etc. dans
/// chaque fichier.
class TouchlyColors {
  TouchlyColors._();

  static const bgDark      = Color(0xFF0A2A6E);
  static const bgLight     = Color(0xFF2979FF);
  static const bgDeep      = Color(0xFF060E30);
  static const yellow      = Color(0xFFFFD700);
  static const yellowDeep  = Color(0xFFFFB300);
  static const navy        = Color(0xFF0A1A4E);
  static const white       = Color(0xFFFFFFFF);
  static const textSub     = Color(0xFFB3C8F0);
  static const correct     = Color(0xFF22C55E);
  static const warn        = Color(0xFFFF6B35);
  static const danger      = Color(0xFFEF4444);
  static const answerA     = Color(0xFF6366F1);
  static const answerB     = Color(0xFF8B5CF6);
  static const answerC     = Color(0xFFEC4899);
  static const cyan        = Color(0xFF06B6D4);
  static const orange      = Color(0xFFF97316);

  static const List<Color> avatarPalette = [
    answerA, answerB, answerC, correct, warn, cyan, orange, yellow,
  ];

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1A5AE8), bgDark, bgDeep],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient primaryButtonGradient = LinearGradient(
    colors: [yellow, yellowDeep],
  );
}