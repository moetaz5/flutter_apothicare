import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
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
    if (hour >= 5 && hour < 12) return 'Bonjour 👋';
    if (hour >= 12 && hour < 18) return 'Bon après-midi 👋';
    return 'Bonne soirée 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = user?.displayName ?? 'Patient';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOWS ───
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryGreen.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            top: 180,
            left: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF244082).withValues(alpha: 0.05),
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
                children: [
                  // ─── TOP HERO HEADER (CENTERED PROFILE) ───
                  Padding(
                    padding: EdgeInsets.only(top: topPadding > 0 ? 8 : 16, bottom: 20, left: 20, right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar with glowing rotating ring
                        RotatingGlowingAvatar(
                          user: user,
                          size: 82,
                          showCameraBadge: false,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                        )
                            .animate()
                            .scale(duration: 400.ms, curve: Curves.easeOutBack)
                            .fadeIn(duration: 350.ms),

                        const SizedBox(height: 12),

                        // Time-aware greeting badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withValues(alpha: 0.10),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Text(
                            _getGreeting(),
                            style: const TextStyle(
                              color: Color(0xFF4B6A3A),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

                        const SizedBox(height: 8),

                        // Patient Name
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 23,
                            fontWeight: FontWeight.w900,
                            color: AppColors.forestGreen,
                            letterSpacing: -0.4,
                          ),
                        ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
                      ],
                    ),
                  ),

                  // ─── HERO FEATURE CARD: PHARMACIES ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAccentCard(
                      title: 'Pharmacies',
                      subtitle: 'Trouver la pharmacie ouverte',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.gardesMap),
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms).scale(begin: const Offset(0.97, 0.97)),
                  ),
                  const SizedBox(height: 18),

                  // ─── 2-COLUMN GRID (EXACT ORIGINAL ICONS & NAMES) ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: 0.98,
                      children: [
                        _buildMenuCard(
                          icon: LucideIcons.idCard,
                          label: 'Profil santé',
                          delayMs: 300,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.carteSoin),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.check,
                          label: 'Mes traitements',
                          delayMs: 350,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.observance),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.fileText,
                          label: 'Dossier pharmaceutique',
                          delayMs: 400,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.dossierPatient),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.pill,
                          label: 'Éducation thérapeutique',
                          delayMs: 450,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.educationTherapeutique),
                        ),
                      ],
                    ),
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

  Widget _buildAccentCard({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
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
              color: const Color(0xFF0F2916).withValues(alpha: 0.38),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative subtle background glow
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withValues(alpha: 0.18),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Row(
                children: [
                  // Logo container with crisp white badge & subtle shadow
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/icone-40.png',
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const Icon(
                        LucideIcons.mapPin,
                        color: AppColors.primaryGreen,
                        size: 26,
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
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.2,
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
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right action button
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.40),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 18),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF244082).withValues(alpha: 0.07),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Green Gradient Icon Squircle with glowing shadow
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withValues(alpha: 0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 27),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
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
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}


