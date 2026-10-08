import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';

class AjouterDispensationScreen extends StatefulWidget {
  const AjouterDispensationScreen({super.key});

  @override
  State<AjouterDispensationScreen> createState() => _AjouterDispensationScreenState();
}

class _AjouterDispensationScreenState extends State<AjouterDispensationScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  dynamic _selectedMedicament;
  final TextEditingController _posologieController = TextEditingController();
  final TextEditingController _dureeController = TextEditingController();

  DateTime _dateDebut = DateTime.now();
  DateTime? _dateFin;

  final List<Map<String, dynamic>> _finalList = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final patientProvider = context.read<PatientProvider>();
      final meds = await patientProvider.fetchAllMedicaments();
      
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final medName = (args['medicament_name'] ?? '').toString().toLowerCase().trim();
        final codeBarre = (args['code_barre'] ?? '').toString().trim();

        for (var m in meds) {
          final pName = (m['produit'] ?? m['nom'] ?? '').toString().toLowerCase().trim();
          final cBarre = (m['code_barre'] ?? m['code'] ?? '').toString().trim();
          if ((codeBarre.isNotEmpty && cBarre == codeBarre) ||
              (medName.isNotEmpty && (pName == medName || pName.contains(medName) || medName.contains(pName)))) {
            if (mounted) {
              setState(() {
                _selectedMedicament = m;
              });
            }
            break;
          }
        }
      }
    });
    _recalculateDateFin();
  }

  @override
  void dispose() {
    _posologieController.dispose();
    _dureeController.dispose();
    super.dispose();
  }

  void _recalculateDateFin() {
    final dureeInt = int.tryParse(_dureeController.text.trim()) ?? 0;
    if (dureeInt > 0) {
      _dateFin = _dateDebut.add(Duration(days: dureeInt));
    } else {
      _dateFin = null;
    }
  }

  void _resetCurrentForm() {
    setState(() {
      _selectedMedicament = null;
      _posologieController.clear();
      _dureeController.clear();
      _dateDebut = DateTime.now();
      _dateFin = null;
    });
  }

  void _addCurrentToList() {
    if (_selectedMedicament == null ||
        _posologieController.text.trim().isEmpty ||
        _dureeController.text.trim().isEmpty) {
      AppToast.showError('Veuillez remplir tous les champs du médicament !', context);
      return;
    }

    final medId = _selectedMedicament['id'];
    final medName = _selectedMedicament['produit']?.toString() ?? 'Médicament';
    final posologie = _posologieController.text.trim();
    final duree = int.tryParse(_dureeController.text.trim()) ?? 0;
    final dateDebutStr = DateFormat('yyyy-MM-dd').format(_dateDebut);
    final dateFinStr = _dateFin != null ? DateFormat('yyyy-MM-dd').format(_dateFin!) : dateDebutStr;

    setState(() {
      _finalList.add({
        'medicamentId': medId,
        'medicamentName': medName,
        'posologie': posologie,
        'duree': duree,
        'dateDebut': dateDebutStr,
        'dateFin': dateFinStr,
      });
      _resetCurrentForm();
    });

    AppToast.showSuccess('Médicament ajouté à la liste !', context);
  }

  Future<void> _handleSaveDispensation() async {
    final List<Map<String, dynamic>> itemsToSave = List.from(_finalList);

    final hasCurrentData = _selectedMedicament != null ||
        _posologieController.text.trim().isNotEmpty ||
        _dureeController.text.trim().isNotEmpty;

    if (hasCurrentData) {
      if (_selectedMedicament == null ||
          _posologieController.text.trim().isEmpty ||
          _dureeController.text.trim().isEmpty) {
        AppToast.showError('Veuillez compléter le médicament en cours ou l\'ajouter à la liste !', context);
        return;
      }
      final medId = _selectedMedicament['id'];
      final medName = _selectedMedicament['produit']?.toString() ?? 'Médicament';
      final posologie = _posologieController.text.trim();
      final duree = int.tryParse(_dureeController.text.trim()) ?? 0;
      final dateDebutStr = DateFormat('yyyy-MM-dd').format(_dateDebut);
      final dateFinStr = _dateFin != null ? DateFormat('yyyy-MM-dd').format(_dateFin!) : dateDebutStr;

      itemsToSave.add({
        'medicamentId': medId,
        'medicamentName': medName,
        'posologie': posologie,
        'duree': duree,
        'dateDebut': dateDebutStr,
        'dateFin': dateFinStr,
      });
    }

    if (itemsToSave.isEmpty) {
      AppToast.showError('Veuillez ajouter au moins un médicament !', context);
      return;
    }

    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final patientProvider = context.read<PatientProvider>();
    final patientId = auth.currentUser?.id;

    final payload = itemsToSave.map((item) => {
      'medicamentId': item['medicamentId'],
      'posologie': item['posologie'],
      'duree': item['duree'],
      'dateDebut': item['dateDebut'],
      'dateFin': item['dateFin'],
    }).toList();

    final success = await patientProvider.addDispensation(
      patientId: patientId,
      medicaments: payload,
    );

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        AppToast.showSuccess('Dispensation enregistrée avec succès !', context);
        Navigator.pop(context);
      } else {
        AppToast.showError('Erreur lors de l\'enregistrement de la dispensation.', context);
      }
    }
  }

  void _openBarcodeScanner(List<dynamic> allMeds) async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.qrScanner,
      arguments: {'isSelectionMode': true},
    );

    if (result is Map && mounted) {
      _applyScannedProduct(result, allMeds);
    }
  }

  void _applyScannedProduct(Map result, List<dynamic> allMeds) {
    final medName = (result['medicament_name'] ?? result['produit'] ?? result['nom'] ?? '').toString().toLowerCase().trim();
    final codeBarre = (result['code_barre'] ?? '').toString().trim();

    dynamic matched;
    for (var m in allMeds) {
      final pName = (m['produit'] ?? m['nom'] ?? '').toString().toLowerCase().trim();
      final cBarre = (m['code_barre'] ?? m['code'] ?? '').toString().trim();
      if ((codeBarre.isNotEmpty && cBarre == codeBarre) ||
          (medName.isNotEmpty && (pName == medName || pName.contains(medName) || medName.contains(pName)))) {
        matched = m;
        break;
      }
    }

    if (matched != null) {
      setState(() {
        _selectedMedicament = matched;
      });
      AppToast.showSuccess('Produit sélectionné : ${matched['produit'] ?? matched['nom']}', context);
    } else if (medName.isNotEmpty || codeBarre.isNotEmpty) {
      setState(() {
        _selectedMedicament = {
          'id': result['product']?['id'] ?? 0,
          'produit': result['medicament_name'] ?? medName,
          'code_barre': codeBarre,
        };
      });
      AppToast.showSuccess('Produit appliqué : ${result['medicament_name'] ?? medName}', context);
    }
  }

  void _showMedicamentPicker(List<dynamic> allMeds, {bool byBarcode = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final filtered = allMeds.where((m) {
              final prod = (m['produit'] ?? '').toString().toLowerCase();
              final code = (m['code_barre'] ?? '').toString().toLowerCase();
              final q = query.toLowerCase();
              return prod.contains(q) || code.contains(q);
            }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(26),
                  topRight: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Text(
                      byBarcode ? 'Sélectionner un code à barre' : 'Sélectionner un médicament',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy),
                    ),
                  ),

                  // Search input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: TextField(
                      autofocus: true,
                      onChanged: (val) => setModalState(() => query = val),
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF9CA3AF)),
                        filled: true,
                        fillColor: const Color(0xFFF3F4F6),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),

                  // List
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'Aucun médicament trouvé.',
                              style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                            itemBuilder: (context, i) {
                              final m = filtered[i];
                              final isSelected = _selectedMedicament != null && _selectedMedicament['id'] == m['id'];
                              return ListTile(
                                onTap: () {
                                  setState(() {
                                    _selectedMedicament = m;
                                  });
                                  Navigator.pop(ctx);
                                },
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: isSelected ? _green : const Color(0xFFEAF5E5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    byBarcode ? LucideIcons.barcode : LucideIcons.pill,
                                    color: isSelected ? Colors.white : _green,
                                    size: 18,
                                  ),
                                ),
                                title: Text(
                                  m['produit']?.toString() ?? 'Médicament',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? _navy : const Color(0xFF374151),
                                    fontSize: 14,
                                  ),
                                ),
                                subtitle: Text(
                                  'Code: ${m['code_barre'] ?? '—'} · Dosage: ${m['dosage'] ?? '—'}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                ),
                                trailing: isSelected
                                    ? const Icon(LucideIcons.check, color: _green, size: 20)
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onBottomNavTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.actualites);
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, AppRoutes.profile);
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final patientProvider = context.watch<PatientProvider>();
    final allMeds = patientProvider.allMedicamentsList;
    final topPadding = MediaQuery.of(context).padding.top;
    final user = auth.currentUser;
    final subtitleText = user?.email?.isNotEmpty == true
        ? user!.email!
        : (user?.nom?.isNotEmpty == true ? user!.nom! : 'Patient');

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER SECTION (Exact React design) ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(20, topPadding + 14, 20, 36),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF4F9F1),
                    Color(0xFFEAF5E5),
                    Color(0xFFE2EFE0),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Retour button
                  Align(
                    alignment: Alignment.topLeft,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: _green, width: 1.5),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.undo2, size: 14, color: _green),
                            SizedBox(width: 6),
                            Text(
                              'Retour',
                              style: TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Pill Icon Badge
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_green, _greenDark],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(LucideIcons.pill, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  const Text(
                    'Nouvelle dispensation',
                    style: TextStyle(
                      color: _navy,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Subtitle
                  Text(
                    subtitleText,
                    style: const TextStyle(
                      color: Color(0xFF4B6A3A),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // ─── FORM SECTION ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  // Card: Informations du médicament
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF244082).withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [_green, _greenDark]),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(LucideIcons.pill, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Informations du médicament',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),

                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 📸 Scanner un médicament Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openBarcodeScanner(allMeds),
                                  icon: const Icon(LucideIcons.camera, size: 18),
                                  label: const Text(
                                    'Scanner un médicament',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 2,
                                    shadowColor: _green.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // CODE À BARRE
                              _buildFieldLabel('CODE À BARRE'),
                              InkWell(
                                onTap: () => _showMedicamentPicker(allMeds, byBarcode: true),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedMedicament != null && _selectedMedicament['code_barre'] != null
                                              ? '${_selectedMedicament['code_barre']}'
                                              : 'Sélectionner...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _selectedMedicament != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // MÉDICAMENT
                              _buildFieldLabel('MÉDICAMENT'),
                              InkWell(
                                onTap: () => _showMedicamentPicker(allMeds, byBarcode: false),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _selectedMedicament != null && _selectedMedicament['produit'] != null
                                              ? '${_selectedMedicament['produit']}'
                                              : 'Sélectionner...',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _selectedMedicament != null ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF9CA3AF)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // POSOLOGIE
                              _buildFieldLabel('POSOLOGIE (X * X)'),
                              TextField(
                                controller: _posologieController,
                                style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 2*3',
                                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4EAF3), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _green, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // DURÉE
                              _buildFieldLabel('DURÉE (JOURS)'),
                              TextField(
                                controller: _dureeController,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() => _recalculateDateFin()),
                                style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 5',
                                  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE4EAF3), width: 1.5),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: _green, width: 1.5),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // DATE DÉBUT
                              _buildFieldLabel('DATE DÉBUT'),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _dateDebut,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _dateDebut = picked;
                                      _recalculateDateFin();
                                    });
                                  }
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.calendar, size: 18, color: _green),
                                      const SizedBox(width: 10),
                                      Text(
                                        DateFormat('yyyy-MM-dd').format(_dateDebut),
                                        style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),

                              // DATE FIN
                              _buildFieldLabel('DATE FIN'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFE4EAF3), width: 1.5),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.calendar, size: 18, color: Color(0xFF9CA3AF)),
                                    const SizedBox(width: 10),
                                    Text(
                                      _dateFin != null ? DateFormat('yyyy-MM-dd').format(_dateFin!) : '—',
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // ➕ Ajouter à la liste Button
                              InkWell(
                                onTap: _addCurrentToList,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  decoration: BoxDecoration(
                                    color: _green.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _green, width: 1.8, strokeAlign: BorderSide.strokeAlignInside),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.plus, color: _green, size: 18),
                                      SizedBox(width: 6),
                                      Text(
                                        'Ajouter à la liste',
                                        style: TextStyle(
                                          color: _green,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
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
                  ),

                  // ─── CARD: Médicaments ajoutés ───
                  if (_finalList.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF244082).withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [_green, _greenDark]),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: const Icon(LucideIcons.checkCircle, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Médicaments ajoutés (${_finalList.length})',
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: _navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, color: Colors.grey.shade100),

                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _finalList.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                            itemBuilder: (context, idx) {
                              final item = _finalList[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(colors: [_green, _greenDark]),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(LucideIcons.pill, color: Colors.white, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['medicamentName'] ?? '—',
                                            style: const TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F2937),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item['posologie']} · ${item['duree']}j · ${item['dateDebut']} → ${item['dateFin']}',
                                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => setState(() => _finalList.removeAt(idx)),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(LucideIcons.x, color: Color(0xFFEF4444), size: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ─── ENREGISTRER LA DISPENSATION BUTTON ───
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _handleSaveDispensation,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(LucideIcons.checkCircle, size: 18),
                      label: Text(
                        _isSaving ? 'Enregistrement…' : 'Enregistrer la dispensation',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        shadowColor: const Color(0xFF244082).withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF9CA3AF),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
