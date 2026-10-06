import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'widgets/admin_drawer.dart';

class AdminListJoursScreen extends StatefulWidget {
  const AdminListJoursScreen({super.key});

  @override
  State<AdminListJoursScreen> createState() => _AdminListJoursScreenState();
}

class _AdminListJoursScreenState extends State<AdminListJoursScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchAnnees();
      admin.fetchJoursFeries(forceRefresh: true);
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

  // ─── MODAL AJOUTER / MODIFIER UN JOUR FÉRIÉ (Identique React AjouterJours.jsx) ───
  void _showAddEditJourSheet({Map<String, dynamic>? jour}) {
    final admin = context.read<AdminProvider>();
    final isEditing = jour != null;
    final id = isEditing ? int.tryParse(jour['id']?.toString() ?? '0') ?? 0 : 0;

    final nomController = TextEditingController(text: isEditing ? (jour['nom'] ?? '') : '');
    final dateController = TextEditingController(
      text: isEditing ? (jour['date'] ?? '').toString().split('T').first : '',
    );
    String selectedType = isEditing ? (jour['type']?.toString() ?? '1') : '1'; // '1': National, '2': Religieux
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
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
                  Text(
                    isEditing ? 'Modifier le jour férié' : 'Ajouter un jour férié',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nom du jour
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du jour *',
                  hintText: 'Ex: 1er jour Aïd El Fitr, Fête du travail...',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendarCheck, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Date du jour (DatePicker)
              TextField(
                controller: dateController,
                readOnly: true,
                onTap: () async {
                  final now = DateTime.now();
                  DateTime initial = now;
                  if (dateController.text.isNotEmpty) {
                    try {
                      initial = DateTime.parse(dateController.text);
                    } catch (_) {}
                  }

                  final picked = await showDatePicker(
                    context: modalCtx,
                    initialDate: initial,
                    firstDate: DateTime(now.year - 5),
                    lastDate: DateTime(now.year + 10),
                    locale: const Locale('fr', 'FR'),
                  );
                  if (picked != null) {
                    final monthStr = picked.month.toString().padLeft(2, '0');
                    final dayStr = picked.day.toString().padLeft(2, '0');
                    setSheetState(() {
                      dateController.text = '${picked.year}-$monthStr-$dayStr';
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Date *',
                  hintText: 'YYYY-MM-DD',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendar, color: AppColors.primaryGreen, size: 20),
                  suffixIcon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                ),
              ),
              const SizedBox(height: 14),

              // Type (National vs Religieux)
              const Text('Type de jour férié *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('National')),
                      selected: selectedType == '1',
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selectedType == '1' ? AppColors.primaryGreen : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedType = '1');
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Religieux')),
                      selected: selectedType == '2',
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selectedType == '2' ? AppColors.primaryGreen : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedType = '2');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nom = nomController.text.trim();
                          final date = dateController.text.trim();
                          if (nom.isEmpty || date.isEmpty) {
                            AppToast.showError('Veuillez remplir le nom et la date du jour férié');
                            return;
                          }

                          setSheetState(() => isSubmitting = true);

                          final res = isEditing
                              ? await admin.updateJourFerie(
                                  id: id,
                                  nomJour: nom,
                                  dateJour: date,
                                  type: selectedType,
                                )
                              : await admin.addJourFerie(
                                  nomJour: nom,
                                  dateJour: date,
                                  type: selectedType,
                                );

                          setSheetState(() => isSubmitting = false);

                          if (res.success) {
                            if (!context.mounted) return;
                            Navigator.pop(ctx);
                            AppToast.showSuccess(res.message);
                          } else {
                            AppToast.showError(res.message);
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.check, size: 18),
                  label: Text(
                    isSubmitting ? 'Enregistrement...' : (isEditing ? 'Modifier' : 'Ajouter'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forestGreen,
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
    );
  }

  // ─── SÉLECTIONNER L'ANNÉE ACTIVE MODAL ───
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
                          await admin.fetchJoursFeries(forceRefresh: true);
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

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final auth = context.watch<AuthProvider>();
    final rawJours = admin.joursFeries;

    final filteredList = rawJours.where((j) {
      if (_searchQuery.isEmpty) return true;
      final nom = (j['nom'] ?? j['nom_jour'] ?? '').toString().toLowerCase();
      final date = (j['date'] ?? '').toString().toLowerCase();
      return nom.contains(_searchQuery) || date.contains(_searchQuery);
    }).toList();

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
          'Liste des jours fériés',
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
              await admin.fetchJoursFeries(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
          // Year Selector Pill
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
                      admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                    ),
                  ],
                ),
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
      body: RefreshIndicator(
        onRefresh: () => admin.fetchJoursFeries(forceRefresh: true),
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── TOP ACTION: + Ajouter un jour férié (Identique React ListJours.jsx) ───
              ElevatedButton.icon(
                onPressed: () => _showAddEditJourSheet(),
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('Ajouter un jour férié', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const SizedBox(height: 14),

              // ─── SEARCH INPUT ───
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un jour férié...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(LucideIcons.search, color: AppColors.forestGreen, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
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
              const SizedBox(height: 16),

              // ─── LIST TITLE ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Jours fériés (${filteredList.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                  ),
                  if (admin.isLoading)
                    const AppLoadingIndicator.small(size: 16),
                ],
              ),
              const SizedBox(height: 10),

              // ─── LIST OF HOLIDAYS ───
              if (admin.isLoading && rawJours.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: AppLoadingIndicator.page(message: 'Chargement des jours fériés...')),
                )
              else if (filteredList.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(LucideIcons.calendarX, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      const Text(
                        'Aucun jour férié trouvé',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                    final nom = item['nom'] ?? item['nom_jour'] ?? 'Jour férié';
                    final date = (item['date'] ?? '').toString().split('T').first;
                    final type = item['type']?.toString() ?? '1';
                    final isNational = type == '1';
                    final etat = int.tryParse(item['etat']?.toString() ?? '1') ?? 1;
                    final isActif = etat == 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isNational
                                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                  : const Color(0xFF9C27B0).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isNational ? LucideIcons.flag : LucideIcons.moon,
                              size: 20,
                              color: isNational ? AppColors.forestGreen : const Color(0xFF7B1FA2),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nom,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 12, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      date,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.forestGreen),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isNational
                                            ? AppColors.primaryGreen.withValues(alpha: 0.10)
                                            : const Color(0xFF9C27B0).withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isNational ? 'National' : 'Religieux',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isNational ? AppColors.forestGreen : const Color(0xFF7B1FA2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions (Edit & Toggle State)
                          IconButton(
                            icon: const Icon(LucideIcons.edit, size: 18, color: Color(0xFFF57F17)),
                            onPressed: () => _showAddEditJourSheet(jour: item),
                            visualDensity: VisualDensity.compact,
                          ),
                          IconButton(
                            icon: Icon(
                              isActif ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                              size: 20,
                              color: isActif ? AppColors.primaryGreen : AppColors.error,
                            ),
                            onPressed: () async {
                              final res = await admin.changeJourEtat(id, etat);
                              if (res.success) {
                                AppToast.showSuccess(res.message);
                              } else {
                                AppToast.showError(res.message);
                              }
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
