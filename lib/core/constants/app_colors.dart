import 'package:flutter/material.dart';

class AppColors {
  // Primary Palette - Emerald / Teal / Deep Slate
  static const Color primary = Color(0xFF0F766E); // Emerald 700
  static const Color primaryDark = Color(0xFF0D9488); // Teal 600
  static const Color primaryLight = Color(0xFFCCFBF1); // Teal 100
  static const Color accent = Color(0xFF10B981); // Emerald 500

  // Neutral Colors
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE2E8F0); // Slate 200
  
  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textMuted = Color(0xFF94A3B8); // Slate 400

  // Status / Action Colors
  static const Color income = Color(0xFF10B981); // Emerald Green
  static const Color incomeBg = Color(0xFFD1FAE5);
  static const Color expense = Color(0xFFEF4444); // Rose Red
  static const Color expenseBg = Color(0xFFFEE2E2);
  static const Color warning = Color(0xFFF59E0B); // Amber
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color info = Color(0xFF3B82F6); // Blue

  // Account Type Colors
  static const Color bankColor = Color(0xFF1E40AF); // Deep Blue
  static const Color walletColor = Color(0xFF7C3AED); // Purple
  static const Color cashColor = Color(0xFF059669); // Green
  static const Color otherColor = Color(0xFF475569); // Slate

  // Shadows & Gradients
  static final List<BoxShadow> softShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F766E).withOpacity(0.06),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
