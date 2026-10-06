import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';

class AdminTbGardesScreen extends StatefulWidget {
  const AdminTbGardesScreen({super.key});

  @override
  State<AdminTbGardesScreen> createState() => _AdminTbGardesScreenState();
}

class _AdminTbGardesScreenState extends State<AdminTbGardesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchTbGardes();
      admin.fetchGouvernorats();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddTbGardeSheet() {
    final admin = context.read<AdminProvider>();
    final nomController = TextEditingController();
    int? selectedGouvernoratId = admin.gouvernorats.isNotEmpty
        ? int.tryParse(admin.gouvernorats.first['id']?.toString() ?? '')
        : null;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Ajouter un TB de garde',
                    style: TextStyle(
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

              // Nom de la zone / TB
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du TB de garde *',
                  hintText: 'Ex: CITÉ EL KHADRA, LA MARSA...',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendarDays, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Gouvernorat Dropdown
              const Text('Gouvernorat *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedGouvernoratId,
                    isExpanded: true,
                    hint: const Text('Sélectionner un gouvernorat'),
                    items: admin.gouvernorats.map((g) {
                      final id = int.tryParse(g['id']?.toString() ?? '0') ?? 0;
                      final nom = (g['nom'] ?? 'Gouvernorat').toString();
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedGouvernoratId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nom = nomController.text.trim();
                          if (nom.isEmpty) {
                            AppToast.showError('Veuillez saisir le nom de la zone');
                            return;
                          }
                          if (selectedGouvernoratId == null || selectedGouvernoratId == 0) {
                            AppToast.showError('Veuillez sélectionner un gouvernorat');
                            return;
                          }

                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await admin.addTbGarde(
                                nom,
                                selectedGouvernoratId!,
                              );
                          if (!mounted) return;
                          if (result.success) {
                            AppToast.showSuccess(result.message);
                          } else {
                            AppToast.showError(result.message);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer le TB de garde', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditTbGardeSheet(Map<String, dynamic> item) {
    final admin = context.read<AdminProvider>();
    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final nomController = TextEditingController(text: (item['designation'] ?? item['nom'] ?? item['nom_zone'] ?? '').toString());
    int? selectedGouvernoratId = int.tryParse(item['id_gouvernorat']?.toString() ?? '') ??
        (admin.gouvernorats.isNotEmpty ? int.tryParse(admin.gouvernorats.first['id']?.toString() ?? '') : null);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Modifier le TB de garde',
                    style: TextStyle(
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

              // Nom de la zone / TB
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du TB de garde *',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendarDays, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Gouvernorat Dropdown
              const Text('Gouvernorat *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderGray),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: selectedGouvernoratId,
                    isExpanded: true,
                    hint: const Text('Sélectionner un gouvernorat'),
                    items: admin.gouvernorats.map((g) {
                      final gId = int.tryParse(g['id']?.toString() ?? '0') ?? 0;
                      final nom = (g['nom'] ?? 'Gouvernorat').toString();
                      return DropdownMenuItem<int>(
                        value: gId,
                        child: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedGouvernoratId = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nom = nomController.text.trim();
                          if (nom.isEmpty) {
                            AppToast.showError('Veuillez saisir le nom de la zone');
                            return;
                          }
                          if (selectedGouvernoratId == null || selectedGouvernoratId == 0) {
                            AppToast.showError('Veuillez sélectionner un gouvernorat');
                            return;
                          }

                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await admin.updateTbGarde(
                                id,
                                nom,
                                selectedGouvernoratId!,
                              );
                          if (!mounted) return;
                          if (result.success) {
                            AppToast.showSuccess(result.message);
                          } else {
                            AppToast.showError(result.message);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final list = admin.tbGardes.where((z) {
      if (_searchQuery.isEmpty) return true;
      final nom = (z['designation'] ?? z['nom'] ?? z['nom_zone'] ?? '').toString().toLowerCase();
      final gvName = (z['gouvernorats'] is Map
              ? (z['gouvernorats']['nom'] ?? '')
              : (z['gouvernorat_nom'] ?? ''))
          .toString()
          .toLowerCase();
      return nom.contains(_searchQuery.toLowerCase()) || gvName.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.forestGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestion des TB de Garde',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.primaryGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchTbGardes(forceRefresh: true);
              await admin.fetchGouvernorats();
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search & Add Bar (Identique React ListZone.jsx)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      decoration: const InputDecoration(
                        hintText: 'Rechercher un TB ou gouvernorat...',
                        hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        prefixIcon: Icon(LucideIcons.search, size: 18, color: AppColors.textMuted),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _showAddTbGardeSheet,
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          // Total count bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F8EC),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 16, color: AppColors.forestGreen),
                const SizedBox(width: 8),
                Text(
                  'Total TB de garde : ${list.length}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.forestGreen,
                  ),
                ),
              ],
            ),
          ),

          // Content List
          Expanded(
            child: admin.isLoading && admin.tbGardes.isEmpty
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des TB de garde...'))
                : list.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.calendarDays, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'Aucun TB de garde enregistré' : 'Aucun TB de garde trouvé',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await admin.fetchTbGardes(forceRefresh: true);
                          await admin.fetchGouvernorats();
                          if (context.mounted) {
                            AppToast.showSuccess('Données actualisées avec succès', context);
                          }
                        },
                        color: AppColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final item = list[idx];
                            final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                            final name = (item['designation'] ?? item['nom'] ?? item['nom_zone'] ?? 'TB de garde').toString();
                            final gvName = (item['gouvernorats'] is Map
                                    ? (item['gouvernorats']['nom'] ?? '')
                                    : (item['gouvernorat_nom'] ?? ''))
                                .toString();
                            final etat = int.tryParse(item['etat']?.toString() ?? '1') ?? 1;
                            final isActif = etat == 1;

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActif ? AppColors.primaryGreen.withValues(alpha: 0.25) : Colors.red.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icon Badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isActif
                                          ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        LucideIcons.calendarDays,
                                        color: isActif ? AppColors.primaryGreen : AppColors.textMuted,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // TB de garde & Gouvernorat
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name.toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.forestGreen,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            if (gvName.isNotEmpty) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFE3F2FD),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(LucideIcons.mapPin, size: 11, color: Color(0xFF1976D2)),
                                                    const SizedBox(width: 3),
                                                    Text(
                                                      gvName.toUpperCase(),
                                                      style: const TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: Color(0xFF1976D2),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                            ],
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: isActif ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                isActif ? 'Actif' : 'Désactivé',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: isActif ? AppColors.primaryGreen : Colors.red.shade700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Actions Column (Identique React: Edit Orange + Toggle State Check/Cross)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Bouton Modifier (Orange / Edit)
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 20, color: Color(0xFFE5A800)),
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditTbGardeSheet(item),
                                      ),

                                      // 2. Bouton Toggle État (Vert Check si Actif / Rouge Cross si Désactivé)
                                      IconButton(
                                        icon: Icon(
                                          isActif ? LucideIcons.check : LucideIcons.x,
                                          size: 20,
                                          color: isActif ? AppColors.success : AppColors.error,
                                        ),
                                        tooltip: isActif ? 'Désactiver le TB de garde' : 'Activer le TB de garde',
                                        onPressed: () async {
                                          if (id > 0) {
                                            final result = await admin.changeTbGardeEtat(id, etat);
                                            if (!mounted) return;
                                            if (result.success) {
                                              AppToast.showSuccess(result.message);
                                            } else {
                                              AppToast.showError(result.message);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 200.ms);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
