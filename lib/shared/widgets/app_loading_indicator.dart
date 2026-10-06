import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Un composant de chargement unifié, moderne et optimisé pour toutes les pages d'Apothicare.
/// Garantit fluidité (60/120 FPS), zéro freeze et cohérence visuelle avec la charte graphique.
class AppLoadingIndicator extends StatefulWidget {
  final String? message;
  final double size;
  final Color? color;
  final bool isSmall;

  const AppLoadingIndicator({
    super.key,
    this.message,
    this.size = 52.0,
    this.color,
    this.isSmall = false,
  });

  /// Version compacte pour les boutons, badges et petites zones
  const AppLoadingIndicator.small({
    super.key,
    this.size = 20.0,
    this.color,
  })  : message = null,
        isSmall = true;

  /// Version pleine page centrée avec texte descriptif
  const AppLoadingIndicator.page({
    super.key,
    this.message = 'Chargement des données...',
    this.size = 56.0,
    this.color,
  }) : isSmall = false;

  /// Overlay bloquant semi-transparent avec carte centrale
  static Widget fullScreen({String message = 'Veuillez patienter...'}) {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
        margin: const EdgeInsets.symmetric(horizontal: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLoadingIndicator(size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<AppLoadingIndicator> createState() => _AppLoadingIndicatorState();
}

class _AppLoadingIndicatorState extends State<AppLoadingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.primaryGreen;

    if (widget.isSmall) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * math.pi,
                child: CustomPaint(
                  painter: _SmallSpinnerPainter(color: activeColor),
                ),
              );
            },
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Halo lumineux d'arrière-plan
              Container(
                width: widget.size * 1.15,
                height: widget.size * 1.15,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withValues(alpha: 0.08),
                ),
              ),

              // Anneau rotatif double gradient
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _controller.value * 2 * math.pi,
                      child: CustomPaint(
                        painter: _ApothicareSpinnerPainter(
                          primaryColor: activeColor,
                          secondaryColor: AppColors.forestGreen,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Icône centrale stylisée
              Icon(
                Icons.local_pharmacy_rounded,
                size: widget.size * 0.42,
                color: activeColor,
              ),
            ],
          ),
          if (widget.message != null && widget.message!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              widget.message!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallSpinnerPainter extends CustomPainter {
  final Color color;

  _SmallSpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = math.max(2.0, size.width * 0.12)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    canvas.drawArc(rect, 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _SmallSpinnerPainter oldDelegate) => oldDelegate.color != color;
}

class _ApothicareSpinnerPainter extends CustomPainter {
  final Color primaryColor;
  final Color secondaryColor;

  _ApothicareSpinnerPainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 6) / 2;
    final strokeWidth = math.max(3.2, size.width * 0.075);

    // Track de fond subtil
    final bgPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);

    // Arc principal avec gradient fluide
    final sweepGradient = SweepGradient(
      colors: [
        primaryColor.withValues(alpha: 0.0),
        primaryColor.withValues(alpha: 0.6),
        primaryColor,
        secondaryColor,
      ],
      stops: const [0.0, 0.4, 0.75, 1.0],
    );

    final rect = Rect.fromCircle(center: center, radius: radius);
    final arcPaint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawArc(rect, 0, math.pi * 1.6, false, arcPaint);
  }

  @override
  bool shouldRepaint(covariant _ApothicareSpinnerPainter oldDelegate) =>
      oldDelegate.primaryColor != primaryColor || oldDelegate.secondaryColor != secondaryColor;
}
