import 'dart:convert';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/user_model.dart';

class RotatingGlowingAvatar extends StatefulWidget {
  final UserModel? user;
  final String? customPhoto;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onCameraTap;
  final bool? showCameraBadge;

  const RotatingGlowingAvatar({
    super.key,
    required this.user,
    this.customPhoto,
    this.size = 80,
    this.onTap,
    this.onCameraTap,
    this.showCameraBadge,
  });

  @override
  State<RotatingGlowingAvatar> createState() => _RotatingGlowingAvatarState();
}

class _RotatingGlowingAvatarState extends State<RotatingGlowingAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const SweepGradient _sweepGradient = SweepGradient(
    colors: [
      Color(0xFF71A246),
      Color(0x2071A246),
      Color(0xFF5D8A38),
      Color(0xFF3A5A22),
      Color(0xFF71A246),
    ],
  );

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final initials = user?.initials ?? 'PT';
    final photo = widget.customPhoto ?? user?.photo;

    // Build the static inner core once so it is not rebuilt 60 times/sec
    final coreAvatar = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF71A246), width: 2.8),
        color: const Color(0xFFE0EFD6),
      ),
      child: ClipOval(
        child: _buildAvatarContent(photo, initials),
      ),
    );

    final bool isPharmacien = user?.isPharmacien == true ||
        user?.isJeunePharmacie == true ||
        user?.idRole == 4;
    final bool shouldShowCamera = (widget.showCameraBadge ?? isPharmacien) && isPharmacien;

    return RepaintBoundary(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _controller,
              child: coreAvatar,
              builder: (context, child) {
                final angle = _controller.value * 2 * math.pi;
                final pulse = (math.sin(angle) + 1) / 2; // 0..1

                return Container(
                  width: widget.size + 14,
                  height: widget.size + 14,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color.fromRGBO(113, 162, 70, 0.22 + 0.20 * pulse),
                        blurRadius: 14 + 6 * pulse,
                        spreadRadius: 2 + 3 * pulse,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating subtle gradient ring
                      Transform.rotate(
                        angle: angle,
                        child: Container(
                          width: widget.size + 6,
                          height: widget.size + 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _sweepGradient,
                          ),
                        ),
                      ),

                      // Inner white spacer ring
                      Container(
                        width: widget.size + 1,
                        height: widget.size + 1,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),

                      // Static core passed as pre-built child
                      child!,
                    ],
                  ),
                );
              },
            ),
          ),

          // Small Green Camera Badge (Identique React .hp-camera-btn - Pharmacien UNIQUEMENT)
          if (shouldShowCamera)
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onCameraTap ?? widget.onTap,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F8F4F),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.camera,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarContent(String? photo, String initials) {
    if (photo != null) {
      final p = photo.trim();
      if (p.isNotEmpty &&
          p != 'null' &&
          p != 'undefined' &&
          p != 'none' &&
          p != 'default.png') {
        if (p.startsWith('data:image') || p.startsWith('data:')) {
          try {
            final commaIndex = p.indexOf(',');
            final base64Str = commaIndex != -1 ? p.substring(commaIndex + 1) : p;
            final bytes = base64Decode(base64Str.replaceAll(RegExp(r'\s+'), ''));
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: widget.size,
              height: widget.size,
              errorBuilder: (ctx, err, stack) => _buildInitials(initials),
            );
          } catch (_) {
            return _buildInitials(initials);
          }
        } else if (p.startsWith('http://') || p.startsWith('https://')) {
          return CachedNetworkImage(
            imageUrl: p,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            placeholder: (ctx, url) => _buildInitials(initials),
            errorWidget: (ctx, url, err) => _buildInitials(initials),
          );
        } else if (p.contains('.') || p.contains('/')) {
          final fullUrl = p.startsWith('/')
              ? '${AppConstants.backBaseUrl}${p.substring(1)}'
              : '${AppConstants.backBaseUrl}uploads/$p';
          return CachedNetworkImage(
            imageUrl: fullUrl,
            fit: BoxFit.cover,
            width: widget.size,
            height: widget.size,
            placeholder: (ctx, url) => _buildInitials(initials),
            errorWidget: (ctx, url, err) => _buildInitials(initials),
          );
        } else if (p.length > 80) {
          try {
            final bytes = base64Decode(p.replaceAll(RegExp(r'\s+'), ''));
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: widget.size,
              height: widget.size,
              errorBuilder: (ctx, err, stack) => _buildInitials(initials),
            );
          } catch (_) {
            return _buildInitials(initials);
          }
        }
      }
    }
    return Image.asset(
      'assets/images/avatar-mobile.png',
      fit: BoxFit.cover,
      width: widget.size,
      height: widget.size,
      errorBuilder: (ctx, err, stack) => _buildInitials(initials),
    );
  }

  Widget _buildInitials(String initials) {
    final text = initials.trim().isNotEmpty ? initials.trim() : 'PT';
    return Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF71A246), Color(0xFF3A5A22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: widget.size * 0.35,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
