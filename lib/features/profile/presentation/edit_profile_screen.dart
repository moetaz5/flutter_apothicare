import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/wave_clipper.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel? user;
  const EditProfileScreen({super.key, this.user});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _navy = Color(0xFF163820);
  static const Color _green = Color(0xFF71A246);
  static const Color _greenDark = Color(0xFF5D8A38);
  static const Color _bgGrey = Color(0xFFF0F4F8);

  late TextEditingController _nomController;
  late TextEditingController _nomArController;
  late TextEditingController _numCnoptController;
  late TextEditingController _loginController;
  late TextEditingController _emailController;
  late TextEditingController _telController;
  late TextEditingController _tel2Controller;
  late TextEditingController _adresseController;
  late TextEditingController _adresseArController;
  final TextEditingController _passwordController = TextEditingController();

  // Dropdown selections
  int? _selectedGouvernoratId;
  String? _selectedGouvernoratNom;
  String? _selectedDelegation;
  int? _selectedZoneId;
  String? _selectedZoneNom;

  // Reference lists
  List<Map<String, dynamic>> _gouvernorats = [];
  List<Map<String, dynamic>> _delegations = [];
  List<Map<String, dynamic>> _zones = [];
  List<Map<String, dynamic>> _services = [];
  final Set<int> _selectedServiceIds = {};

  bool _isLoadingData = true;
  bool _isSaving = false;
  bool _showPassword = false;
  bool _isMapEditable = false;
  LatLng? _selectedPosition;

  @override
  void initState() {
    super.initState();
    final u = widget.user ?? context.read<AuthProvider>().currentUser;
    _nomController = TextEditingController(text: u?.nom ?? '');
    _nomArController = TextEditingController(text: u?.nomAr ?? '');
    _numCnoptController = TextEditingController(text: u?.numCnopt ?? '');
    _loginController = TextEditingController(text: u?.login ?? '');
    _emailController = TextEditingController(text: u?.email ?? u?.login ?? '');
    _telController = TextEditingController(text: u?.tel ?? '');
    _tel2Controller = TextEditingController(text: u?.tel2 ?? '');
    _adresseController = TextEditingController(text: u?.adresse ?? '');
    _adresseArController = TextEditingController(text: u?.adresseAr ?? '');

    _selectedGouvernoratId = u?.idGouvernorat;
    _selectedGouvernoratNom = u?.gouvernoratNom;
    _selectedDelegation = u?.delegation;
    _selectedZoneId = u?.idGarde;
    _selectedZoneNom = u?.zoneGardeNom;

    if (u?.services != null) {
      for (final s in u!.services) {
        _selectedServiceIds.add(s.id);
      }
    }

    if (u?.lat != null && u?.lng != null) {
      _selectedPosition = LatLng(u!.lat!, u.lng!);
    } else {
      _selectedPosition = const LatLng(34.7406, 10.7603);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReferenceData(u);
    });
  }

  Future<void> _loadReferenceData(UserModel? user) async {
    final auth = context.read<AuthProvider>();
    try {
      final results = await Future.wait([
        auth.fetchGouvernorats(),
        auth.fetchDelegations(),
        auth.fetchActiveZones(),
        auth.fetchActiveServices(),
      ]);

      if (mounted) {
        setState(() {
          _gouvernorats = results[0];
          _delegations = results[1];
          _zones = results[2];
          _services = results[3];

          // Set default labels if IDs exist
          if (_selectedGouvernoratId != null && _selectedGouvernoratNom == null) {
            final found = _gouvernorats.firstWhere(
              (g) => g['id'] == _selectedGouvernoratId,
              orElse: () => {},
            );
            if (found.isNotEmpty) _selectedGouvernoratNom = found['nom']?.toString();
          }

          if (_selectedZoneId != null && _selectedZoneNom == null) {
            final found = _zones.firstWhere(
              (z) => z['id'] == _selectedZoneId,
              orElse: () => {},
            );
            if (found.isNotEmpty) _selectedZoneNom = found['designation']?.toString() ?? found['nom']?.toString();
          }

          // Fallback default services if list from API is empty
          if (_services.isEmpty) {
            _services = [
              {'id': 1, 'nom': "Salle d'injection"},
              {'id': 2, 'nom': "Coin para"},
              {'id': 3, 'nom': "Suivi pondéral"},
              {'id': 4, 'nom': "vétérinaire"},
            ];
          }

          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingData = false);
      }
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    _nomArController.dispose();
    _numCnoptController.dispose();
    _loginController.dispose();
    _emailController.dispose();
    _telController.dispose();
    _tel2Controller.dispose();
    _adresseController.dispose();
    _adresseArController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final nom = _nomController.text.trim();
    final email = _emailController.text.trim();
    final login = _loginController.text.trim();

    if (nom.isEmpty || email.isEmpty) {
      AppToast.showError("Le nom et l'email sont obligatoires.", context);
      return;
    }

    setState(() => _isSaving = true);
    final auth = context.read<AuthProvider>();

    try {
      final success = await auth.updatePharmacienDetails(
        nom: nom,
        nomAr: _nomArController.text.trim(),
        numCnopt: _numCnoptController.text.trim(),
        login: login.isNotEmpty ? login : email,
        tel: _telController.text.trim(),
        tel2: _tel2Controller.text.trim(),
        adresse: _adresseController.text.trim(),
        adresseAr: _adresseArController.text.trim(),
        delegation: _selectedDelegation ?? '',
        idGouvernorat: _selectedGouvernoratId,
        idGarde: _selectedZoneId,
        lat: _selectedPosition?.latitude,
        lng: _selectedPosition?.longitude,
        password: _passwordController.text,
        serviceIds: _selectedServiceIds.toList(),
      );

      if (mounted) {
        if (success) {
          AppToast.showSuccess('Informations mises à jour avec succès !', context);
          Navigator.pop(context, true);
        } else {
          AppToast.showError(auth.errorMessage ?? 'Erreur lors de la mise à jour.', context);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError('Erreur lors de la mise à jour.', context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSelectorModal({
    required String title,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelBuilder,
    required dynamic Function(Map<String, dynamic>) valueBuilder,
    required dynamic currentValue,
    required Function(dynamic value, String label) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF6B7280)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final val = valueBuilder(item);
                    final label = labelBuilder(item);
                    final isSelected = val == currentValue;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      title: Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? _green : const Color(0xFF374151),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(LucideIcons.check, color: _green, size: 20)
                          : null,
                      onTap: () {
                        onSelected(val, label);
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _bgGrey,
      body: _isLoadingData
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: _green, strokeWidth: 3),
                  SizedBox(height: 14),
                  Text(
                    'Chargement du formulaire...',
                    style: TextStyle(color: Color(0xFF6B7A99), fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── HERO HEADER (Identique React UserEdit.jsx) ───
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
                          padding: EdgeInsets.only(top: topPadding + 14, bottom: 26, left: 16, right: 16),
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
                              const SizedBox(height: 12),

                              // Edit Pencil Icon Badge
                              Container(
                                width: 60,
                                height: 60,
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
                                  child: Icon(LucideIcons.pencil, color: Colors.white, size: 28),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Title
                              const Text(
                                "Modifier l'utilisateur",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Mettez à jour vos informations et de votre pharmacie',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
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

                  // ─── FORM CONTENT ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                    child: Column(
                      children: [
                        // Section 1: Mes informations
                        _buildCardSection(
                          icon: LucideIcons.user,
                          title: 'MES INFORMATIONS',
                          children: [
                            _buildInputField(label: 'NOM COMPLET *', controller: _nomController, placeholder: 'Nom complet'),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'NOM COMPLET (AR)', controller: _nomArController, placeholder: 'Nom complet (Arabe)'),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'NUM CNOPT', controller: _numCnoptController, placeholder: 'Numéro CNOPT'),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'IDENTIFIANT', controller: _loginController, placeholder: 'Identifiant'),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'ADRESSE EMAIL *', controller: _emailController, placeholder: 'Email', keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'TÉLÉPHONE PHARMACIE', controller: _telController, placeholder: 'Téléphone', keyboardType: TextInputType.phone),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'TÉLÉPHONE PERSONNEL', controller: _tel2Controller, placeholder: 'Mobile', keyboardType: TextInputType.phone),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 2: Adresse
                        _buildCardSection(
                          icon: LucideIcons.mapPin,
                          title: 'ADRESSE',
                          children: [
                            _buildInputField(label: 'ADRESSE', controller: _adresseController, placeholder: 'Adresse'),
                            const SizedBox(height: 14),
                            _buildInputField(label: 'ADRESSE (AR)', controller: _adresseArController, placeholder: 'Adresse en Arabe'),
                            const SizedBox(height: 14),

                            // GOUVERNORAT SELECT
                            _buildSelectField(
                              label: 'GOUVERNORAT',
                              value: _selectedGouvernoratNom,
                              placeholder: 'Gouvernorat',
                              onTap: () {
                                _showSelectorModal(
                                  title: 'Sélectionner un gouvernorat',
                                  items: _gouvernorats,
                                  labelBuilder: (g) => g['nom']?.toString() ?? '',
                                  valueBuilder: (g) => g['id'],
                                  currentValue: _selectedGouvernoratId,
                                  onSelected: (val, label) {
                                    setState(() {
                                      _selectedGouvernoratId = val as int?;
                                      _selectedGouvernoratNom = label;
                                    });
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  _selectedGouvernoratId = null;
                                  _selectedGouvernoratNom = null;
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            // DÉLÉGATION SELECT
                            _buildSelectField(
                              label: 'DÉLÉGATION',
                              value: _selectedDelegation,
                              placeholder: 'Délégation',
                              onTap: () {
                                _showSelectorModal(
                                  title: 'Sélectionner une délégation',
                                  items: _delegations,
                                  labelBuilder: (d) => d['delegation']?.toString() ?? d['nom']?.toString() ?? '',
                                  valueBuilder: (d) => d['delegation']?.toString() ?? d['nom']?.toString() ?? '',
                                  currentValue: _selectedDelegation,
                                  onSelected: (val, label) {
                                    setState(() {
                                      _selectedDelegation = label;
                                    });
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  _selectedDelegation = null;
                                });
                              },
                            ),
                            const SizedBox(height: 14),

                            // TABLEAU DE GARDE SELECT
                            _buildSelectField(
                              label: 'TABLEAU DE GARDE',
                              value: _selectedZoneNom,
                              placeholder: 'Tableau de garde',
                              onTap: () {
                                _showSelectorModal(
                                  title: 'Sélectionner un tableau de garde',
                                  items: _zones,
                                  labelBuilder: (z) => z['designation']?.toString() ?? z['nom']?.toString() ?? '',
                                  valueBuilder: (z) => z['id'],
                                  currentValue: _selectedZoneId,
                                  onSelected: (val, label) {
                                    setState(() {
                                      _selectedZoneId = val as int?;
                                      _selectedZoneNom = label;
                                    });
                                  },
                                );
                              },
                              onClear: () {
                                setState(() {
                                  _selectedZoneId = null;
                                  _selectedZoneNom = null;
                                });
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 3: Localisation GPS
                        _buildCardSection(
                          icon: LucideIcons.mapPin,
                          title: 'LOCALISATION',
                          action: GestureDetector(
                            onTap: () => setState(() => _isMapEditable = !_isMapEditable),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                              decoration: BoxDecoration(
                                color: _isMapEditable ? const Color(0xFFEF4444) : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isMapEditable ? LucideIcons.lock : LucideIcons.unlock,
                                    size: 13,
                                    color: _isMapEditable ? Colors.white : const Color(0xFF374151),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _isMapEditable ? 'Bloquer GPS' : 'Modifier GPS',
                                    style: TextStyle(
                                      color: _isMapEditable ? Colors.white : const Color(0xFF374151),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          children: [
                            if (_selectedPosition != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 240,
                                  width: double.infinity,
                                  child: GoogleMap(
                                    initialCameraPosition: CameraPosition(target: _selectedPosition!, zoom: 15),
                                    markers: {
                                      Marker(
                                        markerId: const MarkerId('edit_loc'),
                                        position: _selectedPosition!,
                                        draggable: _isMapEditable,
                                        onDragEnd: (newPos) {
                                          if (_isMapEditable) {
                                            setState(() => _selectedPosition = newPos);
                                          }
                                        },
                                      ),
                                    },
                                    onTap: (newPos) {
                                      if (_isMapEditable) {
                                        setState(() => _selectedPosition = newPos);
                                      }
                                    },
                                    scrollGesturesEnabled: _isMapEditable,
                                    zoomGesturesEnabled: _isMapEditable,
                                    rotateGesturesEnabled: _isMapEditable,
                                    myLocationButtonEnabled: false,
                                    zoomControlsEnabled: false,
                                  ),
                                ),
                              )
                            else
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Text('Localisation indisponible', style: TextStyle(color: Color(0xFF9CA3AF))),
                                ),
                              ),
                            if (_isMapEditable)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Touchez la carte ou glissez le repère pour ajuster la position exacte de votre pharmacie.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 4: Services proposés (Identique React .ue-services)
                        _buildCardSection(
                          icon: LucideIcons.settings,
                          title: 'SERVICES PROPOSÉS',
                          children: [
                            if (_services.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text('Aucun service disponible', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                                ),
                              )
                            else
                              Column(
                                children: _services.map((service) {
                                  final sId = service['id'] is int
                                      ? service['id'] as int
                                      : (int.tryParse(service['id']?.toString() ?? '0') ?? 0);
                                  final sNom = service['nom']?.toString() ?? '';
                                  final isChecked = _selectedServiceIds.contains(sId);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        if (isChecked) {
                                          _selectedServiceIds.remove(sId);
                                        } else {
                                          _selectedServiceIds.add(sId);
                                        }
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFAFAFA),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isChecked ? _green : const Color(0xFFF3F4F6),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              color: isChecked ? _green : Colors.white,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: isChecked ? _green : const Color(0xFFD1D5DB),
                                                width: 2,
                                              ),
                                            ),
                                            child: isChecked
                                                ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Text(
                                              sNom,
                                              style: const TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: _navy,
                                              ),
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
                        const SizedBox(height: 18),

                        // Section 5: Sécurité
                        _buildCardSection(
                          icon: LucideIcons.lock,
                          title: 'SÉCURITÉ',
                          children: [
                            const Text(
                              'NOUVEAU MOT DE PASSE (OPTIONNEL)',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                hintText: 'Laisser vide pour ne pas modifier',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                                filled: true,
                                fillColor: const Color(0xFFFAFAFA),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
                                suffixIcon: IconButton(
                                  icon: Icon(_showPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: const Color(0xFF9CA3AF)),
                                  onPressed: () => setState(() => _showPassword = !_showPassword),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Submit Button
                        SizedBox(
                          height: 56,
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _handleSave,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              shadowColor: _green.withValues(alpha: 0.35),
                            ),
                            child: _isSaving
                                ? const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                                      SizedBox(width: 10),
                                      Text('Enregistrement en cours...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                    ],
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(LucideIcons.save, size: 20),
                                      SizedBox(width: 8),
                                      Text('Enregistrer et Appliquer', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
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
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushNamedAndRemoveUntil(context, AppRoutes.homePharmacien, (r) => false);
          } else if (index == 1) {
            Navigator.pushNamed(context, AppRoutes.actualites);
          } else if (index == 2) {
            Navigator.pop(context);
          } else if (index == 3) {
            _showLogoutDialog();
          }
        },
      ),
    );
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
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
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
              backgroundColor: const Color(0xFFEF4444),
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

  Widget _buildCardSection({
    required IconData icon,
    required String title,
    required List<Widget> children,
    Widget? action,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF244082).withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_green, _greenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _navy,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? placeholder,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _navy),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectField({
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final hasValue = value != null && value.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasValue ? value : placeholder,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                      color: hasValue ? _navy : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                if (hasValue && onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(LucideIcons.x, size: 16, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                Container(
                  height: 16,
                  width: 1,
                  color: const Color(0xFFE5E7EB),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronDown, size: 18, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
