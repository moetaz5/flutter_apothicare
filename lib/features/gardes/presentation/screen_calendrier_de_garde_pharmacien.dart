import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/garde_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';

// Constantes de style identiques à la version React
const Color _kNavy = Color(0xFF163820);
const Color _kGreen = Color(0xFF71A246);
const Color _kOrange = Color(0xFFD3783B);
const Color _kBgColor = Color(0xFFF0F4F8);

class ScreenCalendrierDeGardePharmacien extends StatefulWidget {
  const ScreenCalendrierDeGardePharmacien({super.key});

  @override
  State<ScreenCalendrierDeGardePharmacien> createState() => _ScreenCalendrierDeGardePharmacienState();
}

class _ScreenCalendrierDeGardePharmacienState extends State<ScreenCalendrierDeGardePharmacien> {
  DateTime _currentDate = DateTime.now();
  List<dynamic> _gardesData = [];
  bool _isLoading = true;

  static const List<String> _monthNames = [
    'JANVIER',
    'FÉVRIER',
    'MARS',
    'AVRIL',
    'MAI',
    'JUIN',
    'JUILLET',
    'AOÛT',
    'SEPTEMBRE',
    'OCTOBRE',
    'NOVEMBRE',
    'DÉCEMBRE',
  ];

  // Dimanche, Lundi, Mardi, Mercredi, Jeudi, Vendredi, Samedi (identique React)
  static const List<String> _dayNames = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGardes();
    });
  }

  Future<void> _loadGardes() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final gardeProvider = context.read<GardeProvider>();

    final annee = _currentDate.year.toString();
    final numCnopt = user?.numCnopt ?? user?.id;

    if (numCnopt != null) {
      final data = await gardeProvider.fetchGardesByCnopt(
        annee: annee,
        numCnopt: numCnopt,
      );
      if (mounted) {
        setState(() {
          _gardesData = data;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDownloadPdf() async {
    final user = context.read<AuthProvider>().currentUser;
    final idTbGarde = user?.numCnopt ?? user?.idGarde ?? user?.id;

    if (idTbGarde == null) {
      AppToast.showError('Zone de garde non trouvée', context);
      return;
    }

    try {
      final t = DateTime.now().millisecondsSinceEpoch;
      final pdfUrl = '${AppConstants.backBaseUrl}garde/getPdfNew/$idTbGarde?t=$t';
      final uri = Uri.parse(pdfUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          context.read<GardeProvider>().logPdfDownloadHistory();
        }
      } else {
        // Fallback vers l'ancienne route si getPdfNew échoue
        final fallbackUrl = '${AppConstants.backBaseUrl}garde/getPdf/$idTbGarde';
        final fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
          if (mounted) {
            context.read<GardeProvider>().logPdfDownloadHistory();
          }
        } else {
          if (mounted) {
            AppToast.showError('Impossible d\'ouvrir le fichier PDF', context);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError('Erreur lors de l\'ouverture du PDF', context);
      }
    }
  }

  void _onPrevMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
    });
  }

  void _onNextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
    });
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  int _getFirstDayOfMonth(int year, int month) {
    final weekday = DateTime(year, month, 1).weekday;
    // Dimanche = 0, Lundi = 1, ..., Samedi = 6 (comme getDay() en Javascript)
    return weekday == 7 ? 0 : weekday;
  }

  Map<String, Map<String, dynamic>> _getGardesMap() {
    final map = <String, Map<String, dynamic>>{};

    for (final garde in _gardesData) {
      try {
        final startRaw = garde['date_debut']?.toString();
        final endRaw = garde['date_fin']?.toString();
        if (startRaw == null || endRaw == null) continue;

        DateTime current = DateTime.parse(startRaw);
        final end = DateTime.parse(endRaw);
        final isFerie = garde['isFerie'] == true ||
            garde['is_ferie'] == 1 ||
            garde['is_ferie'] == true ||
            garde['type'] == 'ferie';

        while (!current.isAfter(end)) {
          final dateStr = DateFormat('yyyy-MM-dd').format(current);
          map[dateStr] = {
            'type': isFerie ? 'ferie' : 'garde',
            'isFerie': isFerie,
          };
          current = current.add(const Duration(days: 1));
        }
      } catch (_) {}
    }
    return map;
  }

  List<dynamic> _getCurrentMonthGardes() {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    final list = _gardesData.where((garde) {
      try {
        final startRaw = garde['date_debut']?.toString();
        final endRaw = garde['date_fin']?.toString();
        if (startRaw == null || endRaw == null) return false;

        final start = DateTime.parse(startRaw);
        final end = DateTime.parse(endRaw);

        return !start.isAfter(monthEnd) && !end.isBefore(monthStart);
      } catch (_) {
        return false;
      }
    }).toList();

    list.sort((a, b) {
      final sA = a['date_debut']?.toString() ?? '';
      final sB = b['date_debut']?.toString() ?? '';
      return sA.compareTo(sB);
    });

    return list;
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

  @override
  Widget build(BuildContext context) {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final daysInMonth = _getDaysInMonth(year, month);
    final firstDayOffset = _getFirstDayOfMonth(year, month);
    final gardesMap = _getGardesMap();
    final currentMonthGardes = _getCurrentMonthGardes();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ─── TOP BAR AVEC BOUTON RETOUR ───
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
                child: Align(
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.undo2, size: 16, color: Color(0xFF22C55E)),
                          SizedBox(width: 6),
                          Text(
                            'Retour',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ─── TITRE ET BOUTON IMPRIMER ───
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  children: [
                    // Bouton rouge Imprimer tableau de garde (identique React .cg-btn-print)
                    InkWell(
                      onTap: _handleDownloadPdf,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.printer, color: Colors.white, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Imprimer tableau de garde',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
                    const SizedBox(height: 14),

                    // Titre: Calendrier des gardes
                    const Text(
                      'Calendrier des gardes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _kNavy,
                        letterSpacing: -0.2,
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 350.ms, delay: 50.ms)
                        .slideY(begin: 0.1, end: 0),
                  ],
                ),
              ),

              // ─── CARTE BLANCHE DU CALENDRIER (.cg-card) ───
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: const BoxConstraints(maxWidth: 440),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF244082).withValues(alpha: 0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // En-tête de navigation du mois (< MOIS ANNEE >)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Bouton Précédent
                        InkWell(
                          onTap: _onPrevMonth,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.chevronLeft, size: 20, color: Color(0xFF4B5563)),
                          ),
                        ),

                        // Titre Mois & Année
                        Text(
                          '${_monthNames[month - 1]} $year',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _kNavy,
                            letterSpacing: 1.0,
                          ),
                        ),

                        // Bouton Suivant
                        InkWell(
                          onTap: _onNextMonth,
                          borderRadius: BorderRadius.circular(18),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(LucideIcons.chevronRight, size: 20, color: Color(0xFF4B5563)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // En-têtes des jours de la semaine (D L M M J V S)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 0,
                        crossAxisSpacing: 4,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        return Center(
                          child: Text(
                            _dayNames[index],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),

                    // Grille des jours
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(
                          child: CircularProgressIndicator(color: _kGreen),
                        ),
                      )
                    else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 4,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: firstDayOffset + daysInMonth,
                        itemBuilder: (context, index) {
                          if (index < firstDayOffset) {
                            return const SizedBox(width: 40, height: 40);
                          }
                          final day = index - firstDayOffset + 1;
                          final dateStr =
                              '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                          final event = gardesMap[dateStr];
                          final isToday = now.year == year && now.month == month && now.day == day;

                          final bool isFerie = event != null && event['type'] == 'ferie';
                          final bool isGarde = event != null && event['type'] == 'garde';

                          // Styles exacts React
                          Color? bgColor;
                          Color textColor = const Color(0xFF4B5563);
                          Border? border;
                          List<BoxShadow>? shadows;

                          if (isFerie) {
                            bgColor = _kOrange;
                            textColor = Colors.white;
                            shadows = [
                              BoxShadow(
                                color: const Color(0xFFDB712A).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ];
                          } else if (isGarde) {
                            bgColor = _kGreen;
                            textColor = Colors.white;
                            shadows = [
                              BoxShadow(
                                color: const Color(0xFF71A246).withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ];
                          } else if (isToday) {
                            bgColor = const Color(0xFFE0EFD6);
                            textColor = _kGreen;
                            border = Border.all(color: const Color(0xFFC3E2AF), width: 1.0);
                          }

                          return Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: bgColor,
                                shape: BoxShape.circle,
                                border: border,
                                boxShadow: shadows,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                day.toString(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13.5,
                                  fontWeight: (isGarde || isFerie || isToday)
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 20),

                    // ─── LISTE DES ÉVÉNEMENTS DU MOIS (.cg-events-list) ───
                    if (currentMonthGardes.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: currentMonthGardes.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final item = currentMonthGardes[i];
                          final isFerie = item['isFerie'] == true ||
                              item['is_ferie'] == 1 ||
                              item['is_ferie'] == true ||
                              item['type'] == 'ferie';

                          String dateDisplay = '';
                          try {
                            final startStr = item['date_debut']?.toString() ?? '';
                            final endStr = item['date_fin']?.toString() ?? '';
                            final start = DateTime.parse(startStr);
                            final end = DateTime.parse(endStr);
                            final formatter = DateFormat('d MMM', 'fr_FR');

                            if (isFerie) {
                              dateDisplay = formatter.format(start);
                            } else {
                              dateDisplay = '${formatter.format(start)} - ${formatter.format(end)}';
                            }
                          } catch (_) {
                            dateDisplay = '${item['date_debut'] ?? ''}';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF3F4F6)),
                            ),
                            child: Row(
                              children: [
                                // Marqueur vertical (.cg-event-marker / .cg-event-marker-jour)
                                Container(
                                  width: 6,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isFerie ? _kOrange : _kGreen,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Détails Titre et Date
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isFerie ? 'Jour Férié' : 'Gardes',
                                        style: const TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: _kNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        dateDisplay,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else if (!_isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Aucune garde pour ce mois',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 100.ms)
                  .scale(begin: const Offset(0.96, 0.96), end: const Offset(1, 1), curve: Curves.easeOutBack),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 0,
        onTap: _onBottomNavTapped,
      ),
    );
  }
}

// Alias de classe pour correspondre exactement à la demande
typedef ScreenClandrierDeGardePharmacien = ScreenCalendrierDeGardePharmacien;
typedef CalendarGardesScreen = ScreenCalendrierDeGardePharmacien;
