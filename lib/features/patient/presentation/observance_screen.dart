import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';

class ObservanceScreen extends StatefulWidget {
  const ObservanceScreen({super.key});

  @override
  State<ObservanceScreen> createState() => _ObservanceScreenState();
}

class _ObservanceScreenState extends State<ObservanceScreen> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _searchedPatient;
  List<dynamic> _patientMedicaments = [];
  bool _isSearching = false;
  bool _notFound = false;
  bool _isLoadingMedicaments = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      if (user?.isPatient == true) {
        context.read<PatientProvider>().fetchMedicamentsByPatient(user?.id);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _notFound = false;
      _searchedPatient = null;
      _patientMedicaments = [];
    });

    final patientProvider = context.read<PatientProvider>();
    final patient = await patientProvider.getFichePatient(query);

    if (!mounted) return;

    if (patient == null) {
      setState(() {
        _isSearching = false;
        _notFound = true;
      });
    } else {
      setState(() {
        _isSearching = false;
        _notFound = false;
        _searchedPatient = patient;
        _isLoadingMedicaments = true;
      });

      // Fetch patient medications
      final patientId = patient['id'];
      await patientProvider.fetchMedicamentsByPatient(patientId, forceRefresh: true);

      if (mounted) {
        setState(() {
          _patientMedicaments = patientProvider.medicaments;
          _isLoadingMedicaments = false;
        });
      }
    }
  }

  void _handleClear() {
    setState(() {
      _searchController.clear();
      _searchedPatient = null;
      _patientMedicaments = [];
      _notFound = false;
    });
  }

  void _onBottomNavTapped(int index) {
    final isPatient = context.read<AuthProvider>().currentUser?.isPatient == true;
    if (index == 0) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        isPatient ? AppRoutes.homePatient : AppRoutes.homePharmacien,
        (r) => false,
      );
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final topPadding = MediaQuery.of(context).padding.top;
    final isPharmacist = user?.isPharmacien == true || user?.isJeunePharmacie == true || user?.idRole != 3;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER (Identique ObservancePh.jsx) ───
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
                        // Back Button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: InkWell(
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
                        ),
                        const SizedBox(height: 10),

                        // Icon in green container
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
                            child: Icon(LucideIcons.briefcaseMedical, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text(
                          'Observance',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF163820),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isPharmacist
                              ? 'Consultez et gérez l\'observance de vos patients'
                              : 'Suivez vos traitements et votre observance quotidienne',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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

            // ─── MAIN CONTENT ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Column(
                children: [
                  if (isPharmacist) ...[
                    // ─── PHARMACIST SEARCH CARD ───
                    _buildSearchPatientCard(),

                    // ─── PATIENT DETAILS CARD ───
                    if (_searchedPatient != null) ...[
                      const SizedBox(height: 16),
                      _buildPatientDetailsCard(),
                      const SizedBox(height: 16),
                      _buildPatientMedicamentsCard(),
                    ],
                  ] else ...[
                    // ─── PATIENT OWN TREATMENTS VIEW ───
                    _buildPatientSelfTreatmentsView(),
                  ],
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

  // ─── SEARCH PATIENT CARD ───
  Widget _buildSearchPatientCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INSÉRER L\'IDENTIFIANT POUR AFFICHER LE DP',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163820),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _notFound ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            child: TextField(
              controller: _searchController,
              keyboardType: TextInputType.text,
              onSubmitted: (_) => _handleSearch(),
              decoration: InputDecoration(
                hintText: 'Ex: 31051999812',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                border: InputBorder.none,
                isDense: true,
                prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF9CA3AF)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF9CA3AF)),
                        onPressed: _handleClear,
                      )
                    : null,
              ),
              onChanged: (v) => setState(() {}),
            ),
          ),
          const SizedBox(height: 14),

          // Rechercher Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _handleSearch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF71A246),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSearching
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Rechercher',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),

          if (_notFound) ...[
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Aucun patient trouvé avec ce numéro.',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── PATIENT DETAILS CARD ───
  Widget _buildPatientDetailsCard() {
    final patient = _searchedPatient!;
    final name = patient['nom']?.toString() ?? 'Patient';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final birthDate = patient['date_naissance']?.toString() ?? '-';
    final identifiant = patient['cin']?.toString() ?? patient['identifiant']?.toString() ?? '-';
    final allergie = patient['allergie']?.toString() ?? 'Aucune';
    final adresse = patient['adresse']?.toString() ?? '-';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Patient Header: Avatar + Nom
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF71A246), Color(0xFF3A5A22)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163820),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Dossier Patient (DP)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 16),

          // Info Grid
          Row(
            children: [
              Expanded(child: _buildInfoItem('DATE DE NAISSANCE', birthDate)),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoItem('CIN / IDENTIFIANT', identifiant)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildInfoItem('ALLERGIE', allergie, isAlert: allergie != 'Aucune' && allergie != '-')),
              const SizedBox(width: 12),
              Expanded(child: _buildInfoItem('ADRESSE', adresse)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildInfoItem(String label, String value, {bool isAlert = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF163820),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── PATIENT MEDICAMENTS LIST / TABLE CARD ───
  Widget _buildPatientMedicamentsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Nouvelle Dispensation button
          Row(
            children: [
              Expanded(
                child: Text(
                  'Médicaments du patient (${_patientMedicaments.length})',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF163820),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: const Color(0xFF71A246),
                borderRadius: BorderRadius.circular(30),
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    if (_searchedPatient != null) {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.ajouterDispensation,
                        arguments: {'patient': _searchedPatient},
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF71A246).withValues(alpha: 0.28),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.plus, size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Nouvelle dispensation',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingMedicaments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF71A246), strokeWidth: 3),
              ),
            )
          else if (_patientMedicaments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF3F4F6)),
              ),
              child: const Column(
                children: [
                  Icon(LucideIcons.pill, size: 36, color: Color(0xFFCBD5E1)),
                  SizedBox(height: 10),
                  Text(
                    'Aucun médicament enregistré',
                    style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF64748B), fontSize: 13.5),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Cliquez sur "Nouvelle dispensation" pour en ajouter.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _patientMedicaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = _patientMedicaments[i];
                final medicament = item['medicaments'] is Map ? item['medicaments'] as Map<String, dynamic> : {};
                final produit = medicament['produit']?.toString() ?? item['produit']?.toString() ?? 'Médicament';
                final posologie = item['posologie']?.toString() ?? '-';
                final duree = item['duree']?.toString() ?? '-';
                final dateDebut = item['date_debut']?.toString() ?? '-';
                final dateFin = item['date_fin']?.toString() ?? '-';
                final reste = PatientProvider.calculerReste(item['date_debut']?.toString(), item['duree']);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              produit,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF163820),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (reste is int && reste > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$reste jours restants',
                                style: const TextStyle(
                                  color: Color(0xFF15803D),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Terminé',
                                style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(LucideIcons.clock, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Posologie: $posologie',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const Spacer(),
                          const Icon(LucideIcons.calendar, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            '$duree jours ($dateDebut - $dateFin)',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  // ─── PATIENT SELF TREATMENTS VIEW ───
  Widget _buildPatientSelfTreatmentsView() {
    final patient = context.watch<PatientProvider>();
    final activeList = patient.activeMedicaments;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes Traitements Actifs',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163820),
            ),
          ),
          const SizedBox(height: 14),

          if (patient.isLoadingMedicaments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF71A246), strokeWidth: 3),
              ),
            )
          else if (activeList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Aucun traitement actif en cours.',
                  style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final item = activeList[i];
                final medicament = item['medicaments'] is Map ? item['medicaments'] as Map<String, dynamic> : {};
                final produit = medicament['produit']?.toString() ?? item['produit']?.toString() ?? 'Médicament';
                final posologie = item['posologie']?.toString() ?? '-';
                final duree = item['duree']?.toString() ?? '-';
                final reste = PatientProvider.calculerReste(item['date_debut']?.toString(), item['duree']);

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(LucideIcons.pill, color: Color(0xFF15803D), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              produit,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF163820)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Posologie: $posologie ($duree j)',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$reste j',
                          style: const TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
