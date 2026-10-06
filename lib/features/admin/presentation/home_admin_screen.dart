import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/rotating_glowing_avatar.dart';
import 'widgets/admin_drawer.dart';

class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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
      final admin = context.read<AdminProvider>();
      admin.fetchUsers();
      admin.fetchAnnees();
    });
  }

  void _showYearSelectorModal(BuildContext context) {
    final admin = context.read<AdminProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final currentSelected = admin.selectedYear;
        final list = admin.annees;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(LucideIcons.calendar, color: AppColors.primaryGreen, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Sélectionner l\'année active',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Aucune année configurée', style: TextStyle(color: AppColors.textMuted))),
                )
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: list.map((item) {
                    final yearStr = item['annee']?.toString() ?? '';
                    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                    final isCurrent = yearStr == currentSelected;

                    return InkWell(
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (id > 0) {
                          await admin.selectActiveYear(id, yearStr);
                          if (!mounted) return;
                          AppToast.showSuccess('Année active modifiée : $yearStr');
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primaryGreen : AppColors.scaffoldBackground,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isCurrent ? AppColors.primaryGreen : AppColors.borderGray,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCurrent ? LucideIcons.checkCircle2 : LucideIcons.calendar,
                              size: 16,
                              color: isCurrent ? Colors.white : AppColors.forestGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              yearStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isCurrent ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(context, AppRoutes.adminAnnees);
                  },
                  icon: const Icon(LucideIcons.settings, size: 16, color: AppColors.forestGreen),
                  label: const Text('Gérer toutes les années', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forestGreen)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryGreen),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentTabIndex = index);
    if (index == 0) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    } else if (index == 1) {
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    final displayName = user?.nom?.trim().isNotEmpty == true
        ? user!.nom!.trim()
        : (user?.displayName ?? 'Administrateur');

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AdminDrawer(),
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              children: [
                // ─── TOP HERO BANNER (Green Organic Curve + Waves) ───
                Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFFF1F8EC),
                        Color(0xFFE2F0D9),
                        Color(0xFFD4E8C7),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Organic background glow circles
                      Positioned(
                        top: -40,
                        right: -30,
                        child: Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryGreen.withValues(alpha: 0.15),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 60,
                        left: -50,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primaryGreen.withValues(alpha: 0.10),
                          ),
                        ),
                      ),

                      // Hero content
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: EdgeInsets.only(top: topPadding + 64, bottom: 28, left: 20, right: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Rotating Glowing Avatar
                              RotatingGlowingAvatar(
                                user: user,
                                size: 80,
                                showCameraBadge: false,
                                onTap: () => Navigator.pushNamed(context, AppRoutes.profile),
                              ),
                          const SizedBox(height: 12),

                          // Role Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Espace Administration CNOPT',
                              style: TextStyle(
                                color: Color(0xFFC62828),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Admin Name
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
                          const SizedBox(height: 10),

                          // Active Year Quick Selector Pill (Identique React navbar)
                          Consumer<AdminProvider>(
                            builder: (context, adminProv, _) {
                              final year = adminProv.selectedYear.isNotEmpty
                                  ? adminProv.selectedYear
                                  : DateTime.now().year.toString();

                              return InkWell(
                                onTap: () => _showYearSelectorModal(context),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.95),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.4)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.calendar, size: 14, color: AppColors.forestGreen),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Année : $year',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.forestGreen,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.forestGreen),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── ADMIN PARAMÈTRES & GESTION GRID ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section title: Administration
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Gestion & Paramètres',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),

                  // Grid of Admin Cards
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      _buildAdminCard(
                        icon: LucideIcons.calendar,
                        label: 'Années',
                        sublabel: 'Gestion & sélection',
                        color: const Color(0xFF1B5E20),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminAnnees),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.users,
                        label: 'Utilisateurs',
                        sublabel: 'Comptes & rôles',
                        color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminUsers),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.menu,
                        label: 'Services',
                        sublabel: 'Services officines',
                        color: const Color(0xFF1976D2),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminServices),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.cog,
                        label: 'Procédures',
                        sublabel: 'Documents CNOPT',
                        color: const Color(0xFF00796B),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.procedures),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.calendarDays,
                        label: 'TB Gardes',
                        sublabel: 'Tableau de gardes',
                        color: const Color(0xFFE65100),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminTbGardes),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.shieldAlert,
                        label: 'Pharmacies de Garde',
                        sublabel: 'Liste des gardes',
                        color: const Color(0xFF2E7D32),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminGardes),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.calendarCheck,
                        label: 'Jours Fériés',
                        sublabel: 'Calendrier officiel',
                        color: const Color(0xFFD84315),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminJours),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.tags,
                        label: 'Catégories',
                        sublabel: 'Spécialités & types',
                        color: const Color(0xFF5E35B1),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminCategories),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.newspaper,
                        label: 'Actualités',
                        sublabel: 'Communiqués & flux',
                        color: const Color(0xFF0288D1),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminActualites),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.palette,
                        label: 'Thèmes',
                        sublabel: 'Thématiques de santé',
                        color: const Color(0xFF00897B),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminThemes),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.megaphone,
                        label: 'Annonces',
                        sublabel: 'Annonces & alertes',
                        color: const Color(0xFF8E24AA),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.adminAnnonces),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.mapPin,
                        label: 'Carte Officines',
                        sublabel: 'Recherche jour/nuit',
                        color: const Color(0xFF388E3C),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.gardesMap),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.messageCircle,
                        label: 'Messagerie',
                        sublabel: 'Discussions & alertes',
                        badgeCount: auth.unreadNotifications,
                        color: const Color(0xFF1565C0),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.messagerie),
                      ),
                      _buildAdminCard(
                        icon: LucideIcons.bot,
                        label: 'Ibn Jezzar',
                        sublabel: "Assistant de l'Ordre",
                        color: const Color(0xFF455A64),
                        onTap: () => Navigator.pushNamed(context, AppRoutes.chatbot),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),

      // ─── PINNED STICKY TOP NAVBAR (Menu Icon always visible on scroll) ───
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.only(
            top: topPadding + 8,
            bottom: 10,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: 0.96),
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0.0),
              ],
              stops: const [0.0, 0.7, 1.0],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Drawer Hamburger Button (Always visible on scroll)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 3,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                child: InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primaryGreen.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.menu,
                      color: AppColors.forestGreen,
                      size: 22,
                    ),
                  ),
                ),
              ),

              // Title Branding Badge in Center (Optional subtle context)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'APOTHICARE',
                      style: TextStyle(
                        color: AppColors.forestGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Empty placeholder to keep center badge centered
              const SizedBox(width: 44),
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

  Widget _buildAdminCard({
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    int? badgeCount,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF244082).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 3),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Icon(icon, color: color, size: 22),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (badgeCount != null && badgeCount > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
