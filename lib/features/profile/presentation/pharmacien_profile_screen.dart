import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';
import 'edit_profile_screen.dart';

class PharmacienProfileScreen extends StatefulWidget {
  const PharmacienProfileScreen({super.key});

  @override
  State<PharmacienProfileScreen> createState() => _PharmacienProfileScreenState();
}

class _PharmacienProfileScreenState extends State<PharmacienProfileScreen> {
  bool _isLoading = false;
  UserModel? _user;
  List<String> _facadeImages = [];
  List<String> _paraImages = [];
  List<String> _injectionImages = [];

  @override
  void initState() {
    super.initState();
    final cachedUser = context.read<AuthProvider>().currentUser;
    _user = cachedUser;
    _isLoading = cachedUser == null;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final auth = context.read<AuthProvider>();
    final targetId = _user?.id ?? auth.currentUser?.id;

    try {
      final futures = await Future.wait([
        auth.fetchCurrentUserProfile().timeout(
          const Duration(seconds: 4),
          onTimeout: () => _user ?? auth.currentUser,
        ),
        auth.fetchUserImages(targetId).timeout(
          const Duration(seconds: 4),
          onTimeout: () => <String, List<String>>{
            'facade': <String>[],
            'para': <String>[],
            'injection': <String>[],
          },
        ),
      ]);

      final freshUser = futures[0] as UserModel?;
      final images = futures[1] as Map<String, List<String>>;

      if (mounted) {
        setState(() {
          _user = freshUser ?? _user ?? auth.currentUser;
          _facadeImages = images['facade'] ?? _facadeImages;
          _paraImages = images['para'] ?? _paraImages;
          _injectionImages = images['injection'] ?? _injectionImages;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _user = _user ?? auth.currentUser;
          _isLoading = false;
        });
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == 2) return;
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.actualites);
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

  void _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openEditProfile() async {
    final auth = context.read<AuthProvider>();
    final userToEdit = _user ?? auth.currentUser;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(user: userToEdit),
      ),
    );
    if (result == true || mounted) {
      _fetchUserData();
    }
  }

  void _openImageEditor({
    required String title,
    required String type,
    required List<String> currentImages,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ImageEditorSheet(
        title: title,
        type: type,
        currentImages: currentImages,
        onSaved: _fetchUserData,
      ),
    );
  }

  void _openLocationEditor(UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationEditorSheet(
        user: user,
        onSaved: _fetchUserData,
      ),
    );
  }

  void _openInfoEditor(UserModel? user) {
    if (user == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MesInformationsEditSheet(
        user: user,
        onSaved: _fetchUserData,
      ),
    );
  }

  void _openServicesEditor(UserModel? user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ServicesEditSheet(
        user: user,
        onSaved: _fetchUserData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = _user ?? auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;

    final displayName = user?.nom?.trim().isNotEmpty == true ? user!.nom!.trim() : 'Utilisateur';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: (_isLoading && user == null)
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : RefreshIndicator(
              color: AppColors.primaryGreen,
              onRefresh: _fetchUserData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  children: [
                    // ─── HERO HEADER (Identique React UserDetails.jsx) ───
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
                          // Gradient Overlay
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
                            bottom: -50,
                            right: -50,
                            child: Container(
                              width: 250,
                              height: 250,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                              ),
                            ),
                          ),

                          // Pinned "Retour" Button (Top Left)
                          Positioned(
                            top: topPadding + 12,
                            left: 14,
                            child: InkWell(
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
                                }
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.undo2, size: 14, color: AppColors.primaryGreen),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retour',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Pinned "Modifier" Button (Top Right)
                          Positioned(
                            top: topPadding + 12,
                            right: 14,
                            child: InkWell(
                              onTap: _openEditProfile,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.pencil, size: 14, color: AppColors.primaryGreen),
                                    SizedBox(width: 6),
                                    Text(
                                      'Modifier',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Centered Hero Content
                          Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: double.infinity,
                              child: Padding(
                                padding: EdgeInsets.only(top: topPadding + 54, bottom: 28, left: 20, right: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Store Icon Bubble
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen,
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primaryGreen.withValues(alpha: 0.4),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(LucideIcons.store, color: Colors.white, size: 32),
                                    )
                                        .animate()
                                        .fadeIn(duration: 400.ms)
                                        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack),
                                    const SizedBox(height: 14),

                                    // Title: Détails de l'utilisateur
                                    const Text(
                                      'Détails de l\'utilisateur',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF163820),
                                        letterSpacing: -0.3,
                                      ),
                                    )
                                        .animate()
                                        .fadeIn(duration: 400.ms, delay: 100.ms)
                                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                                    const SizedBox(height: 4),

                                    // Subtitle: Consultez les informations de {nom}
                                    Text(
                                      'Consultez les informations de $displayName',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF4B6A3A),
                                      ),
                                    )
                                        .animate()
                                        .fadeIn(duration: 400.ms, delay: 150.ms)
                                        .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Wave Transition
                    CustomPaint(
                      size: const Size(double.infinity, 24),
                      painter: WavePainter(),
                    ),

                    // ─── BODY SECTIONS (Identique React UserDetails.jsx) ───
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        children: [
                          // 1. SECTION: IMAGE DE LA FAÇADE
                          _buildSectionCard(
                            title: 'IMAGE DE LA FAÇADE',
                            icon: LucideIcons.image,
                            zeroPadding: _facadeImages.isNotEmpty,
                            trailing: _buildEditButton(
                              label: _facadeImages.isNotEmpty ? 'Modifier' : 'Ajouter',
                              onTap: () => _openImageEditor(
                                title: 'Image de la façade',
                                type: 'Image de la façade',
                                currentImages: _facadeImages,
                              ),
                            ),
                            child: _facadeImages.isNotEmpty
                                ? _buildImagesCarousel(_facadeImages)
                                : _buildEmptyState(
                                    icon: LucideIcons.store,
                                    message: 'Aucune image disponible.',
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // 2. SECTION: LOCALISATION
                          _buildSectionCard(
                            title: 'LOCALISATION',
                            icon: LucideIcons.mapPin,
                            zeroPadding: (user?.lat != null && user?.lng != null),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (user?.lat != null && user?.lng != null) ...[
                                  _buildGoogleMapsChip(user!.lat!, user.lng!),
                                  const SizedBox(width: 8),
                                ],
                                _buildEditButton(
                                  label: (user?.lat != null && user?.lng != null) ? 'Modifier' : 'Ajouter',
                                  onTap: () => _openLocationEditor(user),
                                ),
                              ],
                            ),
                            child: (user?.lat != null && user?.lng != null)
                                ? _buildMapWidget(user!.lat!, user.lng!, user.nom ?? 'Pharmacie')
                                : _buildEmptyState(
                                    icon: LucideIcons.mapPin,
                                    message: 'Aucune coordonnée géographique n\'est disponible.',
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // 3. SECTION: MES INFORMATIONS
                          _buildSectionCard(
                            title: 'MES INFORMATIONS',
                            icon: LucideIcons.user,
                            trailing: _buildEditButton(
                              label: 'Modifier',
                              onTap: () => _openInfoEditor(user),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('NOM COMPLET', user?.nom?.toUpperCase() ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('NOM COMPLET (AR)', user?.nomAr?.toUpperCase() ?? '-')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('NUM CNOPT', user?.numCnopt ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('IDENTIFIANT', user?.login ?? user?.identifiant ?? '-')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('ADRESSE EMAIL', user?.email ?? user?.login ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('ADRESSE', user?.adresse ?? '-')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('ADRESSE (AR)', user?.adresseAr ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('GOUVERNORAT', user?.gouvernoratNom ?? '-')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('DÉLÉGATION', user?.delegation ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('TABLEAU DE GARDE', user?.zoneGardeNom ?? '-')),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: _buildInfoItem('TÉLÉPHONE PHARMACIE', user?.tel ?? '-')),
                                    const SizedBox(width: 10),
                                    Expanded(child: _buildInfoItem('TÉLÉPHONE PERSONNEL', user?.tel2 ?? '-')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // 4. SECTION: IMAGE SALLE D'INJECTION
                          _buildSectionCard(
                            title: 'IMAGE SALLE D\'INJECTION',
                            icon: LucideIcons.syringe,
                            zeroPadding: _injectionImages.isNotEmpty,
                            trailing: _buildEditButton(
                              label: _injectionImages.isNotEmpty ? 'Modifier' : 'Ajouter',
                              onTap: () => _openImageEditor(
                                title: 'Salle d\'injection',
                                type: 'Salle d’injection',
                                currentImages: _injectionImages,
                              ),
                            ),
                            child: _injectionImages.isNotEmpty
                                ? _buildImagesCarousel(_injectionImages)
                                : _buildEmptyState(
                                    icon: LucideIcons.syringe,
                                    message: 'Aucune image salle d\'injection disponible.',
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // 5. SECTION: IMAGE COIN PARA
                          _buildSectionCard(
                            title: 'IMAGE COIN PARA',
                            icon: LucideIcons.pill,
                            zeroPadding: _paraImages.isNotEmpty,
                            trailing: _buildEditButton(
                              label: _paraImages.isNotEmpty ? 'Modifier' : 'Ajouter',
                              onTap: () => _openImageEditor(
                                title: 'Coin Parapharmacie',
                                type: 'Coin para',
                                currentImages: _paraImages,
                              ),
                            ),
                            child: _paraImages.isNotEmpty
                                ? _buildImagesCarousel(_paraImages)
                                : _buildEmptyState(
                                    icon: LucideIcons.pill,
                                    message: 'Aucune image coin para disponible.',
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // 6. SECTION: SERVICES DISPONIBLES
                          _buildSectionCard(
                            title: 'SERVICES DISPONIBLES',
                            icon: LucideIcons.settings,
                            trailing: _buildEditButton(
                              label: 'Modifier',
                              onTap: () => _openServicesEditor(user),
                            ),
                            child: (user?.services != null && user!.services.isNotEmpty)
                                ? Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: user.services.map((s) {
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0EFD6),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          s.nom,
                                          style: const TextStyle(
                                            color: Color(0xFF3A5A22),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  )
                                : _buildEmptyState(
                                    icon: LucideIcons.settings,
                                    message: 'Aucun service disponible pour cet utilisateur.',
                                  ),
                          ),
                          const SizedBox(height: 18),

                          // 7. SECTION: NOTIFICATIONS & TEST
                          _buildSectionCard(
                            title: 'NOTIFICATIONS MOBILES',
                            icon: LucideIcons.bell,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Vérifiez la réception des alertes système (actualités, messages, dispensations) sur votre téléphone.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await NotificationService.showTestNotification();
                                      AppToast.showSuccess('Notification de test envoyée !');
                                    },
                                    icon: const Icon(LucideIcons.bellRing, size: 16, color: Color(0xFF71A246)),
                                    label: const Text(
                                      'Tester la notification système',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF163820)),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF71A246), width: 1.5),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  // ─── HELPER WIDGETS ───

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
    bool zeroPadding = false,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF244082).withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF71A246), Color(0xFF5D8A38)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF163820),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Body
          if (zeroPadding)
            child
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
        ],
      ),
    );
  }

  Widget _buildEditButton({required VoidCallback onTap, String label = 'Modifier'}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.pencil, size: 12, color: AppColors.primaryGreen),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleMapsChip(double lat, double lng) {
    return InkWell(
      onTap: () => _openGoogleMaps(lat, lng),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.externalLink, size: 12, color: AppColors.primaryGreen),
            SizedBox(width: 4),
            Text(
              'Google Maps',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9CA3AF),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesCarousel(List<String> images) {
    return _CarouselViewer(images: images);
  }

  Widget _buildMapWidget(double lat, double lng, String name) {
    final latLng = LatLng(lat, lng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 200,
        width: double.infinity,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: latLng, zoom: 15),
          markers: {
            Marker(
              markerId: const MarkerId('pharmacie_loc'),
              position: latLng,
              infoWindow: InfoWindow(title: name),
            ),
          },
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CAROUSEL VIEWER (Identique React .ud-carousel-wrap) ───

class _CarouselViewer extends StatefulWidget {
  final List<String> images;
  const _CarouselViewer({required this.images});

  @override
  State<_CarouselViewer> createState() => _CarouselViewerState();
}

class _CarouselViewerState extends State<_CarouselViewer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = widget.images.length > 1;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8F9FA),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (idx) => setState(() => _currentPage = idx),
                  itemBuilder: (ctx, i) {
                    final filename = widget.images[i];
                    final url = filename.startsWith('http')
                        ? filename
                        : '${AppConstants.backBaseUrl}uploads/$filename';

                    return Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.contain,
                          height: 240,
                          placeholder: (ctx, url) => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                          ),
                          errorWidget: (ctx, url, err) => Container(
                            height: 180,
                            width: 180,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Bouton Précédent
                if (hasMultiple && _currentPage > 0)
                  Positioned(
                    left: 6,
                    child: InkWell(
                      onTap: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.chevronLeft, color: Colors.white, size: 20),
                      ),
                    ),
                  ),

                // Bouton Suivant
                if (hasMultiple && _currentPage < widget.images.length - 1)
                  Positioned(
                    right: 6,
                    child: InkWell(
                      onTap: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.chevronRight, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Indicateurs de pagination (Dots)
          if (hasMultiple) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.images.length, (index) {
                final isSelected = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isSelected ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryGreen : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 1. IMAGE EDITOR MODAL SHEET ───

class _ImageEditorSheet extends StatefulWidget {
  final String title;
  final String type;
  final List<String> currentImages;
  final VoidCallback onSaved;

  const _ImageEditorSheet({
    required this.title,
    required this.type,
    required this.currentImages,
    required this.onSaved,
  });

  @override
  State<_ImageEditorSheet> createState() => _ImageEditorSheetState();
}

class _ImageEditorSheetState extends State<_ImageEditorSheet> {
  File? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _selectedFile = File(picked.path));
      }
    } catch (_) {
      AppToast.showError("Impossible d'accéder à la source d'image.");
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFile == null) return;
    setState(() => _isUploading = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.uploadUserImage(
      filePath: _selectedFile!.path,
      type: widget.type,
    );

    if (mounted) setState(() => _isUploading = false);

    if (success) {
      AppToast.showSuccess('Image mise à jour avec succès !');
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } else {
      AppToast.showError(auth.errorMessage ?? 'Échec du téléversement de l\'image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.image, color: AppColors.primaryGreen, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163820),
                      ),
                    ),
                    const Text(
                      'Modifier ou ajouter une photo',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Current images (if any)
          if (widget.currentImages.isNotEmpty) ...[
            const Text(
              'IMAGE(S) ACTUELLE(S)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.currentImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) {
                  final fn = widget.currentImages[i];
                  final url = fn.startsWith('http') ? fn : '${AppConstants.backBaseUrl}uploads/$fn';
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: url,
                      width: 120,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 120,
                        height: 100,
                        color: Colors.grey.shade100,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 120,
                        height: 100,
                        color: Colors.grey.shade200,
                        child: const Icon(LucideIcons.imageOff, color: Colors.grey),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Selected preview or pick buttons
          if (_selectedFile != null) ...[
            const Text(
              'NOUVELLE IMAGE SÉLECTIONNÉE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    _selectedFile!,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => setState(() => _selectedFile = null),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.x, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _handleUpload,
                icon: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.uploadCloud, size: 18),
                label: Text(
                  _isUploading ? 'Téléversement en cours…' : 'Enregistrer cette image',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'CHOISIR UNE NOUVELLE IMAGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.camera),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.camera, size: 28, color: AppColors.primaryGreen),
                          SizedBox(height: 8),
                          Text(
                            'Appareil photo',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF163820)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickImage(ImageSource.gallery),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.images, size: 28, color: AppColors.primaryGreen),
                          SizedBox(height: 8),
                          Text(
                            'Galerie photos',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF163820)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── 2. LOCATION EDITOR MODAL SHEET ───

class _LocationEditorSheet extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onSaved;

  const _LocationEditorSheet({required this.user, required this.onSaved});

  @override
  State<_LocationEditorSheet> createState() => _LocationEditorSheetState();
}

class _LocationEditorSheetState extends State<_LocationEditorSheet> {
  late LatLng _currentPos;
  GoogleMapController? _mapController;
  bool _isLocating = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final lat = widget.user?.lat;
    final lng = widget.user?.lng;
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      _currentPos = LatLng(lat, lng);
    } else {
      _currentPos = const LatLng(34.7406, 10.7603); // Sfax par défaut
    }
  }

  Future<void> _locateCurrentPosition() async {
    setState(() => _isLocating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        AppToast.showError('Permission de localisation requise.');
        setState(() => _isLocating = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final newLatLng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPos = newLatLng;
        _isLocating = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 16));
    } catch (_) {
      setState(() => _isLocating = false);
      AppToast.showError('Impossible d\'obtenir la position GPS actuelle.');
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.updatePharmacienDetails(
      nom: widget.user?.nom ?? '',
      lat: _currentPos.latitude,
      lng: _currentPos.longitude,
    );

    if (mounted) setState(() => _isSaving = false);

    if (success) {
      AppToast.showSuccess('Coordonnées GPS mises à jour avec succès !');
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } else {
      AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour des coordonnées.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.mapPin, color: AppColors.primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modifier la localisation',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163820),
                        ),
                      ),
                      Text(
                        'Ajustez l\'emplacement de votre officine',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Sub-bar with GPS button & coordinates
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Lat: ${_currentPos.latitude.toStringAsFixed(5)}, Lng: ${_currentPos.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isLocating ? null : _locateCurrentPosition,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _isLocating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryGreen))
                            : const Icon(LucideIcons.locateFixed, size: 14, color: AppColors.primaryGreen),
                        const SizedBox(width: 5),
                        const Text(
                          'Ma position',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryGreen),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Google Map Interactive View
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _currentPos, zoom: 15),
                  onMapCreated: (ctrl) => _mapController = ctrl,
                  onTap: (latLng) {
                    setState(() => _currentPos = latLng);
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('edit_pharmacie_loc'),
                      position: _currentPos,
                      draggable: true,
                      onDragEnd: (newPos) {
                        setState(() => _currentPos = newPos);
                      },
                    ),
                  },
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: true,
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Touchez la carte ou faites glisser le marqueur pour définir l\'emplacement exact.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Save Button Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  _isSaving ? 'Enregistrement…' : 'Enregistrer cette position',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 3. MES INFORMATIONS EDITOR MODAL SHEET ───

class _MesInformationsEditSheet extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;

  const _MesInformationsEditSheet({required this.user, required this.onSaved});

  @override
  State<_MesInformationsEditSheet> createState() => _MesInformationsEditSheetState();
}

class _MesInformationsEditSheetState extends State<_MesInformationsEditSheet> {
  late TextEditingController _nomController;
  late TextEditingController _nomArController;
  late TextEditingController _numCnoptController;
  late TextEditingController _loginController;
  late TextEditingController _telController;
  late TextEditingController _tel2Controller;
  late TextEditingController _adresseController;
  late TextEditingController _adresseArController;
  late TextEditingController _passwordController;

  int? _selectedGouvernoratId;
  String? _selectedGouvernoratNom;
  String? _selectedDelegation;
  int? _selectedZoneId;
  String? _selectedZoneNom;

  List<Map<String, dynamic>> _gouvernorats = [];
  List<Map<String, dynamic>> _delegations = [];
  List<Map<String, dynamic>> _zones = [];

  bool _isSaving = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _nomController = TextEditingController(text: u.nom ?? '');
    _nomArController = TextEditingController(text: u.nomAr ?? '');
    _numCnoptController = TextEditingController(text: u.numCnopt ?? '');
    _loginController = TextEditingController(text: u.login ?? '');
    _telController = TextEditingController(text: u.tel ?? '');
    _tel2Controller = TextEditingController(text: u.tel2 ?? '');
    _adresseController = TextEditingController(text: u.adresse ?? '');
    _adresseArController = TextEditingController(text: u.adresseAr ?? '');
    _passwordController = TextEditingController();

    _selectedGouvernoratId = u.idGouvernorat;
    _selectedGouvernoratNom = u.gouvernoratNom;
    _selectedDelegation = u.delegation;
    _selectedZoneId = u.idGarde;
    _selectedZoneNom = u.zoneGardeNom;

    _loadReferenceData();
  }

  Future<void> _loadReferenceData() async {
    final auth = context.read<AuthProvider>();
    try {
      final results = await Future.wait([
        auth.fetchGouvernorats(),
        auth.fetchDelegations(),
        auth.fetchActiveZones(),
      ]);
      if (mounted) {
        setState(() {
          _gouvernorats = results[0];
          _delegations = results[1];
          _zones = results[2];

          if (_selectedGouvernoratId != null && _selectedGouvernoratNom == null) {
            final found = _gouvernorats.firstWhere(
              (g) => g['id'] == _selectedGouvernoratId,
              orElse: () => {},
            );
            if (found.isNotEmpty) _selectedGouvernoratNom = found['nom']?.toString();
          }

          if (_selectedZoneId != null && _selectedZoneNom == null) {
            final found = _zones.firstWhere(
              (z) => z['id'] == _selectedZoneId,
              orElse: () => {},
            );
            if (found.isNotEmpty) _selectedZoneNom = found['designation']?.toString() ?? found['nom']?.toString();
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomArController.dispose();
    _numCnoptController.dispose();
    _loginController.dispose();
    _telController.dispose();
    _tel2Controller.dispose();
    _adresseController.dispose();
    _adresseArController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showSelectorModal({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelBuilder,
    required dynamic Function(Map<String, dynamic>) valueBuilder,
    required dynamic currentValue,
    required Function(dynamic value, String label) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF163820),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Aucun élément disponible', style: TextStyle(color: Color(0xFF9CA3AF))))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final item = items[i];
                          final label = labelBuilder(item);
                          final val = valueBuilder(item);
                          final isSelected = val == currentValue;
                          return InkWell(
                            onTap: () {
                              onSelected(val, label);
                              Navigator.pop(ctx);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEBF5E5) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: AppColors.primaryGreen) : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? AppColors.primaryGreen : const Color(0xFF374151),
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(LucideIcons.check, size: 18, color: AppColors.primaryGreen),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    final nom = _nomController.text.trim();
    final login = _loginController.text.trim();
    final pwd = _passwordController.text.trim();

    if (nom.isEmpty || login.isEmpty) {
      AppToast.showError('Le nom et l\'identifiant sont obligatoires.');
      return;
    }

    if (pwd.isNotEmpty && pwd.length < 6) {
      AppToast.showError('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.updatePharmacienDetails(
      nom: nom,
      nomAr: _nomArController.text.trim(),
      numCnopt: _numCnoptController.text.trim(),
      tel: _telController.text.trim(),
      tel2: _tel2Controller.text.trim(),
      adresse: _adresseController.text.trim(),
      adresseAr: _adresseArController.text.trim(),
      delegation: _selectedDelegation,
      idGouvernorat: _selectedGouvernoratId,
      idGarde: _selectedZoneId,
      login: login,
      password: pwd.isNotEmpty ? pwd : null,
    );

    if (mounted) setState(() => _isSaving = false);

    if (success) {
      AppToast.showSuccess('Informations mises à jour avec succès !');
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } else {
      AppToast.showError(auth.errorMessage ?? 'Erreur lors de la modification');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.user, color: AppColors.primaryGreen, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modifier mes informations',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163820),
                        ),
                      ),
                      Text(
                        'Coordonnées et identification',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildField('NOM COMPLET *', 'Nom de la pharmacie', _nomController),
                  const SizedBox(height: 12),
                  _buildField('NOM COMPLET (AR)', 'Nom en arabe', _nomArController),
                  const SizedBox(height: 12),
                  _buildField('NUM CNOPT', 'Numéro CNOPT', _numCnoptController),
                  const SizedBox(height: 12),
                  _buildField('IDENTIFIANT (LOGIN) *', 'Identifiant / Login', _loginController),
                  const SizedBox(height: 12),
                  _buildField('TÉLÉPHONE PHARMACIE', 'Téléphone pharmacie', _telController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField('TÉLÉPHONE PERSONNEL', 'Téléphone personnel', _tel2Controller, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField('ADRESSE', 'Adresse complète', _adresseController),
                  const SizedBox(height: 12),
                  _buildField('ADRESSE (AR)', 'Adresse en arabe', _adresseArController),
                  const SizedBox(height: 12),

                  // Gouvernorat Selector
                  _buildSelectorTile(
                    label: 'GOUVERNORAT',
                    value: _selectedGouvernoratNom,
                    placeholder: 'Sélectionnez un gouvernorat',
                    onTap: () {
                      _showSelectorModal(
                        title: 'Choisir le gouvernorat',
                        items: _gouvernorats,
                        labelBuilder: (g) => g['nom']?.toString() ?? '',
                        valueBuilder: (g) => g['id'],
                        currentValue: _selectedGouvernoratId,
                        onSelected: (val, label) {
                          setState(() {
                            _selectedGouvernoratId = val as int?;
                            _selectedGouvernoratNom = label;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Délégation Selector
                  _buildSelectorTile(
                    label: 'DÉLÉGATION',
                    value: _selectedDelegation,
                    placeholder: 'Sélectionnez une délégation',
                    onTap: () {
                      final filtered = _selectedGouvernoratId != null
                          ? _delegations.where((d) => d['id_gouvernorat'] == _selectedGouvernoratId).toList()
                          : _delegations;
                      _showSelectorModal(
                        title: 'Choisir la délégation',
                        items: filtered.isNotEmpty ? filtered : _delegations,
                        labelBuilder: (d) => d['nom']?.toString() ?? '',
                        valueBuilder: (d) => d['nom']?.toString(),
                        currentValue: _selectedDelegation,
                        onSelected: (val, label) {
                          setState(() {
                            _selectedDelegation = label;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // Tableau de garde Selector
                  _buildSelectorTile(
                    label: 'TABLEAU DE GARDE',
                    value: _selectedZoneNom,
                    placeholder: 'Sélectionnez un tableau de garde',
                    onTap: () {
                      _showSelectorModal(
                        title: 'Choisir le tableau de garde',
                        items: _zones,
                        labelBuilder: (z) => z['designation']?.toString() ?? z['nom']?.toString() ?? '',
                        valueBuilder: (z) => z['id'],
                        currentValue: _selectedZoneId,
                        onSelected: (val, label) {
                          setState(() {
                            _selectedZoneId = val as int?;
                            _selectedZoneNom = label;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  _buildPasswordField(),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSave,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(LucideIcons.check, size: 18),
                      label: Text(
                        _isSaving ? 'Enregistrement…' : 'Enregistrer les informations',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, String hint, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF163820)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectorTile({
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    (value != null && value.isNotEmpty) ? value : placeholder,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: (value != null && value.isNotEmpty) ? FontWeight.w600 : FontWeight.w400,
                      color: (value != null && value.isNotEmpty) ? const Color(0xFF163820) : const Color(0xFF9CA3AF),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOUVEAU MOT DE PASSE (LAISSER VIDE SI INCHANGÉ)',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF163820)),
                  decoration: const InputDecoration(
                    hintText: 'Nouveau mot de passe',
                    hintStyle: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(
                  _showPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  size: 18,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── 4. SERVICES DISPONIBLES EDITOR MODAL SHEET ───

class _ServicesEditSheet extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onSaved;

  const _ServicesEditSheet({required this.user, required this.onSaved});

  @override
  State<_ServicesEditSheet> createState() => _ServicesEditSheetState();
}

class _ServicesEditSheetState extends State<_ServicesEditSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _services = [];
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.user?.services != null) {
      for (final s in widget.user!.services) {
        _selectedIds.add(s.id);
      }
    }
    _loadServices();
  }

  Future<void> _loadServices() async {
    final auth = context.read<AuthProvider>();
    try {
      final list = await auth.fetchActiveServices();
      if (mounted) {
        setState(() {
          if (list.isNotEmpty) {
            _services = list;
          } else {
            _services = [
              {'id': 1, 'nom': "Salle d'injection"},
              {'id': 2, 'nom': "Coin para"},
              {'id': 3, 'nom': "Suivi pondéral"},
              {'id': 4, 'nom': "vétérinaire"},
            ];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _services = [
            {'id': 1, 'nom': "Salle d'injection"},
            {'id': 2, 'nom': "Coin para"},
            {'id': 3, 'nom': "Suivi pondéral"},
            {'id': 4, 'nom': "vétérinaire"},
          ];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.updatePharmacienDetails(
      nom: widget.user?.nom ?? '',
      serviceIds: _selectedIds.toList(),
    );

    if (mounted) setState(() => _isSaving = false);

    if (success) {
      AppToast.showSuccess('Services mis à jour avec succès !');
      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } else {
      AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour des services.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.only(top: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.settings, color: AppColors.primaryGreen, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Services disponibles',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF163820),
                        ),
                      ),
                      Text(
                        'Sélectionnez les services proposés par votre officine',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Services List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _services.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = _services[i];
                      final id = item['id'] is int ? item['id'] as int : int.tryParse(item['id'].toString()) ?? 0;
                      final name = item['nom']?.toString() ?? item['name']?.toString() ?? 'Service';
                      final isSelected = _selectedIds.contains(id);

                      return InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(id);
                            } else {
                              _selectedIds.add(id);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFEBF5E5) : const Color(0xFFFAFAFA),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primaryGreen : const Color(0xFFE5E7EB),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primaryGreen : Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryGreen : const Color(0xFFD1D5DB),
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(LucideIcons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? const Color(0xFF163820) : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Save Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _handleSave,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(LucideIcons.check, size: 18),
                label: Text(
                  _isSaving ? 'Enregistrement…' : 'Enregistrer les services',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
