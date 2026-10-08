import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/services/app_update_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/rotating_glowing_avatar.dart';

class HomePatientScreen extends StatefulWidget {
  const HomePatientScreen({super.key});

  @override
  State<HomePatientScreen> createState() => _HomePatientScreenState();
}

class _HomePatientScreenState extends State<HomePatientScreen> {
  final ScrollController _scrollController = ScrollController();
  int _currentTabIndex = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().fetchUnreadNotifications();
      AppUpdateService.checkForUpdate(context);
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      setState(() => _currentTabIndex = 0);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    if (index == _currentTabIndex) return;
    if (index == 1) {
      Navigator.pushNamed(context, AppRoutes.actualites);
    } else if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.profile);
    } else if (index == 3) {
      _showLogoutDialog();
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AuthProvider>().logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.signIn, (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Bonjour';
    if (hour >= 12 && hour < 18) return 'Bon après-midi';
    return 'Bonne soirée';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final displayName = user?.displayName ?? 'Patient';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GRADIENT ORBS ───
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryGreen.withValues(alpha: 0.20),
                    AppColors.primaryGreen.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 220,
            left: -100,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 110),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── UNIFIED SLEEK HEADER BAR ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    child: Row(
                      children: [
                        // User info with glowing avatar (Expanded to prevent overflow)
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                            borderRadius: BorderRadius.circular(30),
                            child: Row(
                              children: [
                                RotatingGlowingAvatar(
                                  user: user,
                                  size: 48,
                                  showCameraBadge: false,
                                  onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_getGreeting()} 👋',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryGreenDark,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.forestGreen,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.1),

                        const SizedBox(width: 8),

                        // Header Actions (Quick Scan & Notifications)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeaderActionButton(
                              icon: LucideIcons.scanLine,
                              label: 'Scan',
                              onTap: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
                            ),
                            const SizedBox(width: 6),
                            _buildHeaderActionButton(
                              icon: LucideIcons.bell,
                              badgeCount: auth.unreadNotifications,
                              onTap: () => Navigator.pushNamed(context, AppRoutes.actualites),
                            ),
                          ],
                        ).animate().fadeIn(duration: 350.ms).slideX(begin: 0.1),
                      ],
                    ),
                  ),

                  // ─── HERO FEATURE CARD: PHARMACIES (MATCHING ORIGINAL + MODERN TOUCH) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: _buildHeroPharmaciesCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.gardesMap),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).scale(begin: const Offset(0.97, 0.97)),
                  ),
                  const SizedBox(height: 20),

                  // ─── 2X2 MODERN CLEAN CARDS (EXACT ORIGINAL NAMES & ICONS) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.95,
                      children: [
                        _buildMenuCard(
                          icon: LucideIcons.idCard,
                          label: 'Profil santé',
                          delayMs: 200,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.carteSoin),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.check,
                          label: 'Mes traitements',
                          delayMs: 250,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.observance),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.fileText,
                          label: 'Dossier pharmaceutique',
                          delayMs: 300,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.dossierPatient),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.pill,
                          label: 'Éducation thérapeutique',
                          delayMs: 350,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.educationTherapeutique),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ─── QUICK SCANNER ACTION BANNER ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildScannerBannerCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
                    ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
                  ),
                  const SizedBox(height: 14),

                  // ─── DAILY HEALTH ADVICE WIDGET ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildDailyHealthTipCard().animate().fadeIn(delay: 450.ms, duration: 400.ms),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTabIndex,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    String? label,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return _InteractivePressCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: label != null ? 12 : 10, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3820).withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.forestGreen),
                if (label != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ],
              ],
            ),
            if (badgeCount > 0)
              Positioned(
                top: -5,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    badgeCount > 9 ? '9+' : badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroPharmaciesCard({required VoidCallback onTap}) {
    return _InteractivePressCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF163820), Color(0xFF0F2916)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F2916).withValues(alpha: 0.40),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Ambient glowing green light orb inside card
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withValues(alpha: 0.18),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Logo container with crisp white badge & subtle shadow
                  Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.20),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/icone-40.png',
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        LucideIcons.mapPin,
                        color: AppColors.primaryGreen,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Pharmacies',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Pulsing live indicator
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF4ADE80),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF4ADE80).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Trouver la pharmacie ouverte',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right Action Circle
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String label,
    required int delayMs,
    required VoidCallback onTap,
  }) {
    return _InteractivePressCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E3820).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Modern Green Glossy Squircle with specular reflection & layered bloom
            Stack(
              alignment: Alignment.center,
              children: [
                // Soft background halo
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF71A246).withValues(alpha: 0.12),
                  ),
                ),
                // Main Squircle with gloss border & 3D gradient
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7CB84E), Color(0xFF5A8736)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF71A246).withValues(alpha: 0.40),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: const Color(0xFF163820).withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(17),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Gloss specular shine (top-half curved light reflection)
                        Positioned(
                          top: -10,
                          left: -10,
                          right: -10,
                          height: 34,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.32),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),
                        // Icon with micro drop-shadow for premium relief
                        Icon(
                          icon,
                          color: Colors.white,
                          size: 26,
                          shadows: [
                            Shadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              offset: const Offset(0, 1.5),
                              blurRadius: 3,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                height: 1.25,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delayMs), duration: 350.ms).slideY(begin: 0.08);
  }

  Widget _buildScannerBannerCard({required VoidCallback onTap}) {
    return _InteractivePressCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35), width: 1.4),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryGreen.withValues(alpha: 0.09),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(LucideIcons.qrCode, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanner un produit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forestGreen,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scannez le QR Code de votre ordonnance ou boîte',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.arrowRight, color: AppColors.primaryGreen, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyHealthTipCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7EC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.sparkles, color: AppColors.primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conseil Santé du Jour',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestGreen,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Respectez scrupuleusement les horaires de prise de vos médicaments indiqués sur votre ordonnance.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: AppColors.textSubtitle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractivePressCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _InteractivePressCard({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_InteractivePressCard> createState() => _InteractivePressCardState();
}

class _InteractivePressCardState extends State<_InteractivePressCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}


