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
import '../../../shared/widgets/wave_clipper.dart';

class CalendarGardesScreen extends StatefulWidget {
  const CalendarGardesScreen({super.key});

  @override
  State<CalendarGardesScreen> createState() => _CalendarGardesScreenState();
}

class _CalendarGardesScreenState extends State<CalendarGardesScreen> {
  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate;
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

  static const List<String> _dayNames = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
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
    final idTbGarde = user?.idGarde ?? user?.id;

    if (idTbGarde == null) {
      AppToast.showError('Zone de garde non trouvée', context);
      return;
    }

    try {
      final pdfUrl = '${AppConstants.backBaseUrl}garde/getPdf/$idTbGarde';
      final uri = Uri.parse(pdfUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (mounted) {
          context.read<GardeProvider>().logPdfDownloadHistory();
        }
      } else {
        if (mounted) {
          AppToast.showError('Impossible d\'ouvrir le fichier PDF', context);
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
    return weekday == 7 ? 0 : weekday;
  }

  Set<String> _getGardeDateStrings() {
    final set = <String>{};
    for (final garde in _gardesData) {
      try {
        final startRaw = garde['date_debut']?.toString();
        final endRaw = garde['date_fin']?.toString();
        if (startRaw == null || endRaw == null) continue;

        DateTime current = DateTime.parse(startRaw);
        final end = DateTime.parse(endRaw);

        while (!current.isAfter(end)) {
          final dateStr = DateFormat('yyyy-MM-dd').format(current);
          set.add(dateStr);
          current = current.add(const Duration(days: 1));
        }
      } catch (_) {}
    }
    return set;
  }

  List<dynamic> _getCurrentMonthGardes() {
    final year = _currentDate.year;
    final month = _currentDate.month;
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    return _gardesData.where((garde) {
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
    }).toList()
      ..sort((a, b) {
        final sA = a['date_debut']?.toString() ?? '';
        final sB = b['date_debut']?.toString() ?? '';
        return sA.compareTo(sB);
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();

    final year = _currentDate.year;
    final month = _currentDate.month;
    final daysInMonth = _getDaysInMonth(year, month);
    final firstDayOffset = _getFirstDayOfMonth(year, month);
    final gardeDates = _getGardeDateStrings();
    final currentMonthGardes = _getCurrentMonthGardes();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER MODERNE ───
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

                  // Decorative glowing circle
                  Positioned(
                    top: -30,
                    right: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withValues(alpha: 0.10),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.only(top: topPadding + 14, bottom: 26, left: 18, right: 18),
                    child: Column(
                      children: [
                        // Top bar: Back Button & PDF Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Back Button
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

                            // Imprimer tableau de garde Button
                            InkWell(
                              onTap: _handleDownloadPdf,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.printer, color: Colors.white, size: 15),
                                    SizedBox(width: 7),
                                    Text(
                                      'Tableau de garde',
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
                        const SizedBox(height: 16),

                        // Title & Subtitle Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.calendarDays, size: 14, color: AppColors.primaryGreen),
                              SizedBox(width: 6),
                              Text(
                                'Planning officiel CNOPT',
                                style: TextStyle(
                                  color: Color(0xFF4B6A3A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Calendrier des gardes',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                            letterSpacing: -0.3,
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
                      size: const Size(double.infinity, 20),
                      painter: WavePainter(),
                    ),
                  ),
                ],
              ),
            ),

            // ─── CORPS DU CALENDRIER ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              child: Column(
                children: [
                  // ─── CARTE PRINCIPALE CALENDRIER ───
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.07),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Month & Year Navigation Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                onPressed: _onPrevMonth,
                                icon: const Icon(LucideIcons.chevronLeft, color: Color(0xFF475569), size: 20),
                                splashRadius: 18,
                              ),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${_monthNames[month - 1]} $year',
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF1E293B),
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: _onNextMonth,
                                icon: const Icon(LucideIcons.chevronRight, color: Color(0xFF475569), size: 20),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Day Names Chips (Dim Lun Mar Mer Jeu Ven Sam)
                        Row(
                          children: _dayNames.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final d = entry.value;
                            final isWeekend = idx == 0 || idx == 6;
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                decoration: BoxDecoration(
                                  color: isWeekend
                                      ? const Color(0xFFFEF2F2).withValues(alpha: 0.6)
                                      : const Color(0xFFF1F5F9).withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    d,
                                    style: TextStyle(
                                      color: isWeekend ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Calendar Days Grid
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: CircularProgressIndicator(color: AppColors.primaryGreen),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 7,
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 6,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: firstDayOffset + daysInMonth,
                            itemBuilder: (context, index) {
                              if (index < firstDayOffset) {
                                return const SizedBox.shrink();
                              }
                              final day = index - firstDayOffset + 1;
                              final dateStr =
                                  '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                              final isGarde = gardeDates.contains(dateStr);
                              final isToday = now.year == year && now.month == month && now.day == day;
                              final isSelected = _selectedDate != null &&
                                  _selectedDate!.year == year &&
                                  _selectedDate!.month == month &&
                                  _selectedDate!.day == day;

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    _selectedDate = DateTime(year, month, day);
                                  });
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    gradient: isGarde
                                        ? const LinearGradient(
                                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : null,
                                    color: isGarde
                                        ? null
                                        : isToday
                                            ? const Color(0xFFECFDF5)
                                            : isSelected
                                                ? const Color(0xFFF1F5F9)
                                                : Colors.transparent,
                                    borderRadius: BorderRadius.circular(14),
                                    border: isGarde
                                        ? (isSelected
                                            ? Border.all(color: Colors.white, width: 2)
                                            : null)
                                        : isToday
                                            ? Border.all(color: const Color(0xFF86EFAC), width: 1.5)
                                            : isSelected
                                                ? Border.all(color: const Color(0xFFCBD5E1), width: 1.5)
                                                : null,
                                    boxShadow: isGarde
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(
                                        day.toString(),
                                        style: TextStyle(
                                          color: isGarde
                                              ? Colors.white
                                              : isToday
                                                  ? const Color(0xFF15803D)
                                                  : isSelected
                                                      ? const Color(0xFF0F172A)
                                                      : const Color(0xFF475569),
                                          fontSize: 13,
                                          fontWeight: isGarde || isToday || isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      if (isGarde)
                                        Positioned(
                                          bottom: 3,
                                          child: Container(
                                            width: 4,
                                            height: 4,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 18),

                        // Légende rapide
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Garde active',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Aujourd\'hui',
                                    style: TextStyle(fontSize: 11.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms)
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), curve: Curves.easeOutBack),
                  const SizedBox(height: 18),

                  // ─── RÉCAPITULATIF DES GARDES DU MOIS ───
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 10),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.listOrdered, size: 18, color: AppColors.forestGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Périodes de garde (${currentMonthGardes.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (currentMonthGardes.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentMonthGardes.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final item = currentMonthGardes[i];
                        final startStr = item['date_debut']?.toString() ?? '';
                        final endStr = item['date_fin']?.toString() ?? '';

                        String dateRange = '';
                        int totalDays = 1;
                        try {
                          final start = DateTime.parse(startStr);
                          final end = DateTime.parse(endStr);
                          totalDays = end.difference(start).inDays + 1;
                          final formatter = DateFormat('d MMM yyyy', 'fr_FR');
                          dateRange = '${formatter.format(start)} → ${formatter.format(end)}';
                        } catch (_) {
                          dateRange = '$startStr → $endStr';
                        }

                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          'Service de garde',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: Text(
                                            '$totalDays j',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF059669),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      dateRange,
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(LucideIcons.chevronRight, size: 18, color: Color(0xFFCBD5E1)),
                            ],
                          ),
                        )
                            .animate()
                            .fadeIn(duration: 350.ms, delay: (150 + i * 50).ms)
                            .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
                      },
                    )
                  else if (!_isLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Column(
                        children: [
                          Icon(LucideIcons.calendarX2, size: 36, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text(
                            'Aucune garde programmée pour ce mois',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
}
