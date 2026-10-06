import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/admin_provider.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../shared/widgets/app_loading_indicator.dart';

class AdminAnneesScreen extends StatefulWidget {
  const AdminAnneesScreen({super.key});

  @override
  State<AdminAnneesScreen> createState() => _AdminAnneesScreenState();
}

class _AdminAnneesScreenState extends State<AdminAnneesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchAnnees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddAnneeSheet() {
    final anneeController = TextEditingController(text: DateTime.now().year.toString());
    bool isSelected = false;
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
                    'Ajouter une année',
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

              // Année Input
              TextField(
                controller: anneeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Année (ex: 2026) *',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendar, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Active / Selected Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sélectionner comme année active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('Rendre cette année active par défaut', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                    Switch(
                      value: isSelected,
                      activeTrackColor: AppColors.primaryGreen,
                      onChanged: (val) => setSheetState(() => isSelected = val),
                    ),
                  ],
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
                          final anneeStr = anneeController.text.trim();
                          if (anneeStr.isEmpty) {
                            AppToast.showError('L\'année est obligatoire');
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await context.read<AdminProvider>().addAnnee(
                                anneeStr,
                                isSelected ? 1 : 0,
                              );
                          if (mounted) {
                            if (result.success) {
                              AppToast.showSuccess(result.message);
                            } else {
                              AppToast.showError(result.message);
                            }
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
                      : const Text('Enregistrer l\'année', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditAnneeSheet(Map<String, dynamic> item) {
    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
    final anneeController = TextEditingController(text: item['annee']?.toString() ?? '');
    bool isSelected = item['selected'] == 1 || item['selected']?.toString() == '1';
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
                    'Modifier l\'année',
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

              // Année Input
              TextField(
                controller: anneeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Année *',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.calendar, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 16),

              // Active / Selected Toggle
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sélectionner comme année active', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('Rendre cette année active par défaut', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                      ],
                    ),
                    Switch(
                      value: isSelected,
                      activeTrackColor: AppColors.primaryGreen,
                      onChanged: (val) => setSheetState(() => isSelected = val),
                    ),
                  ],
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
                          final anneeStr = anneeController.text.trim();
                          if (anneeStr.isEmpty) {
                            AppToast.showError('L\'année est obligatoire');
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await context.read<AdminProvider>().updateAnnee(
                                id,
                                anneeStr,
                                isSelected ? 1 : 0,
                              );
                          if (mounted) {
                            if (result.success) {
                              AppToast.showSuccess(result.message);
                            } else {
                              AppToast.showError(result.message);
                            }
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

  void _confirmDeleteAnnee(int id, String anneeStr) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'année', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
        content: Text('Êtes-vous sûr de vouloir supprimer l\'année "$anneeStr" ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<AdminProvider>().deleteAnnee(id);
              if (mounted) {
                if (success) {
                  AppToast.showSuccess('Année supprimée avec succès');
                } else {
                  AppToast.showError('Erreur lors de la suppression');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final annees = admin.annees.where((a) {
      if (_searchQuery.isEmpty) return true;
      final yearStr = (a['annee'] ?? '').toString().toLowerCase();
      return yearStr.contains(_searchQuery.toLowerCase());
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
          'Gestion des Années',
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
              await admin.fetchAnnees(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search & Add Bar
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
                        hintText: 'Rechercher une année...',
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
                  onPressed: _showAddAnneeSheet,
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

          // Active Year Banner
          if (admin.selectedYear.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.calendarCheck2, color: AppColors.primaryGreen, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Année active en cours : ',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  Text(
                    admin.selectedYear,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ],
              ),
            ),

          // Content List
          Expanded(
            child: admin.isLoading
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des années...'))
                : annees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.calendarOff, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'Aucune année enregistrée' : 'Aucune année trouvée',
                              style: const TextStyle(fontSize: 15, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primaryGreen,
                        onRefresh: () async {
                          await admin.fetchAnnees(forceRefresh: true);
                          if (context.mounted) {
                            AppToast.showSuccess('Données actualisées avec succès', context);
                          }
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: annees.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, index) {
                            final item = annees[index];
                            final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                            final anneeStr = item['annee']?.toString() ?? '';
                            final isSelected = item['selected'] == 1 ||
                                item['selected']?.toString() == '1' ||
                                admin.selectedYear == anneeStr;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? AppColors.primaryGreen : AppColors.borderGray,
                                  width: isSelected ? 1.5 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppColors.primaryGreen.withValues(alpha: 0.08)
                                        : Colors.black.withValues(alpha: 0.03),
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
                                      color: isSelected ? const Color(0xFFE8F5E9) : AppColors.scaffoldBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isSelected ? LucideIcons.calendarCheck : LucideIcons.calendar,
                                      color: isSelected ? AppColors.primaryGreen : AppColors.forestGreen,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Year Label & Active Status
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          anneeStr,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.forestGreen,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        InkWell(
                                          onTap: () {
                                            if (!isSelected && id > 0) {
                                              admin.selectActiveYear(id, anneeStr);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSelected ? const Color(0xFFE8F5E9) : Colors.grey.shade100,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isSelected ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                                  size: 13,
                                                  color: isSelected ? AppColors.primaryGreen : AppColors.textMuted,
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    isSelected ? 'Active (Sélectionnée)' : 'Définir comme active',
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: isSelected ? AppColors.primaryGreen : AppColors.textMuted,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Action Buttons (Modifier, Supprimer)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Modifier
                                      IconButton(
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        splashRadius: 18,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(LucideIcons.pencil, size: 18, color: Color(0xFFE5A800)),
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditAnneeSheet(item),
                                      ),
                                      const SizedBox(width: 4),
                                      // Supprimer
                                      IconButton(
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        splashRadius: 18,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                                        tooltip: 'Supprimer',
                                        onPressed: () => _confirmDeleteAnnee(id, anneeStr),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ).animate().fadeIn(duration: 250.ms);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
