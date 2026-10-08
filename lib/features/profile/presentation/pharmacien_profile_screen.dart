import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
                            trailing: (user?.lat != null && user?.lng != null)
                                ? InkWell(
                                    onTap: () => _openGoogleMaps(user!.lat!, user.lng!),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : null,
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

// ─── PHARMACIEN EDIT MODAL ───

class _PharmacienEditModal extends StatefulWidget {
  final UserModel user;
  final VoidCallback onSaved;

  const _PharmacienEditModal({required this.user, required this.onSaved});

  @override
  State<_PharmacienEditModal> createState() => _PharmacienEditModalState();
}

class _PharmacienEditModalState extends State<_PharmacienEditModal> {
  late TextEditingController _nomController;
  late TextEditingController _nomArController;
  late TextEditingController _telController;
  late TextEditingController _tel2Controller;
  late TextEditingController _adresseController;
  late TextEditingController _loginController;
  late TextEditingController _passwordController;

  bool _isSaving = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.user.nom ?? '');
    _nomArController = TextEditingController(text: widget.user.nomAr ?? '');
    _telController = TextEditingController(text: widget.user.tel ?? '');
    _tel2Controller = TextEditingController(text: widget.user.tel2 ?? '');
    _adresseController = TextEditingController(text: widget.user.adresse ?? '');
    _loginController = TextEditingController(text: widget.user.login ?? '');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomArController.dispose();
    _telController.dispose();
    _tel2Controller.dispose();
    _adresseController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String pwd) {
    if (pwd.isEmpty) return true;
    return pwd.length >= 12 &&
        RegExp(r'[A-Z]').hasMatch(pwd) &&
        RegExp(r'[a-z]').hasMatch(pwd) &&
        RegExp(r'[0-9]').hasMatch(pwd) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(pwd);
  }

  Future<void> _handleSave() async {
    final nom = _nomController.text.trim();
    final login = _loginController.text.trim();
    final pwd = _passwordController.text.trim();

    if (nom.isEmpty || login.isEmpty) {
      AppToast.showError('Le nom et l\'identifiant sont obligatoires.');
      return;
    }

    if (pwd.isNotEmpty && !_isStrongPassword(pwd)) {
      AppToast.showError('Le mot de passe doit respecter les 5 critères de sécurité.');
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    final success = await auth.updatePharmacienDetails(
      nom: nom,
      nomAr: _nomArController.text.trim(),
      tel: _telController.text.trim(),
      tel2: _tel2Controller.text.trim(),
      adresse: _adresseController.text.trim(),
      login: login,
      password: pwd.isNotEmpty ? pwd : null,
    );

    setState(() => _isSaving = false);

    if (success) {
      AppToast.showSuccess('Profil pharmacien modifié avec succès');
      widget.onSaved();
    } else {
      AppToast.showError(auth.errorMessage ?? 'Erreur lors de la modification');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
              const Text(
                'Modifier mon profil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.forestGreen,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textSecondary),
              ),
            ],
          ),
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
                  _buildField('TÉLÉPHONE PHARMACIE', 'Téléphone pharmacie', _telController, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField('TÉLÉPHONE PERSONNEL', 'Téléphone personnel', _tel2Controller, keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _buildField('ADRESSE', 'Adresse complète', _adresseController),
                  const SizedBox(height: 12),
                  _buildField('IDENTIFIANT (LOGIN) *', 'Identifiant / Login', _loginController),
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
                          : const Icon(LucideIcons.save, size: 18),
                      label: Text(
                        _isSaving ? 'Enregistrement…' : 'Enregistrer les modifications',
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
