import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/actualite_model.dart';
import '../../../core/providers/actualite_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';
import 'actualite_detail_screen.dart';

class ActualitesScreen extends StatefulWidget {
  const ActualitesScreen({super.key});

  @override
  State<ActualitesScreen> createState() => _ActualitesScreenState();
}

class _ActualitesScreenState extends State<ActualitesScreen> {
  final TextEditingController _searchController = TextEditingController();

  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      final isAdmin = user?.isAdmin == true || user?.idRole == 1;
      context.read<ActualiteProvider>().fetchActualites(forceRefresh: true, isAdmin: isAdmin);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    final user = context.read<AuthProvider>().currentUser;
    final isAdmin = user?.isAdmin == true || user?.idRole == 1;
    if (index == 0) {
      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
      } else if (user?.isPatient == true) {
        Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
      }
    } else if (index == 1) {
      // Already on Actualités
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
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

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Récemment';
    try {
      final date = DateTime.tryParse(dateStr);
      if (date == null) return dateStr;
      final diff = DateTime.now().difference(date);
      if (diff.inDays > 365) {
        final years = (diff.inDays / 365).floor();
        return 'il y a $years an${years > 1 ? 's' : ''}';
      } else if (diff.inDays > 30) {
        final months = (diff.inDays / 30).floor();
        return 'il y a $months mois';
      } else if (diff.inDays > 0) {
        return 'il y a ${diff.inDays} jour${diff.inDays > 1 ? 's' : ''}';
      } else if (diff.inHours > 0) {
        return 'il y a ${diff.inHours} h';
      } else if (diff.inMinutes > 0) {
        return 'il y a ${diff.inMinutes} min';
      } else {
        return "À l'instant";
      }
    } catch (_) {
      return dateStr;
    }
  }

  void _showActualiteDetails(ActualiteModel act, String themeName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActualiteDetailScreen(
          actualite: act,
          themeName: themeName,
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ActualiteProvider>();
    final auth = context.watch<AuthProvider>();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bgGrey,
      body: RefreshIndicator(
        color: _green,
        onRefresh: () {
          final isAdmin = auth.currentUser?.isAdmin == true || auth.currentUser?.idRole == 1;
          return provider.fetchActualites(forceRefresh: true, isAdmin: isAdmin);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── HERO HEADER (Identique React ListActualites.jsx) ───
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  image: DecorationImage(
                    image: AssetImage('assets/images/back-mobile.png'),
                    repeat: ImageRepeat.repeat,
                    opacity: 0.16,
                    scale: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
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
                    Padding(
                      padding: EdgeInsets.only(top: topPadding + 14, bottom: 26, left: 18, right: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Bar: Back Button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: InkWell(
                              onTap: () {
                                if (Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                } else {
                                  final user = auth.currentUser;
                                  if (user?.isAdmin == true || user?.idRole == 1) {
                                    Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
                                  } else if (user?.isPatient == true) {
                                    Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
                                  } else {
                                    Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
                                  }
                                }
                              },
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: const Color(0xFF70BA8E), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.undo2, size: 15, color: Color(0xFF22C55E)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retour',
                                      style: TextStyle(
                                        color: Color(0xFF22C55E),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Green Newspaper Icon Badge
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [_green, _greenDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withValues(alpha: 0.40),
                                  blurRadius: 18,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(LucideIcons.newspaper, color: Colors.white, size: 28),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Title
                          const Text(
                            'Actualités',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Restez informé des dernières nouvelles',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B6A3A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: CustomPaint(
                        size: const Size(double.infinity, 22),
                        painter: WavePainter(),
                      ),
                    ),
                  ],
                ),
              ),

              // ─── SEARCH INPUT (Overlapping Wave) ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF244082).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => provider.setSearchQuery(val),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Rechercher une actualité…',
                          hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF)),
                          prefixIcon: const Icon(LucideIcons.search, color: _green, size: 19),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF9CA3AF)),
                                  onPressed: () {
                                    _searchController.clear();
                                    provider.setSearchQuery('');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Horizontal Theme Filter Pills
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          // "Tous" Pill
                          _buildFilterPill(
                            label: 'Tous',
                            isSelected: provider.selectedThemeId == null,
                            onTap: () => provider.setSelectedTheme(null),
                          ),
                          const SizedBox(width: 8),

                          // Dynamic Theme Pills from Backend
                          ...provider.themes.map((theme) {
                            final isSelected = provider.selectedThemeId == theme.id;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterPill(
                                label: theme.nom.toUpperCase(),
                                isSelected: isSelected,
                                onTap: () => provider.setSelectedTheme(theme.id),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── ACTUALITÉS CONTENT LIST ───
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                child: _buildBodyContent(provider),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 1,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildBodyContent(ActualiteProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _green, strokeWidth: 3),
              SizedBox(height: 14),
              Text(
                'Chargement des actualités…',
                style: TextStyle(color: Color(0xFF6B7A99), fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.actualites.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9EDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(LucideIcons.searchX, size: 28, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 14),
              const Text(
                'Aucun résultat trouvé',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Essayez de modifier votre recherche',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: provider.actualites.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (ctx, index) {
        final act = provider.actualites[index];
        final themeName = provider.themes
            .firstWhere(
              (t) => t.id == act.idTheme,
              orElse: () => ThemeModel(id: 0, nom: act.themeNom ?? 'Général'),
            )
            .nom;
        return _buildActualiteCard(act, themeName, index);
      },
    );
  }

  // ─── FILTER PILL WIDGET ───
  Widget _buildFilterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [_green, _greenDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: isSelected ? null : Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _green.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }

  // ─── ACTUALITÉ CARD WIDGET (Exact React la-card) ───
  Widget _buildActualiteCard(ActualiteModel act, String themeName, int index) {
    final title = act.titre ?? '';
    final desc = act.description ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEF2F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showActualiteDetails(act, themeName),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Header (Height 175)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: Container(
                  height: 175,
                  width: double.infinity,
                  color: const Color(0xFFE9EDF4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Image / Placeholder
                      if (act.image != null && act.image!.trim().isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: '${AppConstants.backBaseUrl}uploads/${act.image}',
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _green),
                            ),
                          ),
                          errorWidget: (ctx, url, error) => _buildMediaPlaceholder(),
                        )
                      else
                        _buildMediaPlaceholder(),

                      // Theme Pill Badge over Image (Bottom-Left)
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            themeName.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _navy,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ),

                      // Top-Right Badges (Video badge & Inactif badge)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (act.video != null && act.video!.trim().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.70),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.play, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'Vidéo',
                                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            if (act.etat == 0)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'Inactif',
                                  style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Card Body
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Description
                    if (desc.isNotEmpty)
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 12),

                    // Divider
                    Container(height: 1, color: const Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),

                    // Footer
                    Row(
                      children: [
                        const Icon(LucideIcons.clock, size: 13, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 5),
                        Text(
                          _formatTimeAgo(act.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Lire la suite',
                          style: TextStyle(
                            color: _navy,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(LucideIcons.chevronRight, size: 14, color: _navy),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: index * 60)).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMediaPlaceholder() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.newspaper, size: 32, color: Color(0xFFC4CDD8)),
          SizedBox(height: 6),
          Text(
            'Pas de média',
            style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
