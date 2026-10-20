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
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/conge_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';

class ListCongeScreen extends StatefulWidget {
  const ListCongeScreen({super.key});

  @override
  State<ListCongeScreen> createState() => _ListCongeScreenState();
}

class _ListCongeScreenState extends State<ListCongeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CongeProvider>().fetchConges();
    });
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.homePharmacien, (r) => false);
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

  void _showAddEditCongeModal({CongeItem? existingItem}) {
    final isEditMode = existingItem != null;
    DateTime? selectedStart = existingItem != null && existingItem.dateDebut.isNotEmpty
        ? DateTime.tryParse(existingItem.dateDebut)
        : null;
    DateTime? selectedEnd = existingItem != null && existingItem.dateFin.isNotEmpty
        ? DateTime.tryParse(existingItem.dateFin)
        : null;
    int selectedType = existingItem?.typeConge ?? 1; // 1: Fermeture, 2: Remplacement
    final descController = TextEditingController(text: existingItem?.description ?? '');
    final cnoptController = TextEditingController(text: existingItem?.numCnopt ?? '');
    String? existingImage = existingItem?.image;
    File? selectedImageFile;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              top: 14,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditMode ? 'Modifier la demande' : 'Nouvelle demande de congé',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF163820),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isEditMode ? 'Modifiez les informations ci-dessous' : 'Remplissez les informations ci-dessous',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        icon: const Icon(LucideIcons.x, color: Color(0xFF64748B)),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Type de congé (Fermeture ou Remplacement)
                  const Text(
                    'TYPE DE CONGÉ *',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Fermeture
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedType = 1),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: selectedType == 1 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedType == 1 ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                                width: selectedType == 1 ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.doorClosed,
                                  size: 18,
                                  color: selectedType == 1 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fermeture',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: selectedType == 1 ? FontWeight.w800 : FontWeight.w600,
                                    color: selectedType == 1 ? const Color(0xFF15803D) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Remplacement
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => selectedType = 2),
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                            decoration: BoxDecoration(
                              color: selectedType == 2 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selectedType == 2 ? const Color(0xFF22C55E) : const Color(0xFFE2E8F0),
                                width: selectedType == 2 ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  LucideIcons.userCheck,
                                  size: 18,
                                  color: selectedType == 2 ? const Color(0xFF15803D) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Remplacement',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: selectedType == 2 ? FontWeight.w800 : FontWeight.w600,
                                    color: selectedType == 2 ? const Color(0xFF15803D) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Si Remplacement, Numéro CNOPT obligatoire
                  if (selectedType == 2) ...[
                    const SizedBox(height: 14),
                    const Row(
                      children: [
                        Text(
                          'NUMÉRO CNOPT DU REMPLAÇANT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: cnoptController,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.badgeCheck, size: 18, color: Color(0xFF71A246)),
                          hintText: 'Saisir le numéro CNOPT (ex: 12345)',
                          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Dates Row
                  Row(
                    children: [
                      // Date début
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DATE DÉBUT *',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedStart ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() {
                                    selectedStart = picked;
                                    if (selectedEnd != null && selectedEnd!.isBefore(picked)) {
                                      selectedEnd = picked;
                                    }
                                  });
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 16, color: Color(0xFF71A246)),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedStart != null ? DateFormat('dd/MM/yyyy').format(selectedStart!) : 'Choisir',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selectedStart != null ? const Color(0xFF163820) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Date fin
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'DATE FIN *',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedEnd ?? (selectedStart ?? DateTime.now()),
                                  firstDate: selectedStart ?? DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (picked != null) {
                                  setModalState(() => selectedEnd = picked);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendarCheck, size: 16, color: Color(0xFF71A246)),
                                    const SizedBox(width: 8),
                                    Text(
                                      selectedEnd != null ? DateFormat('dd/MM/yyyy').format(selectedEnd!) : 'Choisir',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selectedEnd != null ? const Color(0xFF163820) : const Color(0xFF94A3B8),
                                      ),
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

                  // Motif / Description
                  const Text(
                    'MOTIF / DESCRIPTION (OPTIONNEL)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: TextField(
                      controller: descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Précisez le motif de votre demande...',
                        hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        contentPadding: EdgeInsets.all(14),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Pièce jointe / Justificatif
                  const Text(
                    'PIÈCE JOINTE / JUSTIFICATIF (OPTIONNEL)',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
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
                                  height: 130,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: '${AppConstants.backBaseUrl}uploads/$existingImage',
                                  height: 130,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                    height: 130,
                                    color: Colors.grey.shade100,
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  ),
                                  errorWidget: (_, __, ___) => Container(
                                    height: 130,
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
                              setModalState(() {
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
                  InkWell(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                      if (picked != null) {
                        setModalState(() {
                          selectedImageFile = File(picked.path);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(LucideIcons.imagePlus, size: 18, color: Color(0xFF71A246)),
                          const SizedBox(width: 8),
                          Text(
                            selectedImageFile != null || (existingImage != null && existingImage!.isNotEmpty)
                                ? 'Changer l\'image jointe'
                                : 'Joindre un justificatif ou photo',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF163820)),
                          ),
                        ],
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
                              if (selectedStart == null || selectedEnd == null) {
                                AppToast.showInfo('Veuillez sélectionner les dates de début et de fin.', context);
                                return;
                              }

                              if (selectedEnd!.isBefore(selectedStart!)) {
                                AppToast.showError('La date de fin doit être supérieure ou égale à la date de début.', context);
                                return;
                              }

                              if (selectedType == 2 && cnoptController.text.trim().isEmpty) {
                                AppToast.showError('Le numéro CNOPT est obligatoire pour un remplacement.', context);
                                return;
                              }

                              setModalState(() => isSubmitting = true);

                              final startStr = DateFormat('yyyy-MM-dd').format(selectedStart!);
                              final endStr = DateFormat('yyyy-MM-dd').format(selectedEnd!);

                              final provider = context.read<CongeProvider>();
                              String? finalImage = existingImage;
                              if (selectedImageFile != null) {
                                final uploaded = await provider.uploadCongeImage(selectedImageFile!.path);
                                if (uploaded != null) {
                                  finalImage = uploaded;
                                }
                              }

                              final bool ok;
                              if (isEditMode) {
                                ok = await provider.updateConge(
                                  id: existingItem.id,
                                  dateDebut: startStr,
                                  dateFin: endStr,
                                  description: descController.text.trim(),
                                  typeConge: selectedType,
                                  numCnopt: selectedType == 2 ? cnoptController.text.trim() : null,
                                  image: finalImage,
                                );
                              } else {
                                ok = await provider.addConge(
                                  dateDebut: startStr,
                                  dateFin: endStr,
                                  description: descController.text.trim(),
                                  typeConge: selectedType,
                                  numCnopt: selectedType == 2 ? cnoptController.text.trim() : null,
                                  image: finalImage,
                                );
                              }

                              if (modalCtx.mounted) {
                                Navigator.pop(modalCtx);
                              }
                              if (mounted) {
                                setModalState(() => isSubmitting = false);
                                if (ok) {
                                  AppToast.showSuccess(
                                    isEditMode
                                        ? 'Demande de congé modifiée avec succès !'
                                        : 'Demande de congé transmise avec succès !',
                                    context,
                                  );
                                } else {
                                  AppToast.showError('Erreur lors de l\'enregistrement de la demande.', context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF71A246),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: isSubmitting
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              isEditMode ? 'Enregistrer les modifications' : 'Envoyer la demande',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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

  void _showAddCongeModal() => _showAddEditCongeModal();

  void _showCongeDetailsModal(CongeItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(top: 14, left: 20, right: 20, bottom: 26),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
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
                          color: const Color(0xFF71A246).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          item.typeConge == 2 ? LucideIcons.userCheck : LucideIcons.doorClosed,
                          color: const Color(0xFF71A246),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.typeLabel,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                          ),
                          const SizedBox(height: 2),
                          const Text('Détails de la demande', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: item.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: item.statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      item.statusLabel,
                      style: TextStyle(color: item.statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Dates
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DATE DÉBUT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            item.dateDebut,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF163820)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('DATE FIN', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            item.dateFin,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF163820)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Remplacement CNOPT
              if (item.typeConge == 2 && item.numCnopt != null && item.numCnopt!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.badgeCheck, size: 20, color: Color(0xFF15803D)),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NUMÉRO CNOPT REMPLAÇANT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                          const SizedBox(height: 2),
                          Text(
                            item.numCnopt!,
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF163820)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // Description
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('DESCRIPTION / MOTIF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    item.description!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4),
                  ),
                ),
              ],

              // Document joint / Image
              if (item.image != null && item.image!.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('DOCUMENT JOINT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B))),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CachedNetworkImage(
                    imageUrl: '${AppConstants.backBaseUrl}uploads/${item.image}',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 180,
                      color: Colors.grey.shade100,
                      child: const Center(child: Icon(LucideIcons.imageOff, color: Colors.grey)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (item.status == 0) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showAddEditCongeModal(existingItem: item);
                        },
                        icon: const Icon(LucideIcons.pencil, size: 15),
                        label: const Text('Modifier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(CongeItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la demande', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette demande de congé ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Non', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<CongeProvider>().deleteConge(item.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();
    final congeProvider = context.watch<CongeProvider>();
    final conges = congeProvider.conges;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: RefreshIndicator(
        color: const Color(0xFF22C55E),
        onRefresh: () async {
          await congeProvider.fetchConges(forceRefresh: true);
          if (context.mounted) {
            AppToast.showSuccess('Données actualisées avec succès', context);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // ─── HERO HEADER (Identique ListConge.jsx) ───
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  image: DecorationImage(
                    image: AssetImage('assets/images/back-mobile.png'),
                    repeat: ImageRepeat.repeat,
                    opacity: 0.16,
                    scale: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xD9FFFFFF),
                              Color(0xC4F0F8EB),
                              Color(0x2871A246),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: topPadding + 14, bottom: 26, left: 18, right: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Top Bar: Back & Refresh Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: const Color(0xFF70BA8E), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.undo2, size: 15, color: Color(0xFF22C55E)),
                                      SizedBox(width: 6),
                                      Text(
                                        'Retour',
                                        style: TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Refresh Button
                              InkWell(
                                onTap: () async {
                                  await congeProvider.fetchConges(forceRefresh: true);
                                  if (context.mounted) {
                                    AppToast.showSuccess('Données actualisées avec succès', context);
                                  }
                                },
                                borderRadius: BorderRadius.circular(30),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: const Color(0xFF70BA8E), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(LucideIcons.refreshCw, size: 14, color: Color(0xFF22C55E)),
                                      SizedBox(width: 5),
                                      Text(
                                        'Actualiser',
                                        style: TextStyle(
                                          color: Color(0xFF22C55E),
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),

                        // Green Calendar Icon
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF71A246), Color(0xFF558332)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF71A246).withValues(alpha: 0.40),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.calendarCheck, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text(
                          'Congés',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF163820),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Consultez et gérez vos demandes de congés',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B6A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 22),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── MAIN CONGÉS CARD ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Card Header: LISTE DES CONGÉS + Ajouter Button
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(LucideIcons.calendarDays, size: 18, color: Color(0xFF71A246)),
                              SizedBox(width: 8),
                              Text(
                                'LISTE DES CONGÉS',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF163820),
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                          InkWell(
                            onTap: _showAddCongeModal,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF22C55E).withValues(alpha: 0.30),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.plus, size: 15, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text(
                                    'Ajouter',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Card Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: congeProvider.isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(color: Color(0xFF71A246), strokeWidth: 3),
                                    SizedBox(height: 12),
                                    Text('Chargement des congés...', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                                  ],
                                ),
                              ),
                            )
                          : conges.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF1F5F9),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(LucideIcons.calendarX, size: 28, color: Color(0xFF94A3B8)),
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Aucun congé trouvé',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF163820),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Appuyez sur "+ Ajouter" pour créer une nouvelle demande.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: conges.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (ctx, i) {
                                    final item = conges[i];

                                    return InkWell(
                                      onTap: () => _showCongeDetailsModal(item),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF9FAFB),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.02),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Title & Status Badge
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF71A246).withValues(alpha: 0.12),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Icon(
                                                        item.typeConge == 2 ? LucideIcons.userCheck : LucideIcons.doorClosed,
                                                        size: 15,
                                                        color: const Color(0xFF71A246),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      item.typeLabel,
                                                      style: const TextStyle(
                                                        fontSize: 14.5,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF163820),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: item.statusColor.withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: item.statusColor.withValues(alpha: 0.3)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        item.status == 1
                                                            ? LucideIcons.checkCircle2
                                                            : (item.status == 2 ? LucideIcons.xCircle : LucideIcons.clock),
                                                        size: 12,
                                                        color: item.statusColor,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        item.statusLabel,
                                                        style: TextStyle(
                                                          color: item.statusColor,
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),

                                            // Dates Row
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 6,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Icon(LucideIcons.calendar, size: 13, color: Color(0xFF71A246)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        'Du ${item.dateDebut} au ${item.dateFin}',
                                                        style: const TextStyle(
                                                          fontSize: 12.5,
                                                          color: Color(0xFF4B5563),
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (item.typeConge == 2 && item.numCnopt != null && item.numCnopt!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF0FDF4),
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(LucideIcons.badgeCheck, size: 13, color: Color(0xFF15803D)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          'CNOPT: ${item.numCnopt}',
                                                          style: const TextStyle(
                                                            fontSize: 12,
                                                            color: Color(0xFF15803D),
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (item.image != null && item.image!.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: const Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(LucideIcons.paperclip, size: 12, color: Color(0xFF64748B)),
                                                        SizedBox(width: 4),
                                                        Text(
                                                          'Pièce jointe',
                                                          style: TextStyle(
                                                            fontSize: 11.5,
                                                            color: Color(0xFF64748B),
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),

                                            if (item.description != null && item.description!.isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                item.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                            ],

                                            // Action Buttons
                                            const SizedBox(height: 10),
                                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                InkWell(
                                                  onTap: () => _showCongeDetailsModal(item),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: const Padding(
                                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(LucideIcons.eye, size: 14, color: Color(0xFF2563EB)),
                                                        SizedBox(width: 5),
                                                        Text(
                                                          'Détails',
                                                          style: TextStyle(color: Color(0xFF2563EB), fontSize: 12.5, fontWeight: FontWeight.w700),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                if (item.status == 0)
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      InkWell(
                                                        onTap: () => _showAddEditCongeModal(existingItem: item),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(LucideIcons.pencil, size: 14, color: Color(0xFFD97706)),
                                                              SizedBox(width: 4),
                                                              Text(
                                                                'Modifier',
                                                                style: TextStyle(color: Color(0xFFD97706), fontSize: 12.5, fontWeight: FontWeight.w700),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      InkWell(
                                                        onTap: () => _showDeleteDialog(item),
                                                        borderRadius: BorderRadius.circular(8),
                                                        child: const Padding(
                                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Icon(LucideIcons.trash2, size: 14, color: Color(0xFFEF4444)),
                                                              SizedBox(width: 4),
                                                              Text(
                                                                'Annuler',
                                                                style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5, fontWeight: FontWeight.w700),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ).animate().fadeIn(duration: 300.ms, delay: Duration(milliseconds: i * 60)).slideY(begin: 0.05, end: 0);
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }
}
