import 'package:flutter/material.dart';

class AppColors {
  // Brand Greens
  static const Color primaryGreen = Color(0xFF71A246);
  static const Color primaryGreenDark = Color(0xFF5D8A38);
  static const Color primaryGreenLight = Color(0xFF88BF56);
  static const Color forestGreen = Color(0xFF163820);
  static const Color deepForestGreen = Color(0xFF0F2916);
  static const Color darkEmerald = Color(0xFF1B4332);
  static const Color darkEmeraldDeep = Color(0xFF081C15);

  // Backgrounds & Neutrals
  static const Color scaffoldBackground = Color(0xFFF0F4F8);
  static const Color cardBackground = Colors.white;
  static const Color inputBackground = Color(0xFFF7F9FC);
  static const Color borderGray = Color(0xFFE4EAF3);
  static const Color lightGray = Color(0xFFE2E8F0);

  // Text Colors
  static const Color textPrimary = Color(0xFF1E2D5A);
  static const Color textHeading = Color(0xFF163820);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color textMuted = Color(0xFF8EA0B8);
  static const Color textSubtitle = Color(0xFF4B6A3A);

  // Status & Accents
  static const Color error = Color(0xFFEF4444);
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [darkEmerald, darkEmeraldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroBackgroundOverlay = LinearGradient(
    colors: [
      Color(0xC7FFFFFF), // 78% White
      Color(0xB7F0F8EB), // 72% Soft Mint
      Color(0x2671A246), // 15% Green
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
