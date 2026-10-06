import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchCategories(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- MODAL AJOUTER UNE CATÉGORIE (Identique React AjouterCategorie.jsx) ---
  void _showAddCategorieSheet() {
    final admin = context.read<AdminProvider>();
    final nomController = TextEditingController();
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
                  const Text(
                    'Ajouter une catégorie',
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

              // Nom de la catégorie
              TextField(
                controller: nomController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Nom de la catégorie *',
                  hintText: 'Ex: CARDIOLOGIE, PÉDIATRIE...',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.briefcase, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton Enregistrer
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nom = nomController.text.trim();
                          if (nom.isEmpty) {
                            AppToast.showError('Veuillez saisir le nom de la catégorie');
                            return;
                          }

                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await admin.addCategorie(nom);
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
                      : const Text('Enregistrer la catégorie', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- MODAL MODIFIER UNE CATÉGORIE (Identique React update/:id) ---
  void _showEditCategorieSheet(Map<String, dynamic> categorie) {
    final admin = context.read<AdminProvider>();
    final id = int.tryParse(categorie['id']?.toString() ?? '0') ?? 0;
    final initialNom = (categorie['nom'] ?? categorie['designation'] ?? '').toString();

    final nomController = TextEditingController(text: initialNom);
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
                  const Text(
                    'Modifier une catégorie',
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

              // Nom de la catégorie
              TextField(
                controller: nomController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Nom de la catégorie *',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.briefcase, color: AppColors.primaryGreen, size: 20),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton Mettre à jour
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nom = nomController.text.trim();
                          if (nom.isEmpty) {
                            AppToast.showError('Veuillez saisir le nom de la catégorie');
                            return;
                          }

                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await admin.updateCategorie(id, nom);
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
                      : const Text('Mettre à jour', style: TextStyle(fontWeight: FontWeight.w700)),
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

    // Filtrage des catégories
    final filteredCategories = admin.categories.where((cat) {
      final nom = (cat['nom'] ?? cat['designation'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nom.contains(query);
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
          'Catégories',
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
              await admin.fetchCategories(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Bouton + Ajouter une catégorie & Barre de recherche
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                // Bouton Ajouter
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _showAddCategorieSheet,
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text(
                      'Ajouter une catégorie',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Barre de recherche
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Rechercher une catégorie...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary, size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(LucideIcons.x, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // 2. Liste des Catégories
          Expanded(
            child: admin.isLoading && admin.categories.isEmpty
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des catégories...'))
                : filteredCategories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.tags, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'Aucune catégorie trouvée' : 'Aucun résultat correspondant',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await admin.fetchCategories(forceRefresh: true);
                          if (context.mounted) {
                            AppToast.showSuccess('Données actualisées avec succès', context);
                          }
                        },
                        color: AppColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredCategories.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final cat = filteredCategories[idx];
                            final id = int.tryParse(cat['id']?.toString() ?? '0') ?? 0;
                            final nom = (cat['nom'] ?? cat['designation'] ?? 'Catégorie').toString();
                            final etat = int.tryParse(cat['etat']?.toString() ?? '1') ?? 1;
                            final isActif = etat == 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActif ? Colors.transparent : Colors.grey.shade300,
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  // Icône Tag
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF244082).withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Center(
                                      child: Icon(LucideIcons.briefcase, color: Color(0xFF244082), size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Informations (Nom, Statut Badge)
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nom.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: isActif ? AppColors.textPrimary : AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (isActif ? AppColors.success : Colors.grey).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isActif ? 'Actif' : 'Inactif',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isActif ? AppColors.success : Colors.grey.shade700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ACTIONS (Orange Edit + Green/Red Toggle)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Bouton Modifier (Orange)
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 18, color: Color(0xFFF39C12)),
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditCategorieSheet(cat),
                                      ),

                                      // 2. Bouton Toggle État (Vert Check si Actif / Rouge Cross si Désactivé)
                                      IconButton(
                                        icon: Icon(
                                          isActif ? LucideIcons.check : LucideIcons.x,
                                          size: 20,
                                          color: isActif ? AppColors.success : AppColors.error,
                                        ),
                                        tooltip: isActif ? 'Désactiver la catégorie' : 'Activer la catégorie',
                                        onPressed: () async {
                                          if (id > 0) {
                                            final result = await admin.changeCategorieEtat(id, etat);
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
