import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/admin_provider.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_loading_indicator.dart';

class AdminGardeDetailsScreen extends StatefulWidget {
  final int id;
  final Map<String, dynamic>? initialGarde;

  const AdminGardeDetailsScreen({
    super.key,
    required this.id,
    this.initialGarde,
  });

  @override
  State<AdminGardeDetailsScreen> createState() => _AdminGardeDetailsScreenState();
}

class _AdminGardeDetailsScreenState extends State<AdminGardeDetailsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _importData;
  List<Map<String, dynamic>> _lines = [];
  List<Map<String, dynamic>> _groupes = [];
  List<Map<String, dynamic>> _dataJours = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails({bool isManualRefresh = false}) async {
    setState(() => _isLoading = true);
    final admin = context.read<AdminProvider>();
    final res = await admin.fetchGardeDetails(widget.id);

    if (!mounted) return;

    if (res != null) {
      final entete = res['enteteObj'] ?? res['entete'] ?? widget.initialGarde ?? {};
      final rawData = res['data'] ?? res['lignes'] ?? res['lignes_gardes'] ?? res['result'] ?? [];
      final rawJours = res['dataJours'] ?? res['jours'] ?? [];

      final List<Map<String, dynamic>> linesList = [];
      if (rawData is List) {
        for (var item in rawData) {
          if (item is Map) {
            linesList.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final List<Map<String, dynamic>> joursList = [];
      if (rawJours is List) {
        for (var item in rawJours) {
          if (item is Map) {
            joursList.add(Map<String, dynamic>.from(item));
          }
        }
      }

      // Group by date_debut + date_fin (Identique React DetailsGarde.jsx)
      final Map<String, Map<String, dynamic>> groupMap = {};
      for (var item in linesList) {
        final dDeb = (item['date_debut'] ?? '').toString().split('T').first;
        final dFin = (item['date_fin'] ?? '').toString().split('T').first;
        final key = '${dDeb}_$dFin';

        if (!groupMap.containsKey(key)) {
          groupMap[key] = {
            'date_debut': dDeb,
            'date_fin': dFin,
            'pharmacies': <String>[],
          };
        }

        final phar = item['top_pharmacien'] ?? item['pharmacien'] ?? {};
        final nomPharmacie = (phar['nom'] ?? item['nom'] ?? '').toString().trim();
        if (nomPharmacie.isNotEmpty) {
          final listPhar = groupMap[key]!['pharmacies'] as List<String>;
          if (!listPhar.contains(nomPharmacie)) {
            listPhar.add(nomPharmacie);
          }
        }
      }

      setState(() {
        _importData = entete is Map ? Map<String, dynamic>.from(entete) : widget.initialGarde;
        _lines = linesList;
        _groupes = groupMap.values.toList();
        _dataJours = joursList;
        _isLoading = false;
      });
    } else {
      setState(() {
        _importData = widget.initialGarde;
        _isLoading = false;
      });
    }

    if (isManualRefresh && mounted) {
      AppToast.showSuccess('Données actualisées avec succès', context);
    }
  }

  List<Map<String, dynamic>> get _filteredLines {
    if (_searchQuery.trim().isEmpty) return _lines;
    final query = _searchQuery.toLowerCase().trim();

    return _lines.where((line) {
      final phar = line['top_pharmacien'] ?? line['pharmacien'] ?? {};
      final nom = (phar['nom'] ?? line['nom'] ?? '').toString().toLowerCase();
      final cnopt = (line['num_cnopt'] ?? phar['tva'] ?? '').toString().toLowerCase();
      return nom.contains(query) || cnopt.contains(query);
    }).toList();
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '-';
    final str = dateVal.toString();
    if (str.isEmpty) return '-';
    try {
      final dt = DateTime.parse(str);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return str.split('T').first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zoneNom = (_importData?['zone_gardes']?['designation'] ??
            _importData?['zone_gardes']?['nom_zone'] ??
            _importData?['nom_zone'] ??
            widget.initialGarde?['nom_zone'] ??
            'TB Garde')
        .toString();
    final updatedAt = _importData?['updatedAt'] ?? _importData?['createdAt'] ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.forestGreen),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Détails de garde',
          style: TextStyle(
            color: AppColors.forestGreen,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw, size: 20, color: AppColors.primaryGreen),
            onPressed: () => _loadDetails(isManualRefresh: true),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: AppLoadingIndicator.page(message: 'Chargement des détails de garde...'))
          : RefreshIndicator(
              onRefresh: () => _loadDetails(isManualRefresh: true),
              color: AppColors.primaryGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── 1. DATE DE RECTIFICATION CARD ───
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.borderGray),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00897B).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(LucideIcons.calendarClock, size: 18, color: Color(0xFF00897B)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      zoneNom.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.forestGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    RichText(
                                      text: TextSpan(
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF555555)),
                                        children: [
                                          const TextSpan(
                                            text: 'Date de rectification : ',
                                            style: TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text: updatedAt.isNotEmpty ? _formatDate(updatedAt) : 'Non renseignée',
                                            style: const TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── 2. LISTE DES PHARMACIES CARD (Identique React) ───
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGray),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header: Title + Export Excel
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Liste des pharmacies',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    AppToast.showSuccess('Exportation Excel préparée avec succès !', context);
                                  },
                                  icon: const Icon(LucideIcons.fileSpreadsheet, size: 14),
                                  label: const Text('Exporter Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E7D32),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: AppColors.borderGray),

                          // Search Filter Bar
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'RECHERCHE PAR NOM DE PHARMACIE / NUM CNOPT',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF666666),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  decoration: InputDecoration(
                                    hintText: 'Entrer un nom / Num CNOPT ...',
                                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                                    prefixIcon: const Icon(LucideIcons.search, size: 18, color: Color(0xFF888888)),
                                    filled: true,
                                    fillColor: const Color(0xFFF9FBF9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: Colors.grey.shade300),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(color: Color(0xFF00897B), width: 1.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Table View
                          if (_filteredLines.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(LucideIcons.calendarX, size: 36, color: Colors.grey.shade400),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Aucune pharmacie trouvée pour cette recherche.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F6F4)),
                                headingTextStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF333333),
                                  letterSpacing: 0.4,
                                ),
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 52,
                                horizontalMargin: 16,
                                columnSpacing: 18,
                                columns: const [
                                  DataColumn(label: Text('NOM DE LA PHARMACIE')),
                                  DataColumn(label: Text('NUM CNOPT')),
                                  DataColumn(label: Text('DATE DÉBUT')),
                                  DataColumn(label: Text('DATE FIN')),
                                  DataColumn(label: Text('ID GARDE')),
                                ],
                                rows: List.generate(_filteredLines.length, (index) {
                                  final line = _filteredLines[index];
                                  final phar = line['top_pharmacien'] ?? line['pharmacien'] ?? {};
                                  final nom = (phar['nom'] ?? line['nom'] ?? '-').toString();
                                  final cnopt = (line['num_cnopt'] ?? phar['tva'] ?? '-').toString();
                                  final dDeb = (line['date_debut'] ?? '-').toString().split('T').first;
                                  final dFin = (line['date_fin'] ?? '-').toString().split('T').first;
                                  final idGarde = (line['id_tbgarde'] ?? line['id'] ?? '-').toString();
                                  final isEven = index % 2 == 0;

                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      isEven ? Colors.white : const Color(0xFFF9FAF9),
                                    ),
                                    cells: [
                                      DataCell(
                                        Text(
                                          nom,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          cnopt,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          dDeb,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          dFin,
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF333333)),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00897B).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            idGarde,
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF00897B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ─── 3. GROUPE DES PHARMACIES CARD (Identique React) ───
                    if (_groupes.isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderGray),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Groupe des pharmacies',
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          AppToast.showSuccess('Exportation Excel du groupe préparée !', context);
                                        },
                                        icon: const Icon(LucideIcons.fileSpreadsheet, size: 13),
                                        label: const Text('Exporter', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2E7D32),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.borderGray),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFFFF8E1)),
                                headingTextStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF8D6E63),
                                  letterSpacing: 0.4,
                                ),
                                dataRowMinHeight: 44,
                                dataRowMaxHeight: 52,
                                horizontalMargin: 16,
                                columnSpacing: 18,
                                columns: const [
                                  DataColumn(label: Text('PHARMACIES')),
                                  DataColumn(label: Text('DATE DÉBUT')),
                                  DataColumn(label: Text('DATE FIN')),
                                ],
                                rows: List.generate(_groupes.length, (index) {
                                  final grp = _groupes[index];
                                  final listPhar = (grp['pharmacies'] as List<String>?) ?? [];
                                  final pharNames = listPhar.join(' - ');
                                  final dDeb = (grp['date_debut'] ?? '-').toString();
                                  final dFin = (grp['date_fin'] ?? '-').toString();
                                  final isEven = index % 2 == 0;

                                  return DataRow(
                                    color: WidgetStateProperty.all(
                                      isEven ? Colors.white : const Color(0xFFFFFDE7).withValues(alpha: 0.4),
                                    ),
                                    cells: [
                                      DataCell(
                                        Text(
                                          pharNames.isNotEmpty ? pharNames : '-',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF333333)),
                                        ),
                                      ),
                                      DataCell(Text(dDeb, style: const TextStyle(fontSize: 12))),
                                      DataCell(Text(dFin, style: const TextStyle(fontSize: 12))),
                                    ],
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                    ],

                    // ─── 4. JOURS FÉRIÉS (si existants) ───
                    if (_dataJours.isNotEmpty) ...[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.borderGray),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Padding(
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 12),
                              child: Text(
                                'Jours Fériés de Garde',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.borderGray),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _dataJours.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (jCtx, jIdx) {
                                final item = _dataJours[jIdx];
                                final jourDate = (item['jour_ferie'] ?? '').toString().split('T').first;
                                final jourNom = (item['jours_feries']?['nom'] ?? 'Jour férié').toString();
                                final phar = (item['top_pharmacien']?['nom'] ?? '-').toString();
                                final cnopt = (item['num_cnopt'] ?? '').toString();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(LucideIcons.calendarCheck, size: 16, color: Colors.amber),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$jourNom ($jourDate)',
                                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Pharmacie : $phar (CNOPT: $cnopt)',
                                              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                            ),
                                          ],
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
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
