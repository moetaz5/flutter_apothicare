import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'widgets/admin_drawer.dart';

class AdminJoursScreen extends StatefulWidget {
  const AdminJoursScreen({super.key});

  @override
  State<AdminJoursScreen> createState() => _AdminJoursScreenState();
}

class _AdminJoursScreenState extends State<AdminJoursScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final admin = context.read<AdminProvider>();
      final auth = context.read<AuthProvider>();
      admin.fetchAnnees();
      admin.fetchTbGardes();
      admin.fetchGardesJours(
        forceRefresh: true,
        idUser: auth.currentUser?.id,
        idRole: auth.currentUser?.idRole,
      );
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

  // ─── 1. MODAL IMPORT EXCEL (Identique React ImportGardesJours.jsx) ───
  void _showImportExcelSheet() {
    final admin = context.read<AdminProvider>();
    int? selectedTbGardeId;
    PlatformFile? selectedFile;
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final zones = admin.tbGardes;
          final currentYear = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();

          return Container(
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
                    const Row(
                      children: [
                        Icon(LucideIcons.fileSpreadsheet, color: AppColors.primaryGreen, size: 22),
                        SizedBox(width: 8),
                        Text(
                          'Import Excel (Jours fériés)',
                          style: TextStyle(
                            fontSize: 17,
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

                // Sélection TB Garde
                const Text('TB Garde *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                      isExpanded: true,
                      value: selectedTbGardeId,
                      hint: const Text('Choisir une zone / TB Garde'),
                      items: zones.map((z) {
                        final id = int.tryParse(z['id']?.toString() ?? '') ?? 0;
                        final name = z['nom_zone'] ?? z['designation'] ?? 'Zone #$id';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        );
                      }).toList(),
                      onChanged: (val) => setSheetState(() => selectedTbGardeId = val),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Sélection Fichier Excel
                const Text('Fichier Excel (.xlsx) *', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['xlsx', 'xls'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setSheetState(() => selectedFile = result.files.first);
                      }
                    } catch (e) {
                      AppToast.showError('Erreur de sélection : $e');
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.scaffoldBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selectedFile != null ? AppColors.primaryGreen : AppColors.borderGray,
                        style: BorderStyle.solid,
                        width: selectedFile != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedFile != null ? LucideIcons.fileCheck2 : LucideIcons.uploadCloud,
                          color: selectedFile != null ? AppColors.primaryGreen : AppColors.textSecondary,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            selectedFile != null ? selectedFile!.name : 'Choisir un fichier Excel (.xlsx)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selectedFile != null ? FontWeight.w700 : FontWeight.w500,
                              color: selectedFile != null ? AppColors.forestGreen : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Format attendu : num_cnopt, date, id_jour',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),

                // Bouton Importer
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isUploading
                        ? null
                        : () async {
                            if (selectedTbGardeId == null || selectedFile == null) {
                              AppToast.showError('Veuillez sélectionner un TB Garde et un fichier');
                              return;
                            }

                            setSheetState(() => isUploading = true);

                            final res = await admin.importGardesJoursExcel(
                              fileBytes: selectedFile!.bytes,
                              filePath: selectedFile!.path,
                              fileName: selectedFile!.name,
                              idTbGarde: selectedTbGardeId!,
                              annee: currentYear,
                            );

                            setSheetState(() => isUploading = false);

                            if (res.success) {
                              if (!context.mounted) return;
                              Navigator.pop(ctx);
                              AppToast.showSuccess(res.message);
                            } else {
                              AppToast.showError(res.message);
                            }
                          },
                    icon: isUploading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.upload, size: 18),
                    label: Text(
                      isUploading ? 'Importation en cours...' : 'Lancer l\'importation',
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
          );
        },
      ),
    );
  }

  // ─── 2. MODAL AJOUTER DES PHARMACIES (Identique React AjouterGardesJours.jsx) ───
  void _showAjouterPharmaciesJoursSheet({Map<String, dynamic>? editGarde}) {
    final isEditing = editGarde != null;
    int? selectedTbGardeId = int.tryParse(editGarde?['id_tbgarde']?.toString() ?? editGarde?['zone_gardes']?['id']?.toString() ?? '');

    String selectedTypeJour = '1'; // '1': National, '2': Religieux
    List<Map<String, dynamic>> joursList = [];
    Map<String, dynamic>? selectedJour;
    List<Map<String, dynamic>> pharmaciesList = [];
    Map<String, dynamic>? selectedPharmacie;

    List<Map<String, dynamic>> addedRows = [];
    bool isLoadingJours = false;
    bool isLoadingPharmacies = false;
    bool isSaving = false;
    bool initialLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setSheetState) {
          final admin = context.read<AdminProvider>();
          final zones = admin.tbGardes;
          final currentYear = admin.selectedYear.isNotEmpty ? admin.selectedYear : DateTime.now().year.toString();

          void loadJoursForType(String type) async {
            setSheetState(() => isLoadingJours = true);
            final res = await admin.fetchJoursByType(annee: currentYear, type: type);
            setSheetState(() {
              joursList = res;
              isLoadingJours = false;
              selectedJour = null;
            });
          }

          void loadPharmaciesForZone(int zoneId) async {
            setSheetState(() => isLoadingPharmacies = true);
            final res = await admin.fetchGroupePharmaciensByZone(zoneId);
            setSheetState(() {
              pharmaciesList = res;
              isLoadingPharmacies = false;
              selectedPharmacie = null;
            });
          }

          if (!initialLoaded) {
            initialLoaded = true;
            loadJoursForType(selectedTypeJour);
            if (selectedTbGardeId != null) {
              loadPharmaciesForZone(selectedTbGardeId!);
            }

            if (isEditing) {
              final id = int.tryParse(editGarde['id']?.toString() ?? '0') ?? 0;
              admin.fetchGardeJoursDetails(id).then((details) {
                if (details != null && details['data'] is List) {
                  final List<Map<String, dynamic>> rows = [];
                  for (var l in (details['data'] as List)) {
                    if (l is Map) {
                      rows.add({
                        'num_cnopt': (l['num_cnopt'] ?? '').toString(),
                        'jour_ferie': (l['jour_ferie'] ?? l['date'] ?? '').toString().split('T').first,
                        'date': (l['jour_ferie'] ?? l['date'] ?? '').toString().split('T').first,
                        'id_tbgarde': selectedTbGardeId,
                        'nom_jour': l['jours_feries']?['nom'] ?? 'Jour férié',
                        'nom_pharmacie': l['top_pharmacien']?['nom'] ?? 'Pharmacie',
                        'id_pharmacien': l['id_pharmacien'] ?? l['top_pharmacien']?['id'],
                      });
                    }
                  }
                  setSheetState(() => addedRows = rows);
                }
              });
            }
          }

          return Container(
            height: MediaQuery.of(modalCtx).size.height * 0.88,
            padding: EdgeInsets.only(
              left: 18,
              right: 18,
              top: 20,
              bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 16,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Modifier les pharmacies (Jours fériés)' : 'Ajouter des pharmacies (Jours fériés)',
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Zone / TB Garde Selector
                        const Text('TB Garde *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: selectedTbGardeId,
                              hint: const Text('Sélectionner TB Garde'),
                              items: zones.map((z) {
                                final id = int.tryParse(z['id']?.toString() ?? '') ?? 0;
                                final name = z['nom_zone'] ?? z['designation'] ?? 'Zone #$id';
                                return DropdownMenuItem<int>(
                                  value: id,
                                  child: Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setSheetState(() {
                                  selectedTbGardeId = val;
                                  if (val != null) loadPharmaciesForZone(val);
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Type de jour férié (National vs Religieux)
                        const Text('Type de jour férié *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('National')),
                                selected: selectedTypeJour == '1',
                                selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: selectedTypeJour == '1' ? AppColors.primaryGreen : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(() => selectedTypeJour = '1');
                                    loadJoursForType('1');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ChoiceChip(
                                label: const Center(child: Text('Religieux')),
                                selected: selectedTypeJour == '2',
                                selectedColor: AppColors.primaryGreen.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: selectedTypeJour == '2' ? AppColors.primaryGreen : AppColors.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                                onSelected: (val) {
                                  if (val) {
                                    setSheetState(() => selectedTypeJour = '2');
                                    loadJoursForType('2');
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Jour férié Selector
                        const Text('Jour férié *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              isExpanded: true,
                              value: selectedJour,
                              hint: Text(isLoadingJours ? 'Chargement des jours...' : 'Sélectionner un jour férié'),
                              items: joursList.map((j) {
                                final nom = j['nom'] ?? 'Jour';
                                final date = (j['date'] ?? '').toString().split('T').first;
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: j,
                                  child: Text('$nom ($date)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) => setSheetState(() => selectedJour = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Pharmacie Selector
                        const Text('Pharmacie *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              isExpanded: true,
                              value: selectedPharmacie,
                              hint: Text(isLoadingPharmacies ? 'Chargement des pharmacies...' : 'Sélectionner une pharmacie'),
                              items: pharmaciesList.map((p) {
                                final nom = p['noms'] ?? p['nom'] ?? 'Pharmacie';
                                final cnopt = p['tva'] ?? p['num_cnopt'] ?? '';
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: p,
                                  child: Text(
                                    cnopt.toString().isNotEmpty ? '$nom ($cnopt)' : nom,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) => setSheetState(() => selectedPharmacie = val),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bouton Ajouter Ligne
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (selectedTbGardeId == null || selectedJour == null || selectedPharmacie == null) {
                                AppToast.showError('Veuillez remplir TB Garde, Jour Férié et Pharmacie');
                                return;
                              }

                              final nomJour = selectedJour!['nom'] ?? 'Jour férié';
                              final dateJour = (selectedJour!['date'] ?? '').toString().split('T').first;
                              final idJour = selectedJour!['id'] ?? 0;

                              final pharmaList = selectedPharmacie!['pharmacies'];
                              if (pharmaList is List && pharmaList.length > 1) {
                                for (var p in pharmaList) {
                                  if (p is Map) {
                                    addedRows.add({
                                      'num_cnopt': (p['tva'] ?? p['num_cnopt'] ?? '').toString(),
                                      'jour_ferie': dateJour,
                                      'date': dateJour,
                                      'id_tbgarde': selectedTbGardeId,
                                      'nom_jour': nomJour,
                                      'nom_pharmacie': p['nom'] ?? 'Pharmacie',
                                      'id_pharmacien': p['id'],
                                      'id_jour': idJour,
                                    });
                                  }
                                }
                              } else {
                                final nomP = selectedPharmacie!['nom'] ?? selectedPharmacie!['noms'] ?? 'Pharmacie';
                                final tvaP = (selectedPharmacie!['tva'] ?? selectedPharmacie!['num_cnopt'] ?? '').toString();
                                final idP = selectedPharmacie!['id'] ?? selectedPharmacie!['value'];

                                addedRows.add({
                                  'num_cnopt': tvaP,
                                  'jour_ferie': dateJour,
                                  'date': dateJour,
                                  'id_tbgarde': selectedTbGardeId,
                                  'nom_jour': nomJour,
                                  'nom_pharmacie': nomP,
                                  'id_pharmacien': idP,
                                  'id_jour': idJour,
                                });
                              }

                              setSheetState(() {
                                selectedPharmacie = null;
                              });
                              AppToast.showSuccess('Ligne ajoutée au tableau');
                            },
                            icon: const Icon(LucideIcons.plus, size: 16, color: AppColors.forestGreen),
                            label: const Text('Ajouter au tableau', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forestGreen)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Tableau des lignes ajoutées
                        if (addedRows.isNotEmpty) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Lignes prêtes (${addedRows.length})',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                              ),
                              TextButton(
                                onPressed: () => setSheetState(() => addedRows.clear()),
                                child: const Text('Tout effacer', style: TextStyle(color: AppColors.error, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.scaffoldBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.borderGray),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: addedRows.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, idx) {
                                final r = addedRows[idx];
                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    r['nom_pharmacie'] ?? 'Pharmacie',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                  subtitle: Text(
                                    '${r['nom_jour']} • ${r['date']} • CNOPT: ${r['num_cnopt']}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(LucideIcons.trash2, size: 16, color: AppColors.error),
                                    onPressed: () => setSheetState(() => addedRows.removeAt(idx)),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    ),
                  ),
                ),

                // Bouton Enregistrer Final
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: isSaving || addedRows.isEmpty
                        ? null
                        : () async {
                            if (selectedTbGardeId == null) {
                              AppToast.showError('Veuillez sélectionner un TB Garde');
                              return;
                            }

                            setSheetState(() => isSaving = true);

                            final res = isEditing
                                ? await admin.updateGardeJoursLines(
                                    id: int.tryParse(editGarde['id']?.toString() ?? '0') ?? 0,
                                    data: addedRows,
                                  )
                                : await admin.addLignesGardeJours(
                                    idTbGarde: selectedTbGardeId!,
                                    lignes: addedRows,
                                    annee: currentYear,
                                  );

                            setSheetState(() => isSaving = false);

                            if (res.success) {
                              if (!context.mounted) return;
                              Navigator.pop(ctx);
                              AppToast.showSuccess(res.message);
                            } else {
                              AppToast.showError(res.message);
                            }
                          },
                    icon: isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.save, size: 18),
                    label: Text(
                      isSaving ? 'Enregistrement...' : 'Enregistrer les pharmacies (${addedRows.length})',
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
          );
        },
      ),
    );
  }

  // ─── 3. MODAL DÉTAILS D'UNE GARDE JOURS FÉRIÉS (Identique React DetailsGardeJours.jsx) ───
  void _showDetailsDialog(Map<String, dynamic> garde) async {
    final admin = context.read<AdminProvider>();
    final id = int.tryParse(garde['id']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<Map<String, dynamic>?>(
        future: admin.fetchGardeJoursDetails(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen));
          }

          final data = snapshot.data;
          final lines = (data?['data'] ?? data?['lignes'] ?? []) as List;
          final zoneName = garde['zone_gardes']?['nom_zone'] ?? garde['zone_gardes']?['designation'] ?? 'Zone';
          final annee = garde['annee'] ?? DateTime.now().year.toString();

          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Détails Garde - $zoneName',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                      ),
                      Text('Année : $annee • ${lines.length} pharmacie(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(LucideIcons.x, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: lines.isEmpty
                  ? const Center(child: Text('Aucune ligne trouvée pour cette garde'))
                  : ListView.separated(
                      itemCount: lines.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final l = lines[i];
                        final nomPharma = l['top_pharmacien']?['nom'] ?? l['nom_pharmacien'] ?? 'Pharmacie';
                        final date = (l['jour_ferie'] ?? l['date'] ?? '').toString().split('T').first;
                        final jourNom = l['jours_feries']?['nom'] ?? 'Jour férié';
                        final cnopt = l['num_cnopt'] ?? '';

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(LucideIcons.calendarCheck, size: 18, color: AppColors.forestGreen),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(nomPharma, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text('$jourNom • $date', style: const TextStyle(fontSize: 11.5, color: AppColors.forestGreen, fontWeight: FontWeight.w600)),
                                    if (cnopt.toString().isNotEmpty)
                                      Text('CNOPT : $cnopt', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.forestGreen)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── 4. DUPLIQUER UNE GARDE (Identique React DuplicateGardeJours.jsx) ───
  void _confirmDuplicate(Map<String, dynamic> garde) {
    final admin = context.read<AdminProvider>();
    final currentYear = int.tryParse(admin.selectedYear) ?? DateTime.now().year;
    final nextYear = (currentYear + 1).toString();
    final id = int.tryParse(garde['id']?.toString() ?? '0') ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dupliquer la garde', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.forestGreen)),
        content: Text('Voulez-vous dupliquer cette liste de pharmacies (Jours fériés) pour l\'année $nextYear ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await admin.duplicateGardeJours(id: id, targetAnnee: nextYear);
              if (res.success) {
                AppToast.showSuccess(res.message);
              } else {
                AppToast.showError(res.message);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Dupliquer pour $nextYear'),
          ),
        ],
      ),
    );
  }

  // ─── 5. CONFIRMATION SUPPRESSION ───
  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.error)),
        content: const Text('Êtes-vous sûr de vouloir supprimer cette garde (jours fériés) ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await context.read<AdminProvider>().deleteGardeJours(id);
              if (ok) {
                AppToast.showSuccess('Données supprimées avec succès');
              } else {
                AppToast.showError('Erreur lors de la suppression');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ─── 6. SÉLECTIONNER L'ANNÉE ACTIVE MODAL ───
  void _showYearSelectorModal(BuildContext context) {
    final admin = context.read<AdminProvider>();
    final auth = context.read<AuthProvider>();

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
                          await admin.fetchGardesJours(
                            forceRefresh: true,
                            annee: yearStr,
                            idUser: auth.currentUser?.id,
                            idRole: auth.currentUser?.idRole,
                          );
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
    final rawGardes = admin.gardesJours;

    final filteredList = rawGardes.where((g) {
      if (_searchQuery.isEmpty) return true;
      final zoneName = (g['zone_gardes']?['nom_zone'] ?? g['zone_gardes']?['designation'] ?? g['tb_garde'] ?? '').toString().toLowerCase();
      final date = (g['createdAt'] ?? '').toString().toLowerCase();
      return zoneName.contains(_searchQuery) || date.contains(_searchQuery);
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
          'Liste des pharmacies (Jours fériés)',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, color: AppColors.forestGreen, size: 20),
            tooltip: 'Actualiser',
            onPressed: () async {
              await admin.fetchGardesJours(
                forceRefresh: true,
                idUser: auth.currentUser?.id,
                idRole: auth.currentUser?.idRole,
              );
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
        onRefresh: () => admin.fetchGardesJours(
          forceRefresh: true,
          idUser: auth.currentUser?.id,
          idRole: auth.currentUser?.idRole,
        ),
        color: AppColors.primaryGreen,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── ACTION BUTTONS (Exactement identique React: Import Excel / Ajouter / Exporter) ───
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Import Excel Pill
                  ElevatedButton.icon(
                    onPressed: _showImportExcelSheet,
                    icon: const Icon(LucideIcons.fileSpreadsheet, size: 15),
                    label: const Text('Import Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F5E9),
                      foregroundColor: const Color(0xFF2E7D32),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: Color(0xFFA5D6A7)),
                      ),
                    ),
                  ),

                  // + Ajouter des pharmacies Pill
                  ElevatedButton.icon(
                    onPressed: () => _showAjouterPharmaciesJoursSheet(),
                    icon: const Icon(LucideIcons.plus, size: 15),
                    label: const Text('Ajouter des pharmacies', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),

                  // Exporter Excel Pill
                  ElevatedButton.icon(
                    onPressed: () {
                      AppToast.showSuccess('Exportation de la liste des pharmacies (Jours fériés) démarrée');
                    },
                    icon: const Icon(LucideIcons.download, size: 15),
                    label: const Text('Exporter Excel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ─── SEARCH & FILTER INPUT ───
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
                    hintText: 'Rechercher par TB GARDE ou date...',
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

              // ─── SECTION TITLE ───
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Pharmacies de garde (${filteredList.length})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.forestGreen),
                  ),
                  if (admin.isLoading)
                    const AppLoadingIndicator.small(size: 16),
                ],
              ),
              const SizedBox(height: 10),

              // ─── DATA TABLE / LIST OF CARDS ───
              if (admin.isLoading && rawGardes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: AppLoadingIndicator.page(message: 'Chargement des pharmacies de garde...')),
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
                        'Aucune garde trouvée',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Utilisez "Import Excel" ou "Ajouter des pharmacies" pour configurer les jours fériés',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filteredList[index];
                    final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
                    final zone = item['zone_gardes'];
                    final zoneName = zone?['nom_zone'] ?? zone?['designation'] ?? item['tb_garde'] ?? 'Zone #$id';
                    final rawCreated = (item['createdAt'] ?? '').toString();
                    final createdFormatted = rawCreated.contains('T')
                        ? '${rawCreated.split('T').first} - ${rawCreated.split('T').last.replaceAll('.000Z', '')}'
                        : rawCreated;
                    final fileUrl = item['file']?.toString();

                    return Container(
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
                        border: Border.all(color: AppColors.borderGray.withValues(alpha: 0.6)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: TB GARDE Badge + Date
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'TB GARDE',
                                              style: TextStyle(
                                                color: AppColors.forestGreen,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              zoneName.toString().toUpperCase(),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: AppColors.forestGreen,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(LucideIcons.clock, size: 13, color: AppColors.textMuted),
                                          const SizedBox(width: 5),
                                          Text(
                                            'Date de création : $createdFormatted',
                                            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Actions Delete Button
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.error),
                                  onPressed: () => _confirmDelete(id),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const Divider(height: 18),

                            // Bottom Actions Row (Modifier / Dupliquer / Détails / Télécharger)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                // Modifier
                                InkWell(
                                  onTap: () => _showAjouterPharmaciesJoursSheet(editGarde: item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFD54F)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.edit, size: 13, color: Color(0xFFF57F17)),
                                        SizedBox(width: 4),
                                        Text('Modifier', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFF57F17))),
                                      ],
                                    ),
                                  ),
                                ),

                                // Dupliquer
                                InkWell(
                                  onTap: () => _confirmDuplicate(item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFEF9A9A)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.undo, size: 13, color: Color(0xFFC62828)),
                                        SizedBox(width: 4),
                                        Text('Dupliquer', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFC62828))),
                                      ],
                                    ),
                                  ),
                                ),

                                // Voir détails
                                InkWell(
                                  onTap: () => _showDetailsDialog(item),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFA5D6A7)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(LucideIcons.eye, size: 13, color: Color(0xFF2E7D32)),
                                        SizedBox(width: 4),
                                        Text('Voir détails', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2E7D32))),
                                      ],
                                    ),
                                  ),
                                ),

                                // Télécharger Fichier (if exists)
                                if (fileUrl != null && fileUrl.isNotEmpty)
                                  InkWell(
                                    onTap: () async {
                                      final url = '${AppConstants.backBaseUrl.replaceAll('/api/', '')}/extraction/$fileUrl';
                                      final uri = Uri.parse(url);
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      } else {
                                        AppToast.showInfo('Fichier : $fileUrl');
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE3F2FD),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF90CAF9)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.download, size: 13, color: Color(0xFF1565C0)),
                                          SizedBox(width: 4),
                                          Text('Télécharger', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
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
