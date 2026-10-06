import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/patient_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';

class DossierPatientScreen extends StatefulWidget {
  const DossierPatientScreen({super.key});

  @override
  State<DossierPatientScreen> createState() => _DossierPatientScreenState();
}

class _DossierPatientScreenState extends State<DossierPatientScreen> {
  final int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().currentUser;
      final patientId = user?.id;
      context.read<PatientProvider>().fetchMedicamentsByPatient(patientId);
    });
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

  void _onNouvelleDispensation() {
    Navigator.pushNamed(context, AppRoutes.ajouterDispensation);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final patient = context.watch<PatientProvider>();
    final topPadding = MediaQuery.of(context).padding.top;
    final allList = patient.medicaments;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER (Identique React ListDossier.jsx) ───
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage('assets/images/back-mobile.png'),
                  repeat: ImageRepeat.repeat,
                  opacity: 0.18,
                  scale: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // Gradient overlay
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
                    padding: EdgeInsets.only(top: topPadding + 14, bottom: 24, left: 20, right: 20),
                    child: Column(
                      children: [
                        // Top actions: Retour & Nouvelle dispensation
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.arrowLeft, size: 14, color: AppColors.primaryGreen),
                                    SizedBox(width: 6),
                                    Text(
                                      'Retour',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _onNouvelleDispensation,
                              borderRadius: BorderRadius.circular(30),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen,
                                  borderRadius: BorderRadius.circular(30),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.3),
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
                        const SizedBox(height: 12),

                        // Folder Icon in Green Box
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF71A246), Color(0xFF5D8A38)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(LucideIcons.folder, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 12),

                        // Title & Subtitle
                        const Text(
                          'Dossier pharmaceutique',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Historique complet de vos médicaments',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Wave Divider
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: CustomPaint(
                      size: const Size(double.infinity, 24),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── BODY ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: patient.isLoadingMedicaments
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primaryGreen),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Row: Total, Actifs, Terminés (matching React ListDossier.jsx)
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                icon: LucideIcons.pill,
                                value: '${patient.totalTraitements}',
                                label: 'Total',
                                iconBg: const [Color(0xFF71A246), Color(0xFF5D8A38)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatItem(
                                icon: LucideIcons.clock,
                                value: '${patient.traitementsActifs}',
                                label: 'Actifs',
                                iconBg: const [Color(0xFF71A246), Color(0xFF5D8A38)],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatItem(
                                icon: LucideIcons.calendar,
                                value: '${patient.traitementsTermines}',
                                label: 'Terminés',
                                iconBg: const [Color(0xFF6B7280), Color(0xFF4B5563)],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Empty State if no items
                        if (allList.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF3F4F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.folder, size: 28, color: Color(0xFF9CA3AF)),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Dossier vide',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Aucun médicament enregistré pour le moment.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          const Text(
                            'Tous les traitements',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // List of items from real API
                          ...List.generate(allList.length, (idx) {
                            final item = allList[idx] is Map ? allList[idx] as Map<String, dynamic> : <String, dynamic>{};
                            return _buildDossierCard(item, idx);
                          }),
                        ],

                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _currentTabIndex,
        notifCount: auth.unreadNotifications,
        onTap: _onBottomNavTapped,
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF244082).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: iconBg),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.forestGreen,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDossierCard(Map<String, dynamic> item, int index) {
    final medicament = item['medicaments'] is Map ? item['medicaments'] as Map<String, dynamic> : {};
    final nomProduit = medicament['produit']?.toString() ?? 'Médicament';
    final posologie = item['posologie']?.toString();
    final duree = item['duree']?.toString();
    final dateDebut = item['date_debut']?.toString();
    final dateFin = item['date_fin']?.toString();
    final reste = PatientProvider.calculerReste(dateDebut, duree);
    final bool isActif = (reste is int && reste > 0);
    final Color barColor = isActif ? AppColors.primaryGreen : const Color(0xFF9CA3AF);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF244082).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored left bar
              Container(
                width: 5,
                color: barColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name
                      Text(
                        nomProduit,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Pills row: Posologie, Duree, Reste
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (posologie != null && posologie.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.pill, size: 11, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 4),
                                  Text(
                                    posologie,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (duree != null && duree.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.calendar, size: 11, color: Color(0xFF4B5563)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${duree}j',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF4B5563),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActif ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  LucideIcons.clock,
                                  size: 11,
                                  color: isActif ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  reste == 0 ? 'Terminé' : '${reste}j restants',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActif ? const Color(0xFF166534) : const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Date range
                      if (dateDebut != null && dateDebut.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Du $dateDebut${dateFin != null && dateFin.isNotEmpty ? ' → $dateFin' : ''}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
