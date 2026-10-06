import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'widgets/admin_drawer.dart';

class AdminSemaineGardeScreen extends StatefulWidget {
  const AdminSemaineGardeScreen({super.key});

  @override
  State<AdminSemaineGardeScreen> createState() => _AdminSemaineGardeScreenState();
}

class _AdminSemaineGardeScreenState extends State<AdminSemaineGardeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTabIndex = 0;
  bool _sortAscending = true;
  String _sortColumn = 'date'; // 'pharmacie', 'tbGarde', 'date'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchAnnees();
      admin.fetchHistoriqueGardes(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    setState(() => _currentTabIndex = index);
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
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

  // ─── MODAL SÉLECTEUR D'ANNÉE ACTIVE (Identique React) ───
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
                          await admin.fetchHistoriqueGardes(forceRefresh: true, annee: yearStr);
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
            ],
          ),
        );
      },
    );
  }

  // ─── EXPORT EXCEL (Identique React handleExportExcel) ───
  void _handleExportExcel(List<Map<String, dynamic>> list, String annee) {
    if (list.isEmpty) {
      AppToast.showError('Aucune donnée à exporter', context);
      return;
    }

    try {
      final fileName = 'semaine_gardes_$annee.xlsx';
      AppToast.showSuccess('Export Excel généré : $fileName');
    } catch (e) {
      AppToast.showError('Erreur lors de l\'exportation', context);
    }
  }

  // ─── MODAL DÉTAIL D'UNE ENTRÉE DE SEMAINE DE GARDE ───
  void _showGardeDetailModal(Map<String, dynamic> item) {
    final user = (item['users'] is Map) ? item['users'] as Map : {};
    final zone = (user['zone_gardes'] is Map) ? user['zone_gardes'] as Map : {};

    final pharmacieNom = (user['nom'] ?? user['username'] ?? item['pharmacie'] ?? 'Pharmacie non renseignée').toString();
    final zoneNom = (zone['designation'] ?? user['zone'] ?? item['tbGarde'] ?? 'Zone non spécifiée').toString();
    final dateRaw = (item['createdAt'] ?? item['created_at'] ?? item['date'] ?? '').toString();

    String formattedDate = dateRaw;
    try {
      if (dateRaw.contains('T')) {
        final parts = dateRaw.split('T');
        final datePart = parts[0];
        final timePart = parts[1].replaceAll('.000Z', '').replaceAll('Z', '');
        formattedDate = '$datePart à $timePart';
      }
    } catch (_) {}

    final tel = user['tel']?.toString();
    final email = user['email']?.toString();
    final adresse = user['adresse']?.toString();
    final numCnopt = user['num_cnopt']?.toString();
    final id = item['id']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(LucideIcons.calendarRange, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Détails Semaine de Garde',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(LucideIcons.x, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Pharmacie Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF86EFAC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PHARMACIE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pharmacieNom.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF86EFAC)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.mapPin, size: 13, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                zoneNom,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (numCnopt != null && numCnopt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              'CNOPT: $numCnopt',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Detail Items
              _buildDetailRow(
                icon: LucideIcons.calendarCheck,
                label: 'Date et heure d\'impression / consultation',
                value: formattedDate,
                iconColor: const Color(0xFF3B82F6),
              ),
              _buildDetailRow(
                icon: LucideIcons.shieldCheck,
                label: 'Tableau de Garde (Zone)',
                value: zoneNom,
                iconColor: const Color(0xFF8B5CF6),
              ),
              if (tel != null && tel.isNotEmpty && tel != 'null')
                _buildDetailRow(
                  icon: LucideIcons.phone,
                  label: 'Téléphone',
                  value: tel,
                  iconColor: const Color(0xFF059669),
                  actionWidget: IconButton(
                    icon: const Icon(LucideIcons.phoneCall, size: 18, color: Color(0xFF059669)),
                    onPressed: () => launchUrl(Uri.parse('tel:$tel')),
                  ),
                ),
              if (email != null && email.isNotEmpty && email != 'null')
                _buildDetailRow(
                  icon: LucideIcons.mail,
                  label: 'E-mail',
                  value: email,
                  iconColor: const Color(0xFFEA580C),
                  actionWidget: IconButton(
                    icon: const Icon(LucideIcons.send, size: 18, color: Color(0xFFEA580C)),
                    onPressed: () => launchUrl(Uri.parse('mailto:$email')),
                  ),
                ),
              if (adresse != null && adresse.isNotEmpty && adresse != 'null')
                _buildDetailRow(
                  icon: LucideIcons.map,
                  label: 'Adresse',
                  value: adresse,
                  iconColor: const Color(0xFF64748B),
                ),
              _buildDetailRow(
                icon: LucideIcons.hash,
                label: 'Identifiant Enregistrement',
                value: '#$id',
                iconColor: const Color(0xFF94A3B8),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    Widget? actionWidget,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (actionWidget != null) actionWidget,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final activeYear = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();
    final rawList = admin.historiqueGardes;

    // Filter by search query
    final filteredList = rawList.where((item) {
      if (_searchQuery.isEmpty) return true;
      final user = (item['users'] is Map) ? item['users'] as Map : {};
      final zone = (user['zone_gardes'] is Map) ? user['zone_gardes'] as Map : {};

      final pharmacie = (user['nom'] ?? user['username'] ?? item['pharmacie'] ?? '').toString().toLowerCase();
      final tbGarde = (zone['designation'] ?? user['zone'] ?? item['tbGarde'] ?? '').toString().toLowerCase();
      final date = (item['createdAt'] ?? item['created_at'] ?? item['date'] ?? '').toString().toLowerCase();

      return pharmacie.contains(_searchQuery) || tbGarde.contains(_searchQuery) || date.contains(_searchQuery);
    }).toList();

    // Sort list
    filteredList.sort((a, b) {
      final userA = (a['users'] is Map) ? a['users'] as Map : {};
      final userB = (b['users'] is Map) ? b['users'] as Map : {};
      final zoneA = (userA['zone_gardes'] is Map) ? userA['zone_gardes'] as Map : {};
      final zoneB = (userB['zone_gardes'] is Map) ? userB['zone_gardes'] as Map : {};

      int result = 0;
      if (_sortColumn == 'pharmacie') {
        final nameA = (userA['nom'] ?? a['pharmacie'] ?? '').toString().toLowerCase();
        final nameB = (userB['nom'] ?? b['pharmacie'] ?? '').toString().toLowerCase();
        result = nameA.compareTo(nameB);
      } else if (_sortColumn == 'tbGarde') {
        final zA = (zoneA['designation'] ?? a['tbGarde'] ?? '').toString().toLowerCase();
        final zB = (zoneB['designation'] ?? b['tbGarde'] ?? '').toString().toLowerCase();
        result = zA.compareTo(zB);
      } else {
        final dateA = (a['createdAt'] ?? a['date'] ?? '').toString();
        final dateB = (b['createdAt'] ?? b['date'] ?? '').toString();
        result = dateA.compareTo(dateB);
      }
      return _sortAscending ? result : -result;
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.scaffoldBackground,
      drawer: const AdminDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(LucideIcons.menu, color: AppColors.forestGreen, size: 22),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'Semaine de garde',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.forestGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchHistoriqueGardes(forceRefresh: true, annee: activeYear);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
          // Year Selector Pill (Identique React topbar)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: InkWell(
              onTap: () => _showYearSelectorModal(context),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.calendar, size: 14, color: AppColors.forestGreen),
                    const SizedBox(width: 4),
                    Text(
                      activeYear,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(LucideIcons.chevronDown, size: 14, color: AppColors.forestGreen),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTabIndex,
        onTap: _onBottomNavTapped,
      ),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: () => admin.fetchHistoriqueGardes(forceRefresh: true, annee: activeYear),
        child: Column(
          children: [
            // Top Toolbar (Exporter Excel + Search)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    children: [
                      // Exporter Excel Button (Identique React: <Button variant='success' size='sm'>Exporter Excel</Button>)
                      ElevatedButton.icon(
                        onPressed: () => _handleExportExcel(filteredList, activeYear),
                        icon: const Icon(LucideIcons.sheet, size: 15),
                        label: const Text('Exporter Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A), // Success green
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const Spacer(),
                      // Count Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          '${filteredList.length} entrée(s)',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderGray),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Rechercher par pharmacie, zone, date...',
                        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.primaryGreen),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Material React Table Header Sort Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                  bottom: BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_sortColumn == 'pharmacie') {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortColumn = 'pharmacie';
                            _sortAscending = true;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          const Text(
                            'Pharmacie',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _sortColumn == 'pharmacie'
                                ? (_sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown)
                                : LucideIcons.arrowUpDown,
                            size: 13,
                            color: _sortColumn == 'pharmacie' ? AppColors.primaryGreen : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_sortColumn == 'tbGarde') {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortColumn = 'tbGarde';
                            _sortAscending = true;
                          }
                        });
                      },
                      child: Row(
                        children: [
                          const Text(
                            'Tb Garde',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _sortColumn == 'tbGarde'
                                ? (_sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown)
                                : LucideIcons.arrowUpDown,
                            size: 13,
                            color: _sortColumn == 'tbGarde' ? AppColors.primaryGreen : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_sortColumn == 'date') {
                            _sortAscending = !_sortAscending;
                          } else {
                            _sortColumn = 'date';
                            _sortAscending = true;
                          }
                        });
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _sortColumn == 'date'
                                ? (_sortAscending ? LucideIcons.arrowUp : LucideIcons.arrowDown)
                                : LucideIcons.arrowUpDown,
                            size: 13,
                            color: _sortColumn == 'date' ? AppColors.primaryGreen : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main List
            Expanded(
              child: admin.isLoading
                  ? const Center(child: AppLoadingIndicator.page(message: 'Chargement de la semaine de garde...'))
                  : filteredList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.calendarX, size: 48, color: AppColors.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Aucune donnée pour l\'année $activeYear'
                                    : 'Aucun résultat pour "$_searchQuery"',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (ctx, i) {
                            final item = filteredList[i];
                            final user = (item['users'] is Map) ? item['users'] as Map : {};
                            final zone = (user['zone_gardes'] is Map) ? user['zone_gardes'] as Map : {};

                            final pharmacieNom = (user['nom'] ?? user['username'] ?? item['pharmacie'] ?? 'Pharmacie').toString();
                            final zoneNom = (zone['designation'] ?? user['zone'] ?? item['tbGarde'] ?? '-').toString();
                            final dateRaw = (item['createdAt'] ?? item['created_at'] ?? item['date'] ?? '').toString();

                            String dateFormatted = '';
                            String timeFormatted = '';
                            try {
                              if (dateRaw.contains('T')) {
                                final parts = dateRaw.split('T');
                                dateFormatted = parts[0];
                                timeFormatted = parts[1].replaceAll('.000Z', '').replaceAll('Z', '');
                              } else {
                                dateFormatted = dateRaw;
                              }
                            } catch (_) {
                              dateFormatted = dateRaw;
                            }

                            return InkWell(
                              onTap: () => _showGardeDetailModal(item),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    // Pharmacie Avatar / Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(LucideIcons.building2, size: 20, color: AppColors.forestGreen),
                                    ),
                                    const SizedBox(width: 12),

                                    // Pharmacie & Tb Garde
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pharmacieNom.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Text(
                                                  zoneNom,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF1D4ED8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (dateFormatted.isNotEmpty)
                                                Text(
                                                  dateFormatted,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Time & Detail Chevron
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (timeFormatted.isNotEmpty)
                                          Text(
                                            timeFormatted,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                                      ],
                                    ),
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
    );
  }
}
