import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static OverlayEntry? _currentEntry;

  /// Afficher une notification de succès en haut de l'écran
  static void showSuccess(String message, [BuildContext? context]) {
    show(message, context: context, isSuccess: true);
  }

  /// Afficher une notification d'erreur en haut de l'écran
  static void showError(String message, [BuildContext? context]) {
    show(message, context: context, isError: true);
  }

  /// Afficher une notification d'information en haut de l'écran
  static void showInfo(String message, [BuildContext? context]) {
    show(message, context: context, isSuccess: false, isError: false);
  }

  /// Affichage générique en haut de l'écran (identique React-Toastify)
  static void show(
    String message, {
    BuildContext? context,
    bool isError = false,
    bool isSuccess = false,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    if (message.trim().isEmpty) return;

    // Récupérer le contexte ou celui du navigatorKey global
    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) return;

    final overlayState = Overlay.maybeOf(targetContext) ??
        navigatorKey.currentState?.overlay;
    if (overlayState == null) return;

    // Supprimer tout toast existant
    _currentEntry?.remove();
    _currentEntry = null;

    final overlayEntry = OverlayEntry(
      builder: (ctx) => _TopToastWidget(
        message: message,
        isError: isError,
        isSuccess: isSuccess,
        onDismiss: () {
          _currentEntry?.remove();
          _currentEntry = null;
        },
        duration: duration,
      ),
    );

    _currentEntry = overlayEntry;
    overlayState.insert(overlayEntry);
  }
}

class _TopToastWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final bool isSuccess;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopToastWidget({
    required this.message,
    required this.isError,
    required this.isSuccess,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopToastWidget> createState() => _TopToastWidgetState();
}

class _TopToastWidgetState extends State<_TopToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      reverseDuration: const Duration(milliseconds: 250),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    // Auto dismiss
    Future.delayed(widget.duration, () {
      if (mounted) {
        _controller.reverse().then((_) {
          if (mounted) {
            widget.onDismiss();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissManually() {
    if (mounted) {
      _controller.reverse().then((_) {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    final Color bgColor = widget.isError
        ? const Color(0xFFE74C3C)
        : (widget.isSuccess ? const Color(0xFF27AE60) : const Color(0xFF2C3E50));

    final IconData icon = widget.isError
        ? LucideIcons.alertCircle
        : (widget.isSuccess ? LucideIcons.circleCheck : LucideIcons.info);

    return Positioned(
      top: topPadding + 10,
      left: 16,
      right: 16,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _dismissManually,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(LucideIcons.x, color: Colors.white70, size: 18),
                      onPressed: _dismissManually,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
