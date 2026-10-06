import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/rotating_glowing_avatar.dart';
import '../../../shared/widgets/wave_clipper.dart';

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
    if (hour >= 5 && hour < 12) return 'Bonjour 👋';
    if (hour >= 12 && hour < 18) return 'Bon après-midi 👋';
    return 'Bonne soirée 🌙';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = user?.displayName ?? 'Espace Pharmacien';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // ─── HERO HEADER (Identique React HomePharmacien.jsx & HomePatient) ───
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage('assets/images/back-mobile.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.18,
                  scale: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xD9FFFFFF),
                            Color(0xC4F0F8EB),
                            Color(0x2871A246),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),

                  // Decorative circle
                  Positioned(
                    bottom: -40,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      ),
                    ),
                  ),

                  SizedBox(
                    width: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.only(top: topPadding + 20, bottom: 28, left: 20, right: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Rotating Glowing Avatar with Pharmacist initials / photo & camera badge
                          RotatingGlowingAvatar(
                            user: user,
                            size: 80,
                            showCameraBadge: true,
                            onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                            onCameraTap: _showPhotoOptionsModal,
                          ),
                          const SizedBox(height: 14),

                          // Time-aware greeting context pill (Identique React)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
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
                                color: Color(0xFF4B6A3A),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Pharmacist Name
                          Text(
                            displayName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forestGreen,
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Wave Divider
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 24),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── PHARMACIEN MENU GRID (8 Items Identiques React) ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    delayMs: 180,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.calendarGardes),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.mapPin,
                    label: 'Recherche pharmacies',
                    useAssetImage: true,
                    delayMs: 220,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.gardesMap),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.messageCircle,
                    label: 'Notifications messagerie',
                    badgeCount: auth.unreadNotifications,
                    delayMs: 260,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.messagerie),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.search,
                    label: 'Recherche de médicaments',
                    delayMs: 300,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.medicaments),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.bot,
                    label: 'Ibn Jezzar',
                    sublabel: "Le chatbot de l'Ordre",
                    delayMs: 340,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.chatbot),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.check,
                    label: 'Observance',
                    delayMs: 380,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.observance),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.clipboardList,
                    label: 'Procédure CNOPT',
                    delayMs: 420,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.procedures),
                  ),
                  _buildMenuCard(
                    icon: LucideIcons.calendar,
                    label: 'Demande congés',
                    delayMs: 460,
                    onTap: () => Navigator.pushNamed(context, AppRoutes.conges),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTabIndex,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
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
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF244082).withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Center icon & label
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryGreen, Color(0xFF5D8A38)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(17),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryGreen.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: useAssetImage
                        ? Padding(
                            padding: const EdgeInsets.all(8),
                            child: Image.asset(
                              'assets/images/icone-40.png',
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, err, stack) => const Icon(LucideIcons.mapPin, color: Colors.white, size: 26),
                            ),
                          )
                        : Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 10),
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
                  if (sublabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sublabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Red unread notification count badge (matches React hp-badge)
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
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeInOutCubic,
        child: widget.child,
      ),
    );
  }
}
