import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/rotating_glowing_avatar.dart';

class HomePharmacienScreen extends StatefulWidget {
  const HomePharmacienScreen({super.key});

  @override
  State<HomePharmacienScreen> createState() => _HomePharmacienScreenState();
}

class _HomePharmacienScreenState extends State<HomePharmacienScreen> {
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
      final auth = context.read<AuthProvider>();
      auth.fetchUnreadNotifications();
      auth.fetchCurrentUserProfile();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

  void _showPhotoOptionsModal() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Photo de profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Prenez une photo ou choisissez-en une dans votre galerie',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoActionBtn(
                    icon: LucideIcons.camera,
                    label: 'Appareil photo',
                    color: AppColors.primaryGreen,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadImage(ImageSource.camera);
                    },
                  ),
                  _buildPhotoActionBtn(
                    icon: LucideIcons.image,
                    label: 'Galerie',
                    color: const Color(0xFF2F8F4F),
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickAndUploadImage(ImageSource.gallery);
                    },
                  ),
                  if (user.photo != null && user.photo!.isNotEmpty)
                    _buildPhotoActionBtn(
                      icon: LucideIcons.trash2,
                      label: 'Supprimer',
                      color: AppColors.error,
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteProfilePhoto();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final bytes = await pickedFile.readAsBytes();
      final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (user == null) return;

      final success = await auth.updateProfile(
        nom: user.nom ?? '',
        login: user.login ?? '',
        tel: user.tel,
        photoProfil: base64String,
      );

      if (!mounted) return;
      if (success) {
        AppToast.showSuccess('Photo de profil mise à jour avec succès !');
      } else {
        AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour');
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError('Erreur: $e', context);
      }
    }
  }

  Future<void> _deleteProfilePhoto() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    final success = await auth.updateProfile(
      nom: user.nom ?? '',
      login: user.login ?? '',
      tel: user.tel,
      photoProfil: '',
    );

    if (!mounted) return;
    if (success) {
      AppToast.showSuccess('Photo de profil supprimée avec succès.', context);
    }
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
    final displayName = user?.displayName ?? 'Espace Pharmacien';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F2),
      body: Stack(
        children: [
          // ─── AMBIENT BACKGROUND GLOWING ORBS ───
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
            top: 240,
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // User info with glowing avatar
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                          borderRadius: BorderRadius.circular(30),
                          child: Row(
                            children: [
                              RotatingGlowingAvatar(
                                user: user,
                                size: 52,
                                showCameraBadge: true,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                                onCameraTap: _showPhotoOptionsModal,
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '${_getGreeting()} 👋',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primaryGreenDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.forestGreen,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 350.ms).slideX(begin: -0.1),

                        // Header Actions (Quick Scan & Notifications)
                        Row(
                          children: [
                            _buildHeaderActionButton(
                              icon: LucideIcons.scanLine,
                              label: 'Scan',
                              onTap: () => Navigator.pushNamed(context, AppRoutes.qrScanner),
                            ),
                            const SizedBox(width: 8),
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

                  // ─── HERO FEATURE CARD: PHARMACIES & CALENDRIER ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    child: _buildHeroPharmaciesCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.gardesMap),
                    ).animate().fadeIn(delay: 150.ms, duration: 400.ms).scale(begin: const Offset(0.97, 0.97)),
                  ),
                  const SizedBox(height: 18),

                  // ─── SECTION TITLE: SERVICES PROFESSIONNELS ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Services & Officine',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'CNOPT Pro',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 180.ms, duration: 300.ms),
                  const SizedBox(height: 12),

                  // ─── 6 MODERN CARDS WITH GLOSSY SQUIRCLES ───
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
                          icon: LucideIcons.calendarSearch,
                          label: 'Calendrier de gardes',
                          delayMs: 200,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.calendarGardes),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.messageCircle,
                          label: 'Notifications messagerie',
                          badgeCount: auth.unreadNotifications,
                          delayMs: 250,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.messagerie),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.search,
                          label: 'Recherche de médicaments',
                          delayMs: 300,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.medicaments),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.check,
                          label: 'Observance',
                          delayMs: 350,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.observance),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.clipboardList,
                          label: 'Procédure CNOPT',
                          delayMs: 400,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.procedures),
                        ),
                        _buildMenuCard(
                          icon: LucideIcons.calendar,
                          label: 'Demande congés',
                          delayMs: 450,
                          onTap: () => Navigator.pushNamed(context, AppRoutes.conges),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ─── QUICK BANNER: IBN JEZZAR AI ASSISTANT ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildAIBannerCard(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.chatbot),
                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                  ),
                  const SizedBox(height: 14),

                  // ─── DAILY HEALTH TIP / NOTE PROFESSIONNELLE ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildProHealthTipCard().animate().fadeIn(delay: 550.ms, duration: 400.ms),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Pharmacies & Gardes',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
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
                          'Trouver la pharmacie ouverte & tour de garde',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.78),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    String? sublabel,
    bool useAssetImage = false,
    int? badgeCount,
    required int delayMs,
    required VoidCallback onTap,
  }) {
    return _InteractivePressCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
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
        child: Stack(
          children: [
            Align(
              alignment: Alignment.center,
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
                              // Gloss specular shine
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
                              // Content: Asset or Icon with micro-shadow
                              useAssetImage
                                  ? Padding(
                                      padding: const EdgeInsets.all(9),
                                      child: Image.asset(
                                        'assets/images/icone-40.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (ctx, err, stack) => const Icon(LucideIcons.mapPin, color: Colors.white, size: 26),
                                      ),
                                    )
                                  : Icon(
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
                  const SizedBox(height: 10),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      height: 1.2,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Red unread notification count badge
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    badgeCount > 99 ? '99+' : badgeCount.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delayMs), duration: 350.ms).slideY(begin: 0.08);
  }

  Widget _buildAIBannerCard({required VoidCallback onTap}) {
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
              child: const Icon(LucideIcons.bot, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 13),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ibn Jezzar — Assistant IA',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.forestGreen,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Posez vos questions sur la législation & pratiques',
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

  Widget _buildProHealthTipCard() {
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
                  'Conseil & Vigilance Officinale',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forestGreen,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Vérifiez la conformité des ordonnances et signalez tout événement indésirable sur le portail CNOPT.',
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
