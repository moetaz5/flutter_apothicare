import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/routes/app_routes.dart';

class AdminDrawer extends StatefulWidget {
  const AdminDrawer({super.key});

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _AdminDrawerState extends State<AdminDrawer> {
  bool _isParametresExpanded = true;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final displayName = user?.nom?.trim().isNotEmpty == true
        ? user!.nom!.trim()
        : (user?.displayName ?? 'Administrateur');
    final email = user?.login ?? user?.email ?? 'admin@cnopt.tn';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Top Header (Logo + Admin Name + Email + Profile Button + Actions)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.borderGray, width: 1)),
              ),
              child: Column(
                children: [
                  // Top action row (Caducee center, notif + logout top-right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 48), // spacer for balance
                      // Caducée Icon & Title
                      Column(
                        children: [
                          Image.asset(
                            'assets/images/icone-40.png',
                            width: 38,
                            height: 38,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              LucideIcons.activity,
                              color: AppColors.primaryGreen,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'APOTHÎCARE',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF244082),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      // Notification & Logout
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.bell, size: 20, color: AppColors.textSecondary),
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, AppRoutes.adminActualites);
                            },
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.logOut, size: 20, color: AppColors.error),
                            onPressed: () => _showLogoutDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Admin Name & Email
                  Text(
                    displayName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Mon Profil Button
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, AppRoutes.profile);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.user, size: 15, color: AppColors.textPrimary),
                          SizedBox(width: 6),
                          Text(
                            'Mon Profil',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Menu List (Identique React)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                children: [
                  // ─── Collapsible Paramètres ───
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _isParametresExpanded = !_isParametresExpanded),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.settings, size: 20, color: Color(0xFF244082)),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Paramètres',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _isParametresExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_isParametresExpanded) ...[
                          const Divider(height: 1, color: AppColors.borderGray),
                          _buildDrawerSubItem(
                            icon: LucideIcons.calendar,
                            title: 'Années',
                            route: AppRoutes.adminAnnees,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.users,
                            title: 'Utilisateurs',
                            route: AppRoutes.adminUsers,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.menu,
                            title: 'Services',
                            route: AppRoutes.adminServices,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.cog,
                            title: 'Procédures',
                            route: AppRoutes.procedures,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.calendarDays,
                            title: 'TB Gardes',
                            route: AppRoutes.adminTbGardes,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.shieldAlert,
                            title: 'Pharmacies de Garde',
                            route: AppRoutes.adminGardes,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.calendarCheck,
                            title: 'Liste Jours Fériés',
                            route: AppRoutes.adminListeJours,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.tags,
                            title: 'Catégories',
                            route: AppRoutes.adminCategories,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.newspaper,
                            title: 'Actualités',
                            route: AppRoutes.adminActualites,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.palette,
                            title: 'Thèmes',
                            route: AppRoutes.adminThemes,
                          ),
                          _buildDrawerSubItem(
                            icon: LucideIcons.megaphone,
                            title: 'Annonces',
                            route: AppRoutes.adminAnnonces,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ─── Standalone Menu Items (Identique React) ───
                  _buildDrawerItem(
                    icon: LucideIcons.shieldAlert,
                    title: 'Pharmacies De Garde',
                    route: AppRoutes.adminGardes,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.calendar,
                    title: 'Jours Fériés',
                    route: AppRoutes.adminGardesJours,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.messageCircle,
                    title: 'Messagerie',
                    route: AppRoutes.messagerie,
                    badgeCount: auth.unreadNotifications,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.fileText,
                    title: 'Connaître Mes Traitements',
                    route: AppRoutes.observance,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.bot,
                    title: 'IBN JAZZAR',
                    route: AppRoutes.chatbot,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.search,
                    title: 'Recherche Pharmacies',
                    route: AppRoutes.gardesMap,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.moon,
                    title: 'Recherche Pharmacies De Nuit',
                    route: AppRoutes.gardesMap,
                    isHighlighted: true,
                  ),
                  _buildDrawerItem(
                    icon: LucideIcons.calendarRange,
                    title: 'Semaine De Garde',
                    route: AppRoutes.adminSemaineGarde,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String route,
    int? badgeCount,
    bool isHighlighted = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFFE0EFD6) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHighlighted ? AppColors.primaryGreen.withValues(alpha: 0.5) : AppColors.borderGray,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Icon(
          icon,
          size: 20,
          color: isHighlighted ? AppColors.primaryGreen : const Color(0xFF4A5568),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w600,
            color: isHighlighted ? AppColors.forestGreen : AppColors.textPrimary,
          ),
        ),
        trailing: (badgeCount != null && badgeCount > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              )
            : const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
        onTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, route);
        },
      ),
    );
  }

  Widget _buildDrawerSubItem({
    required IconData icon,
    required String title,
    required String route,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -2),
      leading: Icon(icon, size: 18, color: AppColors.primaryGreen),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      ),
      trailing: const Icon(LucideIcons.chevronRight, size: 15, color: AppColors.textMuted),
      onTap: () {
        Navigator.pop(context);
        Navigator.pushNamed(context, route);
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
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
              Navigator.pop(context); // Close drawer
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
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
}
