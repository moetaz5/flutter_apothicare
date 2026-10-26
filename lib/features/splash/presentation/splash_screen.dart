import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/actualite_provider.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../admin/presentation/home_admin_screen.dart';
import '../../auth/presentation/sign_in_screen.dart';
import '../../home_patient/presentation/home_patient_screen.dart';
import '../../home_pharmacien/presentation/home_pharmacien_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  double _loadingProgress = 0.0;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _startAppInitialization();
  }

  void _startAppInitialization() {
    // Smooth progress simulation
    const totalSteps = 20;
    int currentStep = 0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 90), (timer) {
      if (!mounted) return;
      currentStep++;
      setState(() {
        _loadingProgress = (currentStep / totalSteps).clamp(0.0, 1.0);
      });
      if (currentStep >= totalSteps) {
        timer.cancel();
        _navigateNext();
      }
    });

    // Background preload tasks
    Future.microtask(() async {
      try {
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        if (auth.isAuthenticated) {
          auth.fetchUnreadNotifications();
          final user = auth.currentUser;
          if (!mounted) return;
          if (user?.isAdmin == true || user?.idRole == 1) {
            context.read<AdminProvider>().fetchUsers();
            context.read<AdminProvider>().fetchAnnees();
          }
          if (mounted) {
            context.read<ActualiteProvider>().fetchActualites();
          }
        }
      } catch (_) {}
    });
  }

  void _navigateNext() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser ?? StorageService.getUser();

    Widget nextScreen;
    final int roleId = user?.idRole ?? 0;
    if (!auth.isAuthenticated || user == null) {
      nextScreen = const SignInScreen();
    } else if (user.isAdmin == true || roleId == 1) {
      nextScreen = const HomeAdminScreen();
    } else if (user.isPatient == true || roleId == 3) {
      nextScreen = const HomePatientScreen();
    } else if (user.isPharmacien == true ||
        user.isJeunePharmacie == true ||
        roleId == 2 ||
        roleId == 4 ||
        roleId == 7 ||
        roleId == 8) {
      nextScreen = const HomePharmacienScreen();
    } else {
      // Unauthorized role
      StorageService.clearAll();
      nextScreen = const SignInScreen();
      Future.microtask(() {
        AppToast.showError("Vous n'avez pas l'accès pour utiliser cette application.");
      });
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // ─── 1. Organic Clean Gradient Background ───
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.2),
                  radius: 1.2,
                  colors: [
                    Color(0xFFF3F9EE), // Very soft, fresh organic mint tint at core
                    Color(0xFFF9FBF7),
                    Colors.white,
                  ],
                  stops: [0.0, 0.45, 1.0],
                ),
              ),
            ),

          // ─── 2. Floating Ambient Glow Orbs ───
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final scale = 1.0 + (_pulseController.value * 0.15);
              final opacity = 0.12 + (_pulseController.value * 0.08);
              return Positioned(
                top: size.height * 0.28 - (160 * scale / 2),
                left: size.width * 0.5 - (160 * scale / 2),
                child: Container(
                  width: 160 * scale,
                  height: 160 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withValues(alpha: opacity),
                        blurRadius: 90,
                        spreadRadius: 30,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ─── 3. Subtle background grid / pattern dots ───
          Positioned.fill(
            child: Opacity(
              opacity: 0.02,
              child: Image.asset(
                'assets/images/back-mobile.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          // ─── 4. Main Center Content (Logo, Branding, Typography) ───
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(height: 20),

                // Center Identity Block
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated Logo Badge with Rotating Radiant Aura
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer Pulsing Ripple Ring
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              return Container(
                                width: 124 + (_pulseController.value * 16),
                                height: 124 + (_pulseController.value * 16),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primaryGreen.withValues(
                                      alpha: 0.35 * (1.0 - _pulseController.value),
                                    ),
                                    width: 2,
                                  ),
                                ),
                              );
                            },
                          ),

                          // Inner Glow Ring
                          Container(
                            width: 114,
                            height: 114,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF88BF56),
                                  Color(0xFF71A246),
                                  Color(0xFF5D8A38),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.30),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),

                          // Pristine White Circular Badge
                          Container(
                            width: 104,
                            height: 104,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.forestGreen.withValues(alpha: 0.12),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(18),
                            child: Image.asset(
                              'assets/images/logo1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .scale(
                            duration: 800.ms,
                            curve: Curves.easeOutBack,
                            begin: const Offset(0.4, 0.4),
                            end: const Offset(1.0, 1.0),
                          )
                          .fadeIn(duration: 600.ms),

                      const SizedBox(height: 28),

                      // Brand Title: "APOTHICARE"
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'APOTHICARE',
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.forestGreen,
                              letterSpacing: 4.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryGreen, // Vibrant green dot
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      )
                          .animate()
                          .fadeIn(delay: 350.ms, duration: 600.ms)
                          .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),

                        const SizedBox(height: 10),

                      // Official CNOPT Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primaryGreen.withValues(alpha: 0.28),
                            width: 1.2,
                          ),
                        ),
                        child: Text(
                          'CONSEIL NATIONAL DE L\'ORDRE DES PHARMACIENS',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreenDark,
                            letterSpacing: 1.0,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.9, 0.9)),

                      const SizedBox(height: 14),

                      // Tagline / Features Pill
                      Text(
                        'ORDRE • HONNEUR • UNION',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSubtitle,
                          letterSpacing: 1.0,
                        ),
                      ).animate().fadeIn(delay: 650.ms, duration: 600.ms),
                    ],
                  ),
                ),

                // ─── 5. Bottom Loading Indicator & Version ───
                Padding(
                  padding: const EdgeInsets.only(bottom: 30, left: 40, right: 40),
                  child: Column(
                    children: [
                      // Smooth Gradient Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 4,
                          width: 160,
                          color: AppColors.primaryGreen.withValues(alpha: 0.15),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 90),
                              height: 4,
                              width: 160 * _loadingProgress,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF71A246),
                                    Color(0xFF5D8A38),
                                    Color(0xFF88BF56),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.35),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sub-status
                      Text(
                        'Chargement des services…',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubtitle.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 700.ms, duration: 500.ms),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}
