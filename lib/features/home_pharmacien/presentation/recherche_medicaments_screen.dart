import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/medicament_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/storage/storage_service.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import '../../../shared/widgets/wave_clipper.dart';

class RechercheMedicamentsScreen extends StatefulWidget {
  const RechercheMedicamentsScreen({super.key});

  @override
  State<RechercheMedicamentsScreen> createState() => _RechercheMedicamentsScreenState();
}

class _RechercheMedicamentsScreenState extends State<RechercheMedicamentsScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF558332);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  // Form State
  OptionItem? _selectedMedicament;
  OptionItem? _selectedGouvernorat;
  OptionItem? _selectedZone;
  int _selectedType = 1; // 1: Rupture, 2: Échange
  final List<GrossisteItem> _selectedGrossistes = [];
  DateTime? _selectedDateExpiration;

  // Selected grossiste per demande item { demandeId: GrossisteItem }
  final Map<int, GrossisteItem> _demandeSelectedGrossiste = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final medProvider = context.read<MedicamentProvider>();
      medProvider.fetchDemandes();
      medProvider.fetchAllOptions();
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
        title: const Text('Déconnexion', style: TextStyle(fontWeight: FontWeight.w800, color: _navy)),
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

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours} h";
    if (diff.inDays < 7) return "Il y a ${diff.inDays} j";
    return DateFormat('dd/MM/yyyy').format(date);
  }

  void _showConfirmActionDialog(DemandeMedicamentItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.circleAlert, color: _green, size: 24),
            SizedBox(width: 8),
            Text('Êtes-vous sûr ?', style: TextStyle(fontWeight: FontWeight.w800, color: _navy, fontSize: 18)),
          ],
        ),
        content: Text(
          item.type == 2
              ? 'Voulez-vous accepter cet échange pour "${item.produit}" ?'
              : 'Voulez-vous vraiment marquer "${item.produit}" comme disponible ?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final idGrossiste = _demandeSelectedGrossiste[item.id]?.id;
              final ok = await context.read<MedicamentProvider>().updateDemande(
                    id: item.id,
                    users: item.rawUser,
                    produit: item.produit ?? 'Médicament',
                    idGrossiste: idGrossiste,
                  );
              if (mounted) {
                if (ok) {
                  AppToast.showSuccess('Demande mise à jour avec succès !', context);
                } else {
                  AppToast.showError('Échec de la mise à jour.', context);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(item.type == 2 ? 'Oui, accepter' : 'Oui, disponible !',
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showMedicamentSelectorModal() {
    final searchCtrl = TextEditingController();
    String currentQuery = '';

    // If medicaments are not yet loaded, trigger fetch immediately
    final provider = context.read<MedicamentProvider>();
    if (provider.medicaments.isEmpty) {
      provider.fetchMedicaments();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Consumer<MedicamentProvider>(
            builder: (context, medProvider, _) {
              final allMeds = medProvider.medicaments;
              final filtered = currentQuery.isEmpty
                  ? allMeds
                  : allMeds
                      .where((m) => m.label.toLowerCase().contains(currentQuery.toLowerCase()))
                      .toList();

              return Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Sélectionner un médicament',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: searchCtrl,
                          onChanged: (q) {
                            setModalState(() {
                              currentQuery = q.trim();
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'Rechercher un médicament…',
                            hintStyle: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            prefixIcon: Icon(LucideIcons.search, size: 18, color: _green),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: medProvider.isLoadingMedicaments && allMeds.isEmpty
                          ? const Center(
                              child: AppLoadingIndicator.page(message: 'Chargement des médicaments…'),
                            )
                          : filtered.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.packageX, size: 36, color: Color(0xFFCBD5E1)),
                                      const SizedBox(height: 10),
                                      Text(
                                        currentQuery.isEmpty ? 'Aucun médicament disponible.' : 'Aucun médicament trouvé pour "$currentQuery".',
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  itemBuilder: (c, i) {
                                    final item = filtered[i];
                                    final isSelected = _selectedMedicament?.value == item.value;
                                    return ListTile(
                                      leading: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected ? _green.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(LucideIcons.pill, color: isSelected ? _green : const Color(0xFF64748B), size: 18),
                                      ),
                                      title: Text(
                                        item.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? _green : _navy,
                                        ),
                                      ),
                                      trailing: isSelected ? const Icon(LucideIcons.check, color: _green, size: 18) : null,
                                      onTap: () {
                                        setState(() => _selectedMedicament = item);
                                        Navigator.pop(modalCtx);
                                      },
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
      ),
    );
  }

  void _showGrossisteMultiSelector(List<GrossisteItem> allGrossistes) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.65,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sélectionner des grossistes',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _navy),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Terminer', style: TextStyle(color: _green, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: allGrossistes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (c, i) {
                      final item = allGrossistes[i];
                      final isSelected = _selectedGrossistes.any((g) => g.id == item.id);
                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: _green,
                        title: Text(
                          item.nom,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? _navy : const Color(0xFF334155),
                          ),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            if (val == true) {
                              _selectedGrossistes.add(item);
                            } else {
                              _selectedGrossistes.removeWhere((g) => g.id == item.id);
                            }
                          });
                          setState(() {});
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _handleDiffuser() async {
    if (_selectedMedicament == null) {
      AppToast.showInfo('Veuillez sélectionner un médicament.', context);
      return;
    }

    if (_selectedGouvernorat == null && _selectedZone == null) {
      AppToast.showInfo('Veuillez sélectionner un gouvernorat ou une table de garde.', context);
      return;
    }

    if (_selectedType == 2 && _selectedGrossistes.isEmpty) {
      AppToast.showInfo('Veuillez sélectionner au moins un grossiste pour un échange.', context);
      return;
    }

    final dateStr = _selectedDateExpiration != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDateExpiration!)
        : null;

    final grossisteIds = _selectedGrossistes.map((g) => g.id).toList();

    final ok = await context.read<MedicamentProvider>().addDemande(
          idMedicament: _selectedMedicament!.value,
          idGouvernorat: _selectedGouvernorat?.value,
          idTbgarde: _selectedZone?.value,
          type: _selectedType,
          dateExpiration: dateStr,
          grossistes: grossisteIds,
        );

    if (mounted) {
      if (ok) {
        AppToast.showSuccess('Disponibilité diffusée avec succès !', context);
        setState(() {
          _selectedMedicament = null;
          _selectedGouvernorat = null;
          _selectedZone = null;
          _selectedType = 1;
          _selectedGrossistes.clear();
          _selectedDateExpiration = null;
        });
      } else {
        AppToast.showError('Échec de la diffusion.', context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final auth = context.watch<AuthProvider>();
    final medProvider = context.watch<MedicamentProvider>();
    final currentUser = StorageService.getUser();
    final currentUserId = currentUser?.id;
    final currentUserRole = currentUser?.idRole ?? 2;

    return Scaffold(
      backgroundColor: _bgGrey,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── HERO HEADER (Identique React RechercheMedicaments.jsx) ───
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
                        // Top Bar: Back Button
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

                        // Green Pill Icon Badge
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_green, _greenDark],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _green.withValues(alpha: 0.40),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(LucideIcons.pill, color: Colors.white, size: 28),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text(
                          'Recherche de médicament',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Échanges & Disponibilités entre pharmaciens',
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

            // ─── CONTENT BODY ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Column(
                children: [
                  // ═══ CARD 1: DEMANDES À PROXIMITÉ ═══
                  Container(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                          ),
                          child: const Row(
                            children: [
                              Icon(LucideIcons.mapPin, size: 18, color: _green),
                              SizedBox(width: 8),
                              Text(
                                'DEMANDES À PROXIMITÉ',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Card Body
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: medProvider.isLoadingDemandes
                              ? const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 36),
                                  child: Center(
                                    child: AppLoadingIndicator.page(message: 'Chargement des demandes…'),
                                  ),
                                )
                              : medProvider.demandes.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                                      child: Center(
                                        child: Text(
                                          'Aucune demande disponible.',
                                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 13.5, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: medProvider.demandes.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (ctx, i) {
                                        final item = medProvider.demandes[i];
                                        final isOwnRequest = item.idPharmacien == currentUserId;
                                        final isUpdating = medProvider.updatingId == item.id;

                                        return Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFAFAFA),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: const Color(0xFFE5E7EB)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Medicine thumbnail / icon
                                                  Container(
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      color: _green.withValues(alpha: 0.12),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: item.image != null && item.image!.isNotEmpty
                                                        ? ClipRRect(
                                                            borderRadius: BorderRadius.circular(12),
                                                            child: Image.network(
                                                              item.image!,
                                                              fit: BoxFit.cover,
                                                              errorBuilder: (_, __, ___) =>
                                                                  const Icon(LucideIcons.pill, color: _green, size: 24),
                                                            ),
                                                          )
                                                        : const Icon(LucideIcons.pill, color: _green, size: 24),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // Details
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          item.produit ?? 'Médicament',
                                                          style: const TextStyle(
                                                            fontSize: 14.5,
                                                            fontWeight: FontWeight.w800,
                                                            color: _navy,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          'Pharmacien : ${item.pharmacienNom ?? "Inconnu"}',
                                                          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                                                        ),
                                                        const SizedBox(height: 2),
                                                        Text(
                                                          _formatTimeAgo(item.createdAt),
                                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
                                                        ),
                                                        if (item.type == 2) ...[
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Date de péremption : ${item.dateExpiration ?? "Non renseignée"}',
                                                            style: const TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w700,
                                                              color: _navy,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              // Actions / Grossiste selector
                                              if (!isOwnRequest) ...[
                                                const SizedBox(height: 10),
                                                if (item.type == 2 && item.grossistes.isNotEmpty) ...[
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                                    ),
                                                    child: DropdownButtonHideUnderline(
                                                      child: DropdownButton<GrossisteItem>(
                                                        value: _demandeSelectedGrossiste[item.id],
                                                        hint: const Text('Choisir un grossiste', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
                                                        isExpanded: true,
                                                        icon: const Icon(LucideIcons.chevronDown, size: 16, color: _green),
                                                        items: item.grossistes.map((g) {
                                                          return DropdownMenuItem(
                                                            value: g,
                                                            child: Text(g.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                                          );
                                                        }).toList(),
                                                        onChanged: (val) {
                                                          if (val != null) {
                                                            setState(() => _demandeSelectedGrossiste[item.id] = val);
                                                          }
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                ],

                                                if (currentUserRole == 2) ...[
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: ElevatedButton(
                                                      onPressed: isUpdating ? null : () => _showConfirmActionDialog(item),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF244082),
                                                        foregroundColor: Colors.white,
                                                        elevation: 0,
                                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                      ),
                                                      child: isUpdating
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                                            )
                                                          : Text(
                                                              item.type == 2 ? 'Accepter' : 'Disponible',
                                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ],
                                          ),
                                        ).animate().fadeIn(duration: 250.ms, delay: Duration(milliseconds: i * 40));
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ═══ CARD 2: AJOUTER UN MÉDICAMENT DISPONIBLE ═══
                  Container(
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ajouter un médicament disponible',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Champ: Médicament *
                        const Text(
                          'MÉDICAMENT *',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _showMedicamentSelectorModal,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                const Icon(LucideIcons.pill, size: 16, color: _green),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _selectedMedicament?.label ?? 'Sélectionner un médicament',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedMedicament != null ? _navy : const Color(0xFF94A3B8),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(LucideIcons.chevronDown, size: 16, color: _green),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Champ: Gouvernorat
                        const Text(
                          'GOUVERNORAT',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<OptionItem>(
                              value: _selectedGouvernorat,
                              hint: const Text('Gouvernorats', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown, size: 18, color: _green),
                              items: medProvider.gouvernorats.map((g) {
                                return DropdownMenuItem(
                                  value: g,
                                  child: Text(g.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedGouvernorat = val;
                                  _selectedZone = null;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Champ: TB de garde (Zone)
                        const Text(
                          'TB DE GARDE',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<OptionItem>(
                              value: _selectedZone,
                              hint: const Text('Tb Gardes', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown, size: 18, color: _green),
                              items: medProvider.zones.map((z) {
                                return DropdownMenuItem(
                                  value: z,
                                  child: Text(z.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedZone = val;
                                  _selectedGouvernorat = null;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Champ: Type *
                        const Text(
                          'TYPE *',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedType,
                              isExpanded: true,
                              icon: const Icon(LucideIcons.chevronDown, size: 18, color: _green),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Rupture', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                                DropdownMenuItem(value: 2, child: Text('Échange', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedType = val;
                                    if (val != 2) {
                                      _selectedGrossistes.clear();
                                      _selectedDateExpiration = null;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),

                        // Conditions si Type == 2 (Échange)
                        if (_selectedType == 2) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'GROSSISTES *',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _showGrossisteMultiSelector(medProvider.grossistes),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.truck, size: 16, color: _green),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _selectedGrossistes.isEmpty
                                          ? 'Sélectionner des grossistes'
                                          : _selectedGrossistes.map((g) => g.nom).join(', '),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: _selectedGrossistes.isNotEmpty ? _navy : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(LucideIcons.chevronDown, size: 16, color: _green),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Date d'expiration
                          const Text(
                            "DATE D'EXPIRATION",
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDateExpiration ?? DateTime.now().add(const Duration(days: 30)),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                              );
                              if (picked != null) {
                                setState(() => _selectedDateExpiration = picked);
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
                                children: [
                                  const Icon(LucideIcons.calendar, size: 16, color: _green),
                                  const SizedBox(width: 10),
                                  Text(
                                    _selectedDateExpiration != null
                                        ? DateFormat('dd/MM/yyyy').format(_selectedDateExpiration!)
                                        : 'Sélectionner la date',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _selectedDateExpiration != null ? _navy : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),

                        // Bouton Diffuser
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: medProvider.isSubmitting ? null : _handleDiffuser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: medProvider.isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Diffuser la disponibilité',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            'Votre disponibilité sera visible pendant 24h.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
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
