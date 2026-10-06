import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';

class AdminThemesScreen extends StatefulWidget {
  const AdminThemesScreen({super.key});

  @override
  State<AdminThemesScreen> createState() => _AdminThemesScreenState();
}

class _AdminThemesScreenState extends State<AdminThemesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().fetchThemes(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── MODAL AJOUTER / MODIFIER UN THÈME (Identique React AjouterTheme.jsx) ───
  void _showAddEditThemeSheet({Map<String, dynamic>? theme}) {
    final isEditing = theme != null;
    final nomController = TextEditingController(
      text: (theme?['nom'] ?? theme?['titre'] ?? '').toString(),
    );
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00897B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEditing ? LucideIcons.pencil : LucideIcons.palette,
                          color: const Color(0xFF00897B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? 'Modifier le thème' : 'Ajouter un thème',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nom du thème
              const Text(
                'Nom du thème *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: nomController,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Ex: INDUSTRIE, OFFICINE, ORDRE...',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  prefixIcon: const Icon(LucideIcons.type, size: 18, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.scaffoldBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
                            AppToast.showError('Veuillez saisir le nom du thème.', context);
                            return;
                          }

                          setSheetState(() => isSubmitting = true);
                          final admin = context.read<AdminProvider>();
                          final themeId = int.tryParse(theme?['id']?.toString() ?? '');

                          final success = await admin.saveTheme(
                            id: themeId,
                            nom: nom,
                          );

                          if (modalCtx.mounted) {
                            Navigator.pop(modalCtx);
                          }

                          if (mounted) {
                            if (success) {
                              AppToast.showSuccess(
                                isEditing ? 'Modification avec succès' : 'Insertion avec succès',
                                context,
                              );
                            } else {
                              AppToast.showError(
                                admin.errorMessage ?? 'Erreur lors de l\'enregistrement.',
                                context,
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isEditing ? 'Enregistrer les modifications' : 'Ajouter le thème',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CHANGER ÉTAT DU THÈME (Identique React themeChangeEtat) ───
  void _handleToggleEtat(Map<String, dynamic> theme) async {
    final admin = context.read<AdminProvider>();
    final themeId = int.tryParse(theme['id']?.toString() ?? '');
    if (themeId == null) return;

    final etatRaw = theme['etat'];
    final isCurrentlyActive = etatRaw == 1 || etatRaw == '1' || etatRaw == true;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCurrentlyActive ? LucideIcons.powerOff : LucideIcons.power,
              color: isCurrentlyActive ? Colors.red : const Color(0xFF15803D),
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(isCurrentlyActive ? 'Désactiver le thème' : 'Activer le thème'),
          ],
        ),
        content: Text(
          isCurrentlyActive
              ? 'Voulez-vous désactiver ce thème ?'
              : 'Voulez-vous activer ce thème ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? Colors.red : const Color(0xFF15803D),
              foregroundColor: Colors.white,
            ),
            child: Text(isCurrentlyActive ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await admin.changeEtatTheme(themeId);
      if (mounted) {
        if (success) {
          AppToast.showSuccess(
            isCurrentlyActive ? 'Désactivation avec succès' : 'Activation avec succès',
            context,
          );
        } else {
          AppToast.showError('Échec de la mise à jour du statut.', context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final allThemes = admin.themes;

    final filteredThemes = allThemes.where((t) {
      if (_searchQuery.isEmpty) return true;
      final name = (t['nom'] ?? t['titre'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery);
    }).toList();

    final activeCount = allThemes.where((t) {
      final e = t['etat'];
      return e == 1 || e == '1' || e == true;
    }).length;
    final inactiveCount = allThemes.length - activeCount;

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
          'Gestion des Thèmes',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.forestGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchThemes(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditThemeSheet(),
        backgroundColor: const Color(0xFF00897B),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'Ajouter un thème',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await admin.fetchThemes(forceRefresh: true);
          if (context.mounted) {
            AppToast.showSuccess('Données actualisées avec succès', context);
          }
        },
        color: const Color(0xFF00897B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Stats Card ───
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF00897B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00695C).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.palette, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Liste des Thèmes',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ${allThemes.length}  •  Actifs: $activeCount  •  Inactifs: $inactiveCount',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // ─── Search Bar ───
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Rechercher un thème...',
                  hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
                  prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ─── List of Themes ───
              if (admin.isLoading && allThemes.isEmpty) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF00897B)),
                  ),
                ),
              ] else if (filteredThemes.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(LucideIcons.palette, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucun thème trouvé',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aucun résultat pour "$_searchQuery"'
                              : 'Cliquez sur le bouton pour ajouter un nouveau thème.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredThemes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = filteredThemes[index];
                    return _buildThemeCard(item);
                  },
                ),
              ],

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeCard(Map<String, dynamic> item) {
    final name = (item['nom'] ?? item['titre'] ?? 'Thème').toString();
    final etatRaw = item['etat'];
    final isActive = etatRaw == null || etatRaw == 1 || etatRaw == '1' || etatRaw == true;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? Colors.grey.shade200 : Colors.red.shade100,
          width: isActive ? 1 : 1.5,
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
          // Icon Container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Icon(LucideIcons.palette, color: Color(0xFF00897B), size: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Name and Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF15803D).withValues(alpha: 0.10)
                        : Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                        size: 11,
                        color: isActive ? const Color(0xFF15803D) : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isActive ? 'Actif' : 'Inactif',
                        style: TextStyle(
                          color: isActive ? const Color(0xFF15803D) : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons (Identiques React: Edit + Toggle Status)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit Button
              IconButton(
                icon: const Icon(LucideIcons.pencil, size: 18, color: Color(0xFFD97706)),
                tooltip: 'Modifier',
                onPressed: () => _showAddEditThemeSheet(theme: item),
              ),

              // Toggle Status Button (Check/Times like in React)
              IconButton(
                icon: Icon(
                  isActive ? LucideIcons.check : LucideIcons.x,
                  size: 20,
                  color: isActive ? const Color(0xFF15803D) : Colors.red,
                ),
                tooltip: isActive ? 'Désactiver' : 'Activer',
                onPressed: () => _handleToggleEtat(item),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
