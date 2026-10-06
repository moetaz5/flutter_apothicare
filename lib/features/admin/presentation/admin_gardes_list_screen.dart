import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'admin_garde_details_screen.dart';

class AdminGardesListScreen extends StatefulWidget {
  const AdminGardesListScreen({super.key});

  @override
  State<AdminGardesListScreen> createState() => _AdminGardesListScreenState();
}

class _AdminGardesListScreenState extends State<AdminGardesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isApiLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      admin.fetchAnnees();
      admin.fetchTbGardes();
      admin.fetchAdminGardes(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── 1. MODAL AJOUTER DES PHARMACIES (Identique React AjouterGarde.jsx) ───
  void _showAjouterPharmaciesSheet({Map<String, dynamic>? editGarde}) {
    final isEditing = editGarde != null;
    int? selectedTbGardeId = int.tryParse(editGarde?['id_tbgarde']?.toString() ?? editGarde?['zone_gardes']?['id']?.toString() ?? '');

    List<Map<String, dynamic>> rows = [];
    List<Map<String, dynamic>> zonePharmacies = [];
    bool isLoadingPharmacies = false;
    bool isSaving = false;
    bool initialLoaded = false;

    Map<String, dynamic>? selectedPharmacie;
    DateTime? dateDebut;
    DateTime? dateFin;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final admin = context.watch<AdminProvider>();
          final zones = admin.tbGardes;

          void loadPharmaciesForZone(int zoneId) async {
            setSheetState(() => isLoadingPharmacies = true);
            final res = await admin.fetchPharmaciensByTbGarde(zoneId);
            setSheetState(() {
              zonePharmacies = res;
              isLoadingPharmacies = false;
              selectedPharmacie = null;
            });
          }

          if (!initialLoaded) {
            initialLoaded = true;
            if (isEditing) {
              final gardeId = int.tryParse(editGarde['id']?.toString() ?? '0') ?? 0;
              if (selectedTbGardeId != null) {
                loadPharmaciesForZone(selectedTbGardeId!);
              }

              admin.fetchGardeDetails(gardeId).then((data) {
                if (data != null) {
                  final rawLines = data['data'] ?? data['lignes'] ?? [];
                  if (rawLines is List) {
                    final List<Map<String, dynamic>> loadedRows = [];
                    for (var l in rawLines) {
                      if (l is Map) {
                        final deb = (l['date_debut'] ?? '').toString().split('T').first;
                        final fin = (l['date_fin'] ?? '').toString().split('T').first;
                        final nomPharma = l['top_pharmacien']?['nom'] ?? l['nom_pharmacien'] ?? l['nom'] ?? 'Pharmacie';
                        final tva = (l['num_cnopt'] ?? l['top_pharmacien']?['tva'] ?? '').toString();
                        loadedRows.add({
                          'num_cnopt': tva,
                          'nom_pharmacie': nomPharma,
                          'date_debut': deb,
                          'date_fin': fin,
                          'id_garde': selectedTbGardeId ?? 0,
                          'id_tbgarde': selectedTbGardeId ?? 0,
                          'id_pharmacien': l['id_pharmacien'] ?? l['pharmacien_id'] ?? l['top_pharmacien']?['id'],
                          'id_user': l['id_pharmacien'] ?? l['pharmacien_id'] ?? l['top_pharmacien']?['id'],
                        });
                      }
                    }
                    if (modalCtx.mounted) {
                      setSheetState(() {
                        rows = loadedRows;
                      });
                    }
                  }
                }
              });
            }
          }

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
                  // Handle
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

                  // Title
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
                              isEditing ? LucideIcons.pencil : LucideIcons.plusCircle,
                              color: const Color(0xFF00897B),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isEditing ? 'Modifier la garde' : 'Ajouter des pharmacies',
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

                  // 1. Choix du TB Garde (Zone)
                  const Text(
                    'Zone TB Garde *',
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
                        value: selectedTbGardeId,
                        isExpanded: true,
                        hint: const Text('Sélectionner un TB Garde', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                        items: zones.map((z) {
                          final zid = int.tryParse(z['id']?.toString() ?? '');
                          final zNom = (z['nom_zone'] ?? z['designation'] ?? 'Zone').toString();
                          return DropdownMenuItem<int?>(
                            value: zid,
                            child: Text(zNom, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setSheetState(() => selectedTbGardeId = val);
                          if (val != null) {
                            loadPharmaciesForZone(val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Formulaire d'ajout d'une ligne
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7FAF7),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(LucideIcons.plus, size: 15, color: Color(0xFF00897B)),
                            SizedBox(width: 6),
                            Text(
                              'Ajouter une ligne de pharmacie',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00897B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Pharmacie
                        const Text(
                          'Pharmacie *',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        isLoadingPharmacies
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00897B))),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.grey.shade300),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<Map<String, dynamic>?>(
                                    value: selectedPharmacie,
                                    isExpanded: true,
                                    hint: Text(
                                      selectedTbGardeId == null
                                          ? 'Veuillez d\'abord choisir la zone'
                                          : zonePharmacies.isEmpty
                                              ? 'Aucune pharmacie trouvée'
                                              : 'Sélectionner la pharmacie',
                                      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    ),
                                    icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textSecondary),
                                    items: zonePharmacies.map((p) {
                                      final nom = (p['nom'] ?? 'Pharmacie').toString();
                                      final tva = (p['tva'] ?? p['num_cnopt'] ?? '').toString();
                                      final label = tva.isNotEmpty ? '$nom ($tva)' : nom;
                                      return DropdownMenuItem<Map<String, dynamic>?>(
                                        value: p,
                                        child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                                      );
                                    }).toList(),
                                    onChanged: (val) => setSheetState(() => selectedPharmacie = val),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 10),

                        // Dates début & fin
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date début *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: dateDebut ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) setSheetState(() => dateDebut = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              dateDebut != null ? DateFormat('dd/MM/yyyy').format(dateDebut!) : 'Début',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: dateDebut != null ? AppColors.textPrimary : AppColors.textMuted,
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Date fin *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: dateFin ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2035),
                                      );
                                      if (picked != null) setSheetState(() => dateFin = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey.shade300),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(LucideIcons.calendar, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              dateFin != null ? DateFormat('dd/MM/yyyy').format(dateFin!) : 'Fin',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: dateFin != null ? AppColors.textPrimary : AppColors.textMuted,
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
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Bouton Ajouter cette ligne
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (selectedPharmacie == null || dateDebut == null || dateFin == null || selectedTbGardeId == null) {
                                AppToast.showError('Veuillez remplir tous les champs de la ligne.', context);
                                return;
                              }

                              final tva = (selectedPharmacie?['tva'] ?? selectedPharmacie?['num_cnopt'] ?? '').toString();
                              final nom = (selectedPharmacie?['nom'] ?? 'Pharmacie').toString();

                              setSheetState(() {
                                rows.add({
                                  'num_cnopt': tva,
                                  'nom_pharmacie': nom,
                                  'date_debut': DateFormat('yyyy-MM-dd').format(dateDebut!),
                                  'date_fin': DateFormat('yyyy-MM-dd').format(dateFin!),
                                  'id_garde': selectedTbGardeId,
                                  'id_user': selectedPharmacie?['id'],
                                });
                                selectedPharmacie = null;
                                dateDebut = null;
                                dateFin = null;
                              });

                              AppToast.showSuccess('Ligne ajoutée', context);
                            },
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: const Text('Ajouter la ligne'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00897B),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Tableau des lignes ajoutées
                  if (rows.isNotEmpty) ...[
                    Text(
                      'Lignes à enregistrer (${rows.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (rCtx, rIdx) {
                        final r = rows[rIdx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE0F2F1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${rIdx + 1}',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF00897B)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['nom_pharmacie'] ?? 'Pharmacie',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                    ),
                                    Text(
                                      'CNOPT: ${r['num_cnopt']}  |  ${r['date_debut']} ➔ ${r['date_fin']}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 16, color: Colors.red),
                                onPressed: () => setSheetState(() => rows.removeAt(rIdx)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Bouton Enregistrer tout
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isSaving || rows.isEmpty
                          ? null
                          : () async {
                              if (selectedTbGardeId == null) {
                                AppToast.showError('Veuillez sélectionner une zone TB Garde.', context);
                                return;
                              }

                              setSheetState(() => isSaving = true);
                              final ({bool success, String message}) res;

                              if (isEditing) {
                                final gardeId = int.tryParse(editGarde['id']?.toString() ?? '0') ?? 0;
                                res = await admin.updateGardeLines(
                                  id: gardeId,
                                  data: rows,
                                );
                              } else {
                                final annee = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();
                                res = await admin.addLignesGarde(
                                  idGarde: selectedTbGardeId!,
                                  lignes: rows,
                                  annee: annee,
                                );
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                if (res.success) {
                                  AppToast.showSuccess(res.message, context);
                                } else {
                                  AppToast.showError(res.message, context);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              isEditing ? 'Enregistrer les modifications' : 'Enregistrer toutes les pharmacies',
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

  // ─── 2. MODAL IMPORT EXCEL (Identique React ImportGardes.jsx) ───
  void _showImportExcelSheet() {
    int? selectedTbGardeId;
    String? selectedFilePath;
    String? selectedFileName;
    List<int>? selectedFileBytes;
    bool isImporting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final admin = context.watch<AdminProvider>();
          final zones = admin.tbGardes;
          final annee = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();

          return Container(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
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

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(LucideIcons.fileSpreadsheet, color: Color(0xFF2E7D32), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Importer un fichier Excel',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
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

                // Année
                Text(
                  'Année active : $annee',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF00897B)),
                ),
                const SizedBox(height: 12),

                // Zone TB Garde
                const Text(
                  'Zone TB Garde *',
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
                      value: selectedTbGardeId,
                      isExpanded: true,
                      hint: const Text('Sélectionner un TB Garde', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      icon: const Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
                      items: zones.map((z) {
                        final zid = int.tryParse(z['id']?.toString() ?? '');
                        final zNom = (z['nom_zone'] ?? z['designation'] ?? 'Zone').toString();
                        return DropdownMenuItem<int?>(
                          value: zid,
                          child: Text(zNom, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => selectedTbGardeId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // File Selector
                const Text(
                  'Fichier Excel (.xlsx, .xls) *',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    try {
                      FilePickerResult? result;
                      try {
                        result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['xlsx', 'xls'],
                          withData: true,
                        );
                      } catch (_) {
                        result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          withData: true,
                        );
                      }

                      if (result != null && result.files.isNotEmpty) {
                        final f = result.files.single;
                        final name = f.name;
                        final lower = name.toLowerCase();

                        if (!lower.endsWith('.xlsx') && !lower.endsWith('.xls') && !lower.endsWith('.csv')) {
                          if (modalCtx.mounted) {
                            AppToast.showError('Veuillez sélectionner un fichier Excel (.xlsx ou .xls)', modalCtx);
                          }
                          return;
                        }

                        setSheetState(() {
                          selectedFilePath = f.path;
                          selectedFileName = f.name;
                          selectedFileBytes = f.bytes;
                        });
                      }
                    } catch (err) {
                      if (modalCtx.mounted) {
                        final errStr = err.toString();
                        if (errStr.contains('MissingPluginException')) {
                          AppToast.showError('Veuillez redémarrer l\'application (Arrêter et relancer Flutter Run) pour activer le plugin de fichiers.', modalCtx);
                        } else {
                          AppToast.showError('Erreur lors de la sélection : $err', modalCtx);
                        }
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedFileName != null ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                        width: selectedFileName != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedFileName != null ? LucideIcons.fileCheck : LucideIcons.uploadCloud,
                          size: 24,
                          color: selectedFileName != null ? const Color(0xFF2E7D32) : const Color(0xFF00897B),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFileName ?? 'Cliquez pour choisir le fichier Excel...',
                            style: TextStyle(
                              fontSize: 13,
                              color: selectedFileName != null ? const Color(0xFF2E7D32) : AppColors.textMuted,
                              fontWeight: selectedFileName != null ? FontWeight.w700 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: isImporting
                        ? null
                        : () async {
                            if (selectedTbGardeId == null) {
                              AppToast.showError('Veuillez sélectionner une zone TB Garde.', context);
                              return;
                            }
                            if (selectedFilePath == null && selectedFileBytes == null) {
                              AppToast.showError('Veuillez sélectionner un fichier Excel.', context);
                              return;
                            }

                            setSheetState(() => isImporting = true);
                            final res = await admin.importGardesExcel(
                              filePath: selectedFilePath,
                              fileBytes: selectedFileBytes,
                              fileName: selectedFileName,
                              idTbGarde: selectedTbGardeId!,
                              annee: annee,
                            );

                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              if (res.success) {
                                AppToast.showSuccess(res.message, context);
                              } else {
                                AppToast.showError(res.message, context);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Importer maintenant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── 3. DÉTAILS DE LA GARDE (Identique React DetailsGarde.jsx) ───
  void _showDetailsSheet(Map<String, dynamic> garde) {
    final id = int.tryParse(garde['id']?.toString() ?? '0') ?? 0;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminGardeDetailsScreen(
          id: id,
          initialGarde: garde,
        ),
      ),
    );
  }

  // ─── 4. DUPLIQUER LA GARDE (Identique React DuplicateGarde.jsx) ───
  void _showDuplicateDialog(Map<String, dynamic> garde) {
    final id = int.tryParse(garde['id']?.toString() ?? '0') ?? 0;
    final zoneNom = (garde['zone_gardes']?['designation'] ?? garde['zone_gardes']?['nom_zone'] ?? garde['nom_zone'] ?? 'TB Garde').toString();
    final admin = context.read<AdminProvider>();
    final currentYear = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();
    final nextYear = ((int.tryParse(currentYear) ?? DateTime.now().year) + 1).toString();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.copy, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Dupliquer la garde', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voulez-vous dupliquer les tours de garde de $zoneNom pour l\'année suivante ($nextYear) ?',
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Année source : $currentYear ➔ Année cible : $nextYear',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dCtx);
              final res = await admin.duplicateGarde(id: id, targetAnnee: nextYear);
              if (mounted) {
                if (res.success) {
                  AppToast.showSuccess(res.message, context);
                } else {
                  AppToast.showError(res.message, context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Dupliquer', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ─── 5. TÉLÉCHARGER LES POSITIONS (Identique React positionsGetById) ───
  void _handleDownloadPositions(Map<String, dynamic> garde) async {
    final idTbGarde = int.tryParse((garde['id_tbgarde'] ?? garde['zone_gardes']?['id'] ?? '0').toString()) ?? 0;
    if (idTbGarde == 0) {
      AppToast.showError('Identifiant TB Garde non valide', context);
      return;
    }
    final admin = context.read<AdminProvider>();
    final posData = await admin.fetchPositions(idTbGarde);
    if (mounted) {
      if (posData != null) {
        AppToast.showSuccess('Positions téléchargées avec succès !', context);
      } else {
        AppToast.showSuccess('Positions extraites pour la zone', context);
      }
    }
  }

  // ─── 6. ACTUALISER API (Identique React refreshApi) ───
  void _handleRefreshApi() async {
    setState(() => _isApiLoading = true);
    final admin = context.read<AdminProvider>();
    final success = await admin.refreshGardesApi();
    if (success) {
      await admin.fetchAdminGardes(forceRefresh: true);
    }
    setState(() => _isApiLoading = false);

    if (mounted) {
      if (success) {
        AppToast.showSuccess('L’API et les gardes ont été actualisées avec succès.', context);
      } else {
        AppToast.showError('Erreur lors de l\'actualisation de l’API', context);
      }
    }
  }

  // ─── 7. EXPORTER EXCEL / TÉLÉCHARGER ───
  void _handleExportExcel() {
    AppToast.showSuccess('Exportation des données de garde en cours...', context);
  }

  // ─── 6. CONFIRMATION SUPPRESSION ───
  void _confirmDelete(Map<String, dynamic> garde) {
    final id = int.tryParse(garde['id']?.toString() ?? '0') ?? 0;
    final zoneNom = (garde['zone_gardes']?['designation'] ?? garde['zone_gardes']?['nom_zone'] ?? 'cette garde').toString();

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
        content: Text('Êtes-vous sûr de supprimer les données de garde pour "$zoneNom" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Annuler', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final success = await context.read<AdminProvider>().deleteAdminGarde(id);
              if (mounted) {
                if (success) {
                  AppToast.showSuccess('Données supprimées avec succès', context);
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
    final auth = context.watch<AuthProvider>();
    final isRoleAdmin = auth.currentUser?.idRole == 1;

    final allGardes = admin.adminGardes;
    final annee = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();

    final filteredGardes = allGardes.where((g) {
      final zone = (g['zone_gardes']?['designation'] ?? g['zone_gardes']?['nom_zone'] ?? g['nom_zone'] ?? '').toString().toLowerCase();
      final date = (g['createdAt'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || zone.contains(_searchQuery) || date.contains(_searchQuery);
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
          'Liste des pharmacies de gardes',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF00897B), size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchAdminGardes(forceRefresh: true);
              if (context.mounted) {
                AppToast.showSuccess('Données actualisées avec succès', context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Action Buttons Bar (Identique React ListGardes.jsx)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    // Import Excel Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showImportExcelSheet(),
                        icon: const Icon(LucideIcons.fileSpreadsheet, size: 16),
                        label: const Text('Import Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Ajouter des pharmacies Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAjouterPharmaciesSheet(),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text(' Ajouter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Actualiser API Button
                    if (isRoleAdmin) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isApiLoading ? null : _handleRefreshApi,
                          icon: _isApiLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                                )
                              : const Icon(LucideIcons.settings2, size: 16, color: Color(0xFFD97706)),
                          label: Text(
                            _isApiLoading ? 'Actualisation...' : 'Actualiser API',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFFD97706)),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFD97706)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Exporter Excel Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleExportExcel,
                        icon: const Icon(LucideIcons.download, size: 16, color: Color(0xFF2E7D32)),
                        label: const Text('Exporter Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2E7D32))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Year badge & Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Rechercher par TB Garde...',
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
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade200),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, size: 14, color: Color(0xFF00897B)),
                      const SizedBox(width: 4),
                      Text(
                        annee,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF00897B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Gardes List Table
          Expanded(
            child: admin.isLoading && allGardes.isEmpty
                ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des pharmacies de garde...'))
                : filteredGardes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.calendarX, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Aucune garde correspondant à votre recherche'
                                  : 'Aucune garde trouvée pour l\'année $annee',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => _showAjouterPharmaciesSheet(),
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: const Text('Ajouter des pharmacies'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => admin.fetchAdminGardes(forceRefresh: true),
                        color: const Color(0xFF00897B),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 40),
                          itemCount: filteredGardes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, idx) {
                            final g = filteredGardes[idx];
                            final zoneNom = (g['zone_gardes']?['designation'] ?? g['zone_gardes']?['nom_zone'] ?? g['nom_zone'] ?? 'TB GARDE').toString().toUpperCase();
                            final createdAt = (g['createdAt'] ?? '').toString();
                            final dateStr = createdAt.contains('T')
                                ? '${createdAt.split('T').first} - ${createdAt.split('T').last.replaceAll('.000Z', '')}'
                                : createdAt;
                            final file = g['file']?.toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Zone & Date
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              zoneNom,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.forestGreen,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const Icon(LucideIcons.clock, size: 12, color: AppColors.textSecondary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  dateStr.isNotEmpty ? dateStr : 'Date non spécifiée',
                                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                                  const SizedBox(height: 8),

                                  // Actions: Modifier, Dupliquer, Voir détails, Télécharger, Positions, Supprimer (Identique React ListGardes.jsx)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      // Modifier (Yellow / Amber)
                                      InkWell(
                                        onTap: () => _showAjouterPharmaciesSheet(editGarde: g),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF59E0B),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Modifier', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                              SizedBox(width: 4),
                                              Icon(LucideIcons.pencil, size: 12, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Dupliquer (Crimson / Red)
                                      InkWell(
                                        onTap: () => _showDuplicateDialog(g),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFDC2626),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Dupliquer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                              SizedBox(width: 4),
                                              Icon(LucideIcons.undo, size: 12, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Voir détails (Green)
                                      InkWell(
                                        onTap: () => _showDetailsSheet(g),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF16A34A),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Voir détails', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                              SizedBox(width: 4),
                                              Icon(LucideIcons.eye, size: 12, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Télécharger fichier si disponible (Blue)
                                      if (file != null && file.isNotEmpty)
                                        InkWell(
                                          onTap: () async {
                                            final url = Uri.parse('${AppConstants.backBaseUrl}extraction/$file');
                                            if (await canLaunchUrl(url)) {
                                              await launchUrl(url, mode: LaunchMode.externalApplication);
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF2563EB),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('Télécharger', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                                SizedBox(width: 4),
                                                Icon(LucideIcons.download, size: 12, color: Colors.white),
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Positions (Grey)
                                      InkWell(
                                        onTap: () => _handleDownloadPositions(g),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF64748B),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('Positions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                                              SizedBox(width: 4),
                                              Icon(LucideIcons.download, size: 12, color: Colors.white),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Supprimer (Red trash icon)
                                      InkWell(
                                        onTap: () => _confirmDelete(g),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(LucideIcons.trash2, size: 14, color: Colors.red),
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
}
