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
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';

class AdminAnnoncesScreen extends StatefulWidget {
  const AdminAnnoncesScreen({super.key});

  @override
  State<AdminAnnoncesScreen> createState() => _AdminAnnoncesScreenState();
}

class _AdminAnnoncesScreenState extends State<AdminAnnoncesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String _searchQuery = '';
  int? _selectedThemeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchAnnonces(forceRefresh: true);
      admin.fetchThemes(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── MODAL AJOUTER / MODIFIER UNE ANNONCE (Identique React AjouterAnnonce.jsx) ───
  void _showAddEditAnnonceSheet({Map<String, dynamic>? annonce}) {
    final isEditing = annonce != null;
    final id = isEditing ? int.tryParse(annonce['id']?.toString() ?? '0') ?? 0 : 0;

    final nomController = TextEditingController(
      text: (annonce?['nom'] ?? annonce?['titre'] ?? '').toString(),
    );
    final emailController = TextEditingController(
      text: (annonce?['email'] ?? '').toString(),
    );
    final descController = TextEditingController(
      text: (annonce?['description'] ?? '').toString(),
    );

    String? existingImage = annonce?['image']?.toString();
    File? selectedImageFile;

    DateTime? dateDebut;
    if (annonce?['date_debut'] != null && annonce!['date_debut'].toString().isNotEmpty) {
      dateDebut = DateTime.tryParse(annonce['date_debut'].toString());
    }

    DateTime? dateFin;
    if (annonce?['date_fin'] != null && annonce!['date_fin'].toString().isNotEmpty) {
      dateFin = DateTime.tryParse(annonce['date_fin'].toString());
    }

    int? themeId = int.tryParse(annonce?['id_theme']?.toString() ?? '');

    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final admin = context.watch<AdminProvider>();
          final availableThemes = admin.themes;

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(modalCtx).size.height * 0.90,
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
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
                  // Sheet Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

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
                              isEditing ? LucideIcons.pencil : LucideIcons.briefcase,
                              color: const Color(0xFF00897B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Modifier l\'annonce' : 'Ajouter une annonce',
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
                  const SizedBox(height: 18),

                  // Nom *
                  const Text(
                    'Nom / Titre *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nomController,
                    decoration: InputDecoration(
                      hintText: 'Titre de l\'annonce...',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(LucideIcons.briefcase, size: 18, color: AppColors.textSecondary),
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
                  const SizedBox(height: 14),

                  // Email *
                  const Text(
                    'Email de contact *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'contact@exemple.com',
                      hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                      prefixIcon: const Icon(LucideIcons.mail, size: 18, color: AppColors.textSecondary),
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
                  const SizedBox(height: 14),

                  // Description *
                  const Text(
                    'Description *',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Détails et contenu de l\'annonce...',
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
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Dates: Date Début & Date Fin
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date de début',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dateDebut ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setSheetState(() => dateDebut = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dateDebut != null
                                            ? DateFormat('dd/MM/yyyy').format(dateDebut!)
                                            : 'Sélectionner',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: dateDebut != null ? AppColors.textPrimary : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    if (dateDebut != null)
                                      GestureDetector(
                                        onTap: () => setSheetState(() => dateDebut = null),
                                        child: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Date de fin',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: dateFin ?? DateTime.now().add(const Duration(days: 30)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2035),
                                );
                                if (picked != null) {
                                  setSheetState(() => dateFin = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                                decoration: BoxDecoration(
                                  color: AppColors.scaffoldBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        dateFin != null
                                            ? DateFormat('dd/MM/yyyy').format(dateFin!)
                                            : 'Sélectionner',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: dateFin != null ? AppColors.textPrimary : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    if (dateFin != null)
                                      GestureDetector(
                                        onTap: () => setSheetState(() => dateFin = null),
                                        child: const Icon(LucideIcons.x, size: 14, color: Colors.grey),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Thème dropdown
                  const Text(
                    'Thème',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        value: themeId,
                        isExpanded: true,
                        hint: const Text('Sélectionner un thème', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Aucun thème', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          ),
                          ...availableThemes.map((t) {
                            final tid = int.tryParse(t['id']?.toString() ?? '');
                            final tNom = (t['nom'] ?? t['titre'] ?? 'Thème').toString();
                            return DropdownMenuItem<int?>(
                              value: tid,
                              child: Text(tNom, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                            );
                          }),
                        ],
                        onChanged: (val) => setSheetState(() => themeId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Image Picker
                  const Text(
                    'Image de l\'annonce',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (selectedImageFile != null || (existingImage != null && existingImage!.isNotEmpty)) ...[
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: selectedImageFile != null
                              ? Image.file(
                                  selectedImageFile!,
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: '${AppConstants.backBaseUrl}uploads/$existingImage',
                                  height: 140,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (ctx, url) => Container(
                                    height: 140,
                                    color: Colors.grey.shade100,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (ctx, url, err) => Container(
                                    height: 140,
                                    color: Colors.grey.shade100,
                                    child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.grey)),
                                  ),
                                ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: InkWell(
                            onTap: () {
                              setSheetState(() {
                                selectedImageFile = null;
                                existingImage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(LucideIcons.x, color: Colors.white, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked != null) {
                        setSheetState(() {
                          selectedImageFile = File(picked.path);
                        });
                      }
                    },
                    icon: const Icon(LucideIcons.imagePlus, size: 18),
                    label: Text(
                      selectedImageFile != null || (existingImage != null && existingImage!.isNotEmpty)
                          ? 'Changer l\'image'
                          : 'Ajouter une image',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00897B),
                      side: const BorderSide(color: Color(0xFF00897B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      minimumSize: const Size(double.infinity, 44),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final nom = nomController.text.trim();
                              final email = emailController.text.trim();
                              final desc = descController.text.trim();

                              if (nom.isEmpty) {
                                AppToast.showError('Veuillez saisir le titre de l\'annonce.', context);
                                return;
                              }
                              if (email.isEmpty) {
                                AppToast.showError('Veuillez saisir l\'email de contact.', context);
                                return;
                              }
                              if (desc.isEmpty) {
                                AppToast.showError('Veuillez saisir une description.', context);
                                return;
                              }

                              setSheetState(() => isSubmitting = true);
                              final adminProvider = context.read<AdminProvider>();

                              final dateDebutStr = dateDebut != null ? DateFormat('yyyy-MM-dd').format(dateDebut!) : null;
                              final dateFinStr = dateFin != null ? DateFormat('yyyy-MM-dd').format(dateFin!) : null;

                              final result = await adminProvider.saveAnnonce(
                                id: isEditing ? id : null,
                                nom: nom,
                                email: email,
                                description: desc,
                                imagePath: selectedImageFile?.path,
                                existingImage: existingImage,
                                dateDebut: dateDebutStr,
                                dateFin: dateFinStr,
                                idTheme: themeId,
                              );

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                if (result.success) {
                                  AppToast.showSuccess(result.message, context);
                                } else {
                                  AppToast.showError(result.message, context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEditing ? 'Enregistrer les modifications' : 'Ajouter l\'annonce',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── MODAL DÉTAILS DE L'ANNONCE (Identique React DetailsAnnonce.jsx) ───
  void _showDetailsSheet(Map<String, dynamic> annonce) {
    final nom = (annonce['nom'] ?? annonce['titre'] ?? 'Annonce').toString();
    final email = (annonce['email'] ?? '').toString();
    final desc = (annonce['description'] ?? '').toString();
    final image = annonce['image']?.toString();
    final dateDebut = annonce['date_debut']?.toString();
    final dateFin = annonce['date_fin']?.toString();
    final etat = int.tryParse(annonce['etat']?.toString() ?? '1') ?? 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title & Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      nom,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: etat == 1 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: etat == 1 ? const Color(0xFF81C784) : const Color(0xFFE57373),
                      ),
                    ),
                    child: Text(
                      etat == 1 ? 'Actif' : 'Inactif',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: etat == 1 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Email badge
              if (email.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mail, size: 15, color: Color(0xFF00897B)),
                      const SizedBox(width: 6),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Dates info
              if ((dateDebut != null && dateDebut.isNotEmpty) || (dateFin != null && dateFin.isNotEmpty)) ...[
                Row(
                  children: [
                    const Icon(LucideIcons.calendar, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Période : ${dateDebut != null && dateDebut.isNotEmpty ? dateDebut.split('T').first : '...'} au ${dateFin != null && dateFin.isNotEmpty ? dateFin.split('T').first : '...'}',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Image
              if (image != null && image.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: '${AppConstants.backBaseUrl}uploads/$image',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (c, url) => Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (c, url, err) => Container(
                      height: 200,
                      color: Colors.grey.shade100,
                      child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.grey)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  desc.isNotEmpty ? desc : 'Aucune description fournie.',
                  style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons inside Details
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddEditAnnonceSheet(annonce: annonce);
                      },
                      icon: const Icon(LucideIcons.pencil, size: 16),
                      label: const Text('Modifier'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF00897B),
                        side: const BorderSide(color: Color(0xFF00897B)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── CONFIRMATION SUPPRESSION ───
  void _confirmDelete(Map<String, dynamic> annonce) {
    final id = int.tryParse(annonce['id']?.toString() ?? '0') ?? 0;
    final nom = (annonce['nom'] ?? annonce['titre'] ?? 'cette annonce').toString();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.triangleAlert, color: Colors.red, size: 22),
            SizedBox(width: 8),
            Text('Confirmation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: Text('Voulez-vous vraiment supprimer l\'annonce "$nom" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final adminProvider = context.read<AdminProvider>();
              final success = await adminProvider.deleteAnnonce(id);
              if (mounted) {
                if (success) {
                  AppToast.showSuccess('Annonce supprimée avec succès', context);
                } else {
                  AppToast.showError('Erreur lors de la suppression', context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminProvider>();
    final allAnnonces = admin.annonces;
    final themes = admin.themes;

    // Filter annonces based on search query & selected theme
    final filteredAnnonces = allAnnonces.where((a) {
      final nom = (a['nom'] ?? a['titre'] ?? '').toString().toLowerCase();
      final email = (a['email'] ?? '').toString().toLowerCase();
      final desc = (a['description'] ?? '').toString().toLowerCase();
      final themeId = int.tryParse(a['id_theme']?.toString() ?? '');

      final matchesQuery = _searchQuery.isEmpty ||
          nom.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          desc.contains(_searchQuery);

      final matchesTheme = _selectedThemeId == null || themeId == _selectedThemeId;

      return matchesQuery && matchesTheme;
    }).toList();

    // Stats
    final totalCount = allAnnonces.length;
    final activeCount = allAnnonces.where((a) => (a['etat'] == 1 || a['etat']?.toString() == '1')).length;
    final inactiveCount = totalCount - activeCount;

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
          'Gestion des Annonces',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF00897B), size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchAnnonces(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditAnnonceSheet(),
        backgroundColor: const Color(0xFF00897B),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // Top Stats Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00897B), Color(0xFF004D40)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', totalCount.toString(), LucideIcons.briefcase),
                Container(width: 1, height: 32, color: Colors.white24),
                _buildStatItem('Actives', activeCount.toString(), LucideIcons.circleCheck, color: const Color(0xFF81C784)),
                Container(width: 1, height: 32, color: Colors.white24),
                _buildStatItem('Inactives', inactiveCount.toString(), LucideIcons.circleX, color: const Color(0xFFFF8A80)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Rechercher une annonce par titre, email...',
                hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 16, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
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
          ),

          // Theme Filter Chips (if themes exist)
          if (themes.isNotEmpty)
            Container(
              height: 38,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: const Text('Tous'),
                    selected: _selectedThemeId == null,
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedThemeId = null);
                    },
                    selectedColor: const Color(0xFF00897B),
                    labelStyle: TextStyle(
                      color: _selectedThemeId == null ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                  const SizedBox(width: 8),
                  ...themes.map((t) {
                    final tid = int.tryParse(t['id']?.toString() ?? '');
                    final isSelected = _selectedThemeId == tid;
                    final tNom = (t['nom'] ?? t['titre'] ?? 'Thème').toString();

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(tNom),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() => _selectedThemeId = selected ? tid : null);
                        },
                        selectedColor: const Color(0xFF00897B),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        showCheckmark: false,
                      ),
                    );
                  }),
                ],
              ),
            ),

          // Annonces List
          Expanded(
            child: admin.isLoading && allAnnonces.isEmpty
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
                : filteredAnnonces.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.briefcase, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty || _selectedThemeId != null
                                  ? 'Aucun résultat trouvé'
                                  : 'Aucune annonce enregistrée',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _showAddEditAnnonceSheet(),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Ajouter une annonce'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF00897B),
                                side: const BorderSide(color: Color(0xFF00897B)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          await admin.fetchAnnonces(forceRefresh: true);
                          if (context.mounted) {
                            AppToast.showSuccess('Données actualisées avec succès', context);
                          }
                        },
                        color: const Color(0xFF00897B),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 80),
                          itemCount: filteredAnnonces.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final a = filteredAnnonces[idx];
                            final id = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
                            final titre = (a['nom'] ?? a['titre'] ?? 'Annonce').toString();
                            final email = (a['email'] ?? '').toString();
                            final desc = (a['description'] ?? '').toString();
                            final image = a['image']?.toString();
                            final etat = int.tryParse(a['etat']?.toString() ?? '1') ?? 1;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
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
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Image Thumbnail or Icon
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: image != null && image.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: '${AppConstants.backBaseUrl}uploads/$image',
                                                width: 56,
                                                height: 56,
                                                fit: BoxFit.cover,
                                                placeholder: (c, u) => Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                                ),
                                                errorWidget: (c, u, e) => Container(
                                                  width: 56,
                                                  height: 56,
                                                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                                  child: const Icon(LucideIcons.briefcase, color: Color(0xFF00897B), size: 24),
                                                ),
                                              )
                                            : Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(LucideIcons.briefcase, color: Color(0xFF00897B), size: 24),
                                              ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Titre + Email + State Badge
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    titre,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ),
                                                // State Badge
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: etat == 1
                                                        ? const Color(0xFFE8F5E9)
                                                        : const Color(0xFFFFEBEE),
                                                    borderRadius: BorderRadius.circular(12),
                                                    border: Border.all(
                                                      color: etat == 1
                                                          ? const Color(0xFF81C784)
                                                          : const Color(0xFFE57373),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    etat == 1 ? 'Actif' : 'Inactif',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: etat == 1
                                                          ? const Color(0xFF2E7D32)
                                                          : const Color(0xFFC62828),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            if (email.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(LucideIcons.mail, size: 12, color: AppColors.textSecondary),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      email,
                                                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  if (desc.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      desc,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                                    ),
                                  ],

                                  const SizedBox(height: 10),
                                  const Divider(height: 1, thickness: 0.8, color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 8),

                                  // Actions Bar (Détails, Modifier, Activer/Désactiver, Supprimer)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Bouton Détails
                                      InkWell(
                                        onTap: () => _showDetailsSheet(a),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(LucideIcons.eye, size: 14, color: Colors.blue),
                                              SizedBox(width: 4),
                                              Text('Détails', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Bouton Modifier
                                      InkWell(
                                        onTap: () => _showAddEditAnnonceSheet(annonce: a),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(LucideIcons.pencil, size: 14, color: Color(0xFFD97706)),
                                              SizedBox(width: 4),
                                              Text('Modifier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Bouton Activer / Désactiver
                                      InkWell(
                                        onTap: () async {
                                          final result = await admin.changeEtatAnnonce(id, etat);
                                          if (context.mounted) {
                                            if (result.success) {
                                              AppToast.showSuccess(result.message, context);
                                            } else {
                                              AppToast.showError(result.message, context);
                                            }
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: etat == 1
                                                ? Colors.red.withValues(alpha: 0.1)
                                                : Colors.green.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                etat == 1 ? LucideIcons.circleX : LucideIcons.circleCheck,
                                                size: 14,
                                                color: etat == 1 ? Colors.red : Colors.green,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                etat == 1 ? 'Désactiver' : 'Activer',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: etat == 1 ? Colors.red : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),

                                      // Bouton Supprimer
                                      InkWell(
                                        onTap: () => _confirmDelete(a),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(LucideIcons.trash2, size: 14, color: Colors.grey),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white70, size: 18),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
