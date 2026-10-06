import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/user_model.dart';
import 'rotating_glowing_avatar.dart';

class HeaderAvatar extends StatelessWidget {
  final UserModel? user;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onActionTap;
  final String? actionTitle;

  const HeaderAvatar({
    super.key,
    required this.user,
    this.onAvatarTap,
    this.onActionTap,
    this.actionTitle,
  });

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour 👋';
    if (hour < 18) return 'Bon après-midi 👋';
    return 'Bonne soirée 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName ?? 'Espace Santé';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 20, bottom: 24, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular Avatar with rotating green glow ring
          RotatingGlowingAvatar(
            user: user,
            size: 80,
            onTap: onAvatarTap,
          ),
          const SizedBox(height: 12),

          // Context greeting pill (identique React)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.25),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _getGreeting(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B6A3A),
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),

          // User Name formatted
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.forestGreen,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

