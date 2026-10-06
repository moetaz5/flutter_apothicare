import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchServices();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddServiceSheet() {
    final nomController = TextEditingController();
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
                    'Ajouter un service',
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

              // Nom du service
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du service *',
                  hintText: 'Ex: Salle d\'injection, Suivi pondéral...',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.briefcase, color: AppColors.primaryGreen, size: 20),
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
                            AppToast.showError('Veuillez saisir le nom du service');
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await context.read<AdminProvider>().addService(nom);
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
                      : const Text('Enregistrer le service', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditServiceSheet(Map<String, dynamic> service) {
    final id = int.tryParse(service['id']?.toString() ?? '0') ?? 0;
    final nomController = TextEditingController(text: (service['nom'] ?? service['designation'] ?? '').toString());
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
                    'Modifier un service',
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

              // Nom du service
              TextField(
                controller: nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du service *',
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(LucideIcons.briefcase, color: AppColors.primaryGreen, size: 20),
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
                            AppToast.showError('Veuillez saisir le nom du service');
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          Navigator.pop(ctx);
                          final result = await context.read<AdminProvider>().updateService(id, nom);
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

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final services = admin.services.where((s) {
      if (_searchQuery.isEmpty) return true;
      final nom = (s['nom'] ?? s['designation'] ?? '').toString().toLowerCase();
      return nom.contains(_searchQuery.toLowerCase());
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
          'Gestion des Services',
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
              await admin.fetchServices(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Top Search & Add Bar (Identique React ListServices.jsx)
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
                        hintText: 'Rechercher un service...',
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
                  onPressed: _showAddServiceSheet,
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

          // Content List
          Expanded(
            child: admin.isLoading && admin.services.isEmpty
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des services...'))
                : services.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.briefcase, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty ? 'Aucun service enregistré' : 'Aucun service trouvé',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await admin.fetchServices(forceRefresh: true);
                          if (context.mounted) {
                            AppToast.showSuccess('Données actualisées avec succès', context);
                          }
                        },
                        color: AppColors.primaryGreen,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: services.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final s = services[idx];
                            final id = int.tryParse(s['id']?.toString() ?? '0') ?? 0;
                            final name = (s['nom'] ?? s['designation'] ?? 'Service').toString();
                            final etat = int.tryParse(s['etat']?.toString() ?? '1') ?? 1;
                            final isActif = etat == 1;

                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isActif
                                          ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                          : Colors.grey.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        isActif ? LucideIcons.checkSquare : LucideIcons.square,
                                        color: isActif ? AppColors.primaryGreen : AppColors.textMuted,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Nom du service & Badge Actif / Désactivé
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: isActif
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isActif
                                                  ? AppColors.primaryGreen.withValues(alpha: 0.3)
                                                  : Colors.red.withValues(alpha: 0.3),
                                            ),
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
                                  ),

                                  // Actions Column (Identique React: Edit Orange + Toggle State Check/Cross)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // 1. Bouton Modifier (Orange / Edit)
                                      IconButton(
                                        icon: const Icon(LucideIcons.pencil, size: 20, color: Color(0xFFE5A800)),
                                        tooltip: 'Modifier',
                                        onPressed: () => _showEditServiceSheet(s),
                                      ),

                                      // 2. Bouton Toggle État (Vert Check si Actif / Rouge Cross si Désactivé)
                                      IconButton(
                                        icon: Icon(
                                          isActif ? LucideIcons.check : LucideIcons.x,
                                          size: 20,
                                          color: isActif ? AppColors.success : AppColors.error,
                                        ),
                                        tooltip: isActif ? 'Désactiver le service' : 'Activer le service',
                                        onPressed: () async {
                                          if (id > 0) {
                                            final result = await admin.changeServiceEtat(id, etat);
                                            if (mounted) {
                                              if (result.success) {
                                                AppToast.showSuccess(result.message);
                                              } else {
                                                AppToast.showError(result.message);
                                              }
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
