import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/actualite_model.dart';
import '../../../core/providers/actualite_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../actualites/presentation/actualite_detail_screen.dart';

class AdminActualitesScreen extends StatefulWidget {
  const AdminActualitesScreen({super.key});

  @override
  State<AdminActualitesScreen> createState() => _AdminActualitesScreenState();
}

class _AdminActualitesScreenState extends State<AdminActualitesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  int? _selectedThemeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final actualiteProvider = context.read<ActualiteProvider>();
      actualiteProvider.fetchActualites(forceRefresh: true, isAdmin: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- MODAL AJOUTER / MODIFIER UNE ACTUALITÉ ---
  void _showAddEditActualiteSheet({ActualiteModel? actualite}) {
    final actualiteProvider = context.read<ActualiteProvider>();
    final isEditing = actualite != null;

    final titreController = TextEditingController(text: actualite?.titre ?? '');
    final descriptionController = TextEditingController(text: actualite?.description ?? '');
    int? selectedThemeId = actualite?.idTheme;
    XFile? pickedImage;
    XFile? pickedVideo;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.90,
          ),
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
          child: SingleChildScrollView(
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
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isEditing ? LucideIcons.pencil : LucideIcons.newspaper,
                            color: AppColors.primaryGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isEditing ? 'Modifier l\'actualité' : 'Ajouter une actualité',
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

                // Titre
                const Text(
                  'Titre de l\'actualité *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: titreController,
                  decoration: InputDecoration(
                    hintText: 'Ex: Campagne de vaccination...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                    prefixIcon: const Icon(LucideIcons.heading, size: 18, color: AppColors.textSecondary),
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
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Thème Dropdown
                const Text(
                  'Thème',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<int?>(
                  initialValue: selectedThemeId,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.scaffoldBackground,
                    prefixIcon: const Icon(LucideIcons.palette, size: 18, color: AppColors.textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Sélectionner un thème (Optionnel)'),
                    ),
                    ...actualiteProvider.themes.map((theme) {
                      return DropdownMenuItem<int?>(
                        value: theme.id,
                        child: Text(theme.nom),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setSheetState(() {
                      selectedThemeId = val;
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Description
                const Text(
                  'Description *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Détails et contenu de l\'actualité...',
                    hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
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
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Image Picker
                const Text(
                  'Image de couverture',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (pickedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(pickedImage!.path),
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: () => setSheetState(() => pickedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.trash2, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else if (actualite?.image != null && actualite!.image!.isNotEmpty) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: '${AppConstants.backBaseUrl}uploads/${actualite.image}',
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Center(child: CircularProgressIndicator()),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 150,
                            color: Colors.grey.shade200,
                            child: const Icon(LucideIcons.image, size: 40, color: Colors.grey),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                            if (image != null) {
                              setSheetState(() => pickedImage = image);
                            }
                          },
                          icon: const Icon(LucideIcons.upload, size: 14),
                          label: const Text('Changer', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black.withValues(alpha: 0.7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  InkWell(
                    onTap: () async {
                      final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (image != null) {
                        setSheetState(() => pickedImage = image);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.imagePlus, color: AppColors.primaryGreen, size: 28),
                          SizedBox(height: 6),
                          Text(
                            'Ajouter une image depuis la galerie',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 14),

                // ─── Video Picker (Identique React: Uploader une vidéo) ───
                const Text(
                  'Uploader une vidéo (Optionnel)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                if (pickedVideo != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.video, color: AppColors.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            pickedVideo!.name,
                            style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, color: Colors.redAccent, size: 18),
                          onPressed: () => setSheetState(() => pickedVideo = null),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else if (actualite?.video != null && actualite!.video!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.video, color: AppColors.primaryGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Vidéo actuelle: ${actualite.video}',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            final video = await _picker.pickVideo(source: ImageSource.gallery);
                            if (video != null) {
                              setSheetState(() => pickedVideo = video);
                            }
                          },
                          child: const Text('Remplacer', style: TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ] else ...[
                  InkWell(
                    onTap: () async {
                      final video = await _picker.pickVideo(source: ImageSource.gallery);
                      if (video != null) {
                        setSheetState(() => pickedVideo = video);
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 56,
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.scaffoldBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.video, color: AppColors.primaryGreen, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Sélectionner une vidéo depuis la galerie',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 14),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final titre = titreController.text.trim();
                            final description = descriptionController.text.trim();

                            if (titre.isEmpty || description.isEmpty) {
                              AppToast.showError('Veuillez remplir le titre et la description.', context);
                              return;
                            }

                            setSheetState(() => isSubmitting = true);

                            final success = await actualiteProvider.saveActualite(
                              id: actualite?.id,
                              titre: titre,
                              description: description,
                              idTheme: selectedThemeId,
                              imagePath: pickedImage?.path,
                              videoPath: pickedVideo?.path,
                            );

                            if (modalCtx.mounted) {
                              Navigator.pop(modalCtx);
                            }

                            if (mounted) {
                              if (success) {
                                AppToast.showSuccess(
                                  isEditing
                                      ? 'Actualité modifiée avec succès !'
                                      : 'Actualité créée avec succès !',
                                  context,
                                );
                              } else {
                                AppToast.showError(
                                  actualiteProvider.errorMessage ?? 'Erreur lors de l\'enregistrement.',
                                  context,
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
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
                            isEditing ? 'Enregistrer les modifications' : 'Publier l\'actualité',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- CONFIRM & TOGGLE ETAT (Identique React changeEtatActualite) ---
  void _handleToggleEtat(ActualiteModel actualite) async {
    final provider = context.read<ActualiteProvider>();
    final isCurrentlyActive = actualite.etat == 1;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isCurrentlyActive ? LucideIcons.eyeOff : LucideIcons.eye,
              color: isCurrentlyActive ? Colors.orange.shade800 : AppColors.primaryGreen,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(isCurrentlyActive ? 'Désactiver l\'actualité' : 'Activer l\'actualité'),
          ],
        ),
        content: Text(
          isCurrentlyActive
              ? 'Voulez-vous masquer cette actualité pour les utilisateurs ?'
              : 'Voulez-vous publier et activer cette actualité ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? Colors.orange.shade800 : AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: Text(isCurrentlyActive ? 'Désactiver' : 'Activer'),
          ),
        ],
      ),
    );

    if (confirm == true && actualite.id != null) {
      final success = await provider.changeEtatActualite(actualite.id!);
      if (mounted) {
        if (success) {
          AppToast.showSuccess(
            isCurrentlyActive ? 'Actualité désactivée avec succès' : 'Actualité activée avec succès',
            context,
          );
        } else {
          AppToast.showError('Échec du changement de statut de l\'actualité.', context);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actualiteProvider = context.watch<ActualiteProvider>();
    final allActualites = actualiteProvider.allActualites;

    // Filter by query and theme
    final filtered = allActualites.where((item) {
      if (_selectedThemeId != null && item.idTheme != _selectedThemeId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final title = (item.titre ?? '').toLowerCase();
        final desc = (item.description ?? '').toLowerCase();
        if (!title.contains(_searchQuery) && !desc.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();

    final activeCount = allActualites.where((a) => a.etat == 1).length;
    final inactiveCount = allActualites.where((a) => a.etat == 0).length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Gestion des Actualités',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: AppColors.forestGreen,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.forestGreen),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.forestGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await actualiteProvider.fetchActualites(forceRefresh: true, isAdmin: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditActualiteSheet(),
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text(
          'Nouvelle actualité',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await actualiteProvider.fetchActualites(forceRefresh: true, isAdmin: true);
          if (context.mounted) {
            AppToast.showSuccess('Données actualisées avec succès', context);
          }
        },
        color: AppColors.primaryGreen,
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
                    colors: [Color(0xFF163820), Color(0xFF2D5A3A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF163820).withValues(alpha: 0.20),
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
                      child: const Icon(LucideIcons.newspaper, color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Actualités & Communiqués',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total: ${allActualites.length}  •  Actives: $activeCount  •  Inactives: $inactiveCount',
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
                  hintText: 'Rechercher une actualité...',
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
                    borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ─── Themes Filter Chips ───
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Tous les thèmes'),
                      selected: _selectedThemeId == null,
                      onSelected: (_) => setState(() => _selectedThemeId = null),
                      selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primaryGreen,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _selectedThemeId == null ? AppColors.forestGreen : AppColors.textSecondary,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _selectedThemeId == null ? AppColors.primaryGreen : Colors.grey.shade300,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...actualiteProvider.themes.map((theme) {
                      final isSelected = _selectedThemeId == theme.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(theme.nom),
                          selected: isSelected,
                          onSelected: (_) => setState(() => _selectedThemeId = isSelected ? null : theme.id),
                          selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                          checkmarkColor: AppColors.primaryGreen,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? AppColors.forestGreen : AppColors.textSecondary,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryGreen : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── List of Actualités ───
              if (actualiteProvider.isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: AppColors.primaryGreen),
                  ),
                ),
              ] else if (filtered.isEmpty) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        Icon(LucideIcons.newspaper, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'Aucune actualité trouvée',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _searchQuery.isNotEmpty || _selectedThemeId != null
                              ? 'Essayez de modifier vos filtres de recherche.'
                              : 'Cliquez sur le bouton pour publier une nouvelle actualité.',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _buildActualiteAdminCard(item);
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

  Widget _buildActualiteAdminCard(ActualiteModel item) {
    final isActive = item.etat == 1;
    final hasImage = item.image != null && item.image!.trim().isNotEmpty;
    final themeName = item.themeNom ?? 'Général';

    String dateStr = '';
    if (item.createdAt != null && item.createdAt!.isNotEmpty) {
      try {
        final parsed = DateTime.parse(item.createdAt!);
        dateStr = DateFormat('dd MMM yyyy, HH:mm', 'fr_FR').format(parsed);
      } catch (_) {
        dateStr = item.createdAt!;
      }
    }

    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper Part: Image + Info
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 72,
                    height: 72,
                    color: Colors.grey.shade100,
                    child: hasImage
                        ? CachedNetworkImage(
                            imageUrl: '${AppConstants.backBaseUrl}uploads/${item.image}',
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(LucideIcons.image, size: 24, color: Colors.grey),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(LucideIcons.imageOff, size: 24, color: Colors.grey),
                            ),
                          )
                        : const Center(
                            child: Icon(LucideIcons.newspaper, color: AppColors.primaryGreen, size: 28),
                          ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text infos
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges Row
                      Row(
                        children: [
                          // Theme badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              themeName,
                              style: const TextStyle(
                                color: Color(0xFF1565C0),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF15803D).withValues(alpha: 0.12)
                                  : Colors.red.withValues(alpha: 0.12),
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
                      const SizedBox(height: 6),

                      // Title
                      Text(
                        item.titre ?? 'Sans titre',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Date
                      if (dateStr.isNotEmpty)
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.borderGray),

          // Actions Bar (Identique aux boutons React: Détails / Modifier / Activer-Désactiver)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Button: Details
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActualiteDetailScreen(
                          actualite: item,
                          themeName: themeName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(LucideIcons.eye, size: 16, color: Color(0xFF1E88E5)),
                  label: const Text(
                    'Détails',
                    style: TextStyle(
                      color: Color(0xFF1E88E5),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Button: Edit
                TextButton.icon(
                  onPressed: () => _showAddEditActualiteSheet(actualite: item),
                  icon: const Icon(LucideIcons.pencil, size: 15, color: Color(0xFFD97706)),
                  label: const Text(
                    'Modifier',
                    style: TextStyle(
                      color: Color(0xFFD97706),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 4),

                // Button: Toggle Etat (Activer / Désactiver)
                TextButton.icon(
                  onPressed: () => _handleToggleEtat(item),
                  icon: Icon(
                    isActive ? LucideIcons.powerOff : LucideIcons.power,
                    size: 15,
                    color: isActive ? Colors.red : const Color(0xFF15803D),
                  ),
                  label: Text(
                    isActive ? 'Désactiver' : 'Activer',
                    style: TextStyle(
                      color: isActive ? Colors.red : const Color(0xFF15803D),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
