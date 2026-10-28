import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/models/garde_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers/auth_provider.dart';

class ServiceImageItem {
  final String type;
  final String filename;

  ServiceImageItem({required this.type, required this.filename});
}

class FichePharmacieScreen extends StatefulWidget {
  final GardeModel? garde;
  final int? pharmacyId;

  const FichePharmacieScreen({
    super.key,
    this.garde,
    this.pharmacyId,
  });

  @override
  State<FichePharmacieScreen> createState() => _FichePharmacieScreenState();
}

class _FichePharmacieScreenState extends State<FichePharmacieScreen> {
  final ApiClient _api = ApiClient();
  UserModel? _user;
  List<String> _facadeImages = [];
  List<ServiceImageItem> _services = [];

  GardeModel? _resolvedGarde;

  @override
  void initState() {
    super.initState();
    _resolvedGarde = widget.garde;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_resolvedGarde == null) {
        final args = ModalRoute.of(context)?.settings.arguments;
        if (args is GardeModel) {
          setState(() {
            _resolvedGarde = args;
          });
        }
      }
      _fetchPharmacyDetails();
    });
  }

  int? get _targetId => _resolvedGarde?.id ?? widget.pharmacyId;

  Future<void> _fetchPharmacyDetails() async {
    final id = _targetId;
    if (id == null || id <= 0) return;

    try {
      final auth = context.read<AuthProvider>();
      final futures = await Future.wait([
        _fetchUserById(id),
        _fetchServicesAndImages(id),
        auth.fetchUserImages(id).timeout(
          const Duration(seconds: 4),
          onTimeout: () => <String, List<String>>{
            'facade': <String>[],
            'para': <String>[],
            'injection': <String>[],
          },
        ),
      ]);

      final fetchedUser = futures[0] as UserModel?;
      final authImages = futures[2] as Map<String, List<String>>;

      if (mounted) {
        setState(() {
          _user = fetchedUser;
          if (_facadeImages.isEmpty && authImages['facade']?.isNotEmpty == true) {
            _facadeImages = authImages['facade']!;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchServicesAndImages(int id) async {
    try {
      final res = await _api.post(
        'image/allImages',
        data: {'id': id},
        options: Options(headers: {'id': id.toString()}),
        useCache: true,
      );

      if (res.data != null && res.data is List) {
        final List<ServiceImageItem> loaded = [];
        final List<String> facades = [];

        for (final item in res.data as List) {
          if (item is Map) {
            final type = item['type']?.toString() ?? 'Service';
            final files = item['files'];
            if (files is List) {
              for (final f in files) {
                final fn = f['filename']?.toString();
                if (fn != null && fn.isNotEmpty) {
                  loaded.add(ServiceImageItem(type: type, filename: fn));
                  if (type.toLowerCase().contains('façade') || type.toLowerCase().contains('facade')) {
                    facades.add(fn);
                  }
                }
              }
            }
          }
        }

        if (mounted) {
          setState(() {
            _services = loaded;
            if (facades.isNotEmpty) {
              _facadeImages = facades;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<UserModel?> _fetchUserById(int id) async {
    try {
      final res = await _api.post(
        'user/getUserById',
        data: {'id': id},
        useCache: true,
      );
      if (res.data != null && res.data is Map<String, dynamic>) {
        return UserModel.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (_) {}

    try {
      final res = await _api.post(
        'user/getPharmacie',
        data: {'id': id},
        useCache: true,
      );
      if (res.data != null && res.data is Map<String, dynamic>) {
        return UserModel.fromJson(res.data as Map<String, dynamic>);
      }
    } catch (_) {}

    return null;
  }

  String _resolveGouvernorat(String adresse) {
    if (_user?.gouvernoratNom != null && _user!.gouvernoratNom!.trim().isNotEmpty) {
      return _user!.gouvernoratNom!.trim().toUpperCase();
    }

    final knownGouvernorats = [
      'SFAX', 'TUNIS', 'ARIANA', 'BEN AROUS', 'MANOUBA', 'SOUSSE',
      'MONASTIR', 'MAHDIA', 'NABEUL', 'BIZERTE', 'BEJA', 'JENDOUBA',
      'KEF', 'SILIANA', 'KAIROUAN', 'KASSERINE', 'SIDI BOUZID',
      'GABES', 'MEDENINE', 'TATAOUINE', 'GAFSA', 'TOZEUR', 'KEBILI', 'ZAGHOUAN'
    ];

    final upper = adresse.toUpperCase();
    for (final g in knownGouvernorats) {
      if (upper.contains(g)) {
        return g;
      }
    }

    return 'SFAX';
  }

  Future<void> _callNumber(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&dir_action=navigate');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  void _openImageFullScreen(BuildContext context, String imageUrl, String title) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryGreen),
                    ),
                    errorWidget: (_, __, ___) => Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(LucideIcons.imageOff, color: Colors.white70, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Pincez pour zoomer',
                style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    final g = _resolvedGarde;
    final u = _user;

    final String nomPharmacie = (u?.nom?.isNotEmpty == true
            ? u!.nom!
            : (g?.nomPharmacie?.isNotEmpty == true ? g!.nomPharmacie! : 'Pharmacie'))
        .trim();

    final String adresse = (u?.adresse?.isNotEmpty == true
            ? u!.adresse!
            : (g?.adresse?.isNotEmpty == true ? g!.adresse! : ''))
        .trim();

    final String tel = (u?.tel?.isNotEmpty == true
            ? u!.tel!
            : (g?.tel?.isNotEmpty == true ? g!.tel! : ''))
        .trim();

    final double? lat = u?.lat ?? g?.lat;
    final double? lng = u?.lng ?? g?.lng;

    final String gouvernorat = _resolveGouvernorat(adresse);
    final bool isJeune = u?.isJeunePharmacie == true;

    final ImageProvider bgImage = _facadeImages.isNotEmpty
        ? CachedNetworkImageProvider(
            '${AppConstants.backBaseUrl}${_facadeImages.first.startsWith('/') ? _facadeImages.first.substring(1) : _facadeImages.first}',
          )
        : AssetImage(
            isJeune ? 'assets/images/back-details-jeune.png' : 'assets/images/back-details.png',
          ) as ImageProvider;

    return Scaffold(
      backgroundColor: const Color(0xFF1E293B),
      body: Stack(
        children: [
          // ─── BACKGROUND IMAGE (Identique React PagePharmacie.jsx) ───
          Positioned.fill(
            child: Image(
              image: bgImage,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/images/back-details.png',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
          ),

          // ─── SEMI-TRANSPARENT DARK OVERLAY ───
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.45),
                  ],
                ),
              ),
            ),
          ),

          // ─── SCROLLABLE CONTENT ───
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: bottomPadding + 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ─── TOP BAR WITH BACK BUTTON ───
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.arrowLeft, size: 16, color: Colors.white),
                              SizedBox(width: 6),
                              Text(
                                'Retour',
                                style: TextStyle(
                                  color: Colors.white,
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

                  // ─── HERO TITLE OVER STOREFRONT ───
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Text(
                      nomPharmacie.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.2,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ─── CARD 1: INFORMATIONS (Identique React .info-card) ───
                  _buildSectionCard(
                    icon: LucideIcons.user,
                    title: 'Informations',
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item 1: NOM COMPLET
                          _buildInfoItem(
                            label: 'NOM COMPLET',
                            icon: LucideIcons.user,
                            value: nomPharmacie.toUpperCase(),
                          ),

                          // Item 2: ADRESSE
                          _buildInfoItem(
                            label: 'ADRESSE',
                            icon: LucideIcons.mapPin,
                            value: adresse.isNotEmpty ? adresse : 'Non renseignée',
                          ),

                          // Item 3: GOUVERNORAT
                          _buildInfoItem(
                            label: 'GOUVERNORAT',
                            icon: LucideIcons.building2,
                            value: gouvernorat,
                          ),

                          // Item 4: TÉLÉPHONE (Lien cliquable bleu)
                          _buildInfoItem(
                            label: 'TÉLÉPHONE',
                            icon: LucideIcons.phone,
                            value: tel.isNotEmpty ? tel : 'Non renseigné',
                            isPhone: true,
                          ),

                          // Si jeune pharmacien (rôle 7) : afficher détails supplémentaires
                          if (isJeune) ...[
                            if (u?.login != null && u!.login!.isNotEmpty)
                              _buildInfoItem(
                                label: 'E-MAIL',
                                icon: LucideIcons.mail,
                                value: u.login!,
                              ),
                            if (u?.identifiant != null && u!.identifiant!.isNotEmpty)
                              _buildInfoItem(
                                label: 'NUM ORDRE',
                                icon: LucideIcons.hash,
                                value: u.identifiant!,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ─── CARD 2: LOCALISATION (Identique React .info-card) ───
                  _buildSectionCard(
                    icon: LucideIcons.map,
                    title: 'Localisation',
                    child: (lat != null && lng != null && lat != 0)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: 260,
                                width: double.infinity,
                                child: GoogleMap(
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(lat, lng),
                                    zoom: 15,
                                  ),
                                  markers: {
                                    Marker(
                                      markerId: MarkerId('loc_${_targetId ?? 0}'),
                                      position: LatLng(lat, lng),
                                      infoWindow: InfoWindow(title: nomPharmacie),
                                    ),
                                  },
                                  myLocationButtonEnabled: false,
                                  zoomControlsEnabled: false,
                                  mapToolbarEnabled: false,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openGoogleMaps(lat, lng),
                                    icon: const Icon(LucideIcons.navigation, size: 16),
                                    label: const Text(
                                      'Ouvrir dans Google Maps',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            height: 240,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(LucideIcons.mapPinOff, size: 44, color: Color(0xFF6C757D)),
                                SizedBox(height: 10),
                                Text(
                                  'Localisation indisponible',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6C757D),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),

                  // ─── CARD 3: SERVICES (Identique React .info-card / capture utilisateur) ───
                  _buildSectionCard(
                    icon: LucideIcons.settings,
                    title: 'Services',
                    child: _services.isNotEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            height: 290,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _services.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (ctx, i) {
                                final s = _services[i];
                                final cleanFn = s.filename.startsWith('/') ? s.filename.substring(1) : s.filename;
                                final imgUrl = '${AppConstants.backBaseUrl}uploads/$cleanFn';

                                return InkWell(
                                  onTap: () => _openImageFullScreen(context, imgUrl, s.type),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 200,
                                            height: 190,
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: const Color(0xFF89C998),
                                                width: 1.5,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                              color: Colors.white,
                                            ),
                                            padding: const EdgeInsets.all(4),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: CachedNetworkImage(
                                                imageUrl: imgUrl,
                                                fit: BoxFit.cover,
                                                placeholder: (_, __) => const Center(
                                                  child: CircularProgressIndicator(
                                                    color: AppColors.primaryGreen,
                                                    strokeWidth: 2.5,
                                                  ),
                                                ),
                                                errorWidget: (_, __, ___) => Image.network(
                                                  imgUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(
                                                    color: Colors.grey.shade100,
                                                    child: const Center(
                                                      child: Icon(LucideIcons.image, color: Colors.grey, size: 40),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Zoom Indicator Badge
                                          Positioned(
                                            bottom: 10,
                                            right: 10,
                                            child: Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.65),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                LucideIcons.maximize2,
                                                color: Colors.white,
                                                size: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        width: 200,
                                        child: Text(
                                          s.type,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF2C3E50),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          )
                        : Container(
                            height: 260,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.all(16),
                            child: const Text(
                              'Aucun service disponible',
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF6C757D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── REUSABLE SECTION CARD (.info-card Identique React) ───
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86), // rgb(255 255 255 / 86%) Identique React
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (.info-card .card-header Identique React)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFDFDFD), Color(0xFFE6E1EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE9ECEF), width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF212529)),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF212529),
                  ),
                ),
              ],
            ),
          ),
          // Body
          child,
        ],
      ),
    );
  }

  // ─── BULLE INFO ITEM (Identique React .info-item) ───
  Widget _buildInfoItem({
    required String label,
    required IconData icon,
    required String value,
    bool isPhone = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xFF28A745), // Vert React identique
          width: 1.8,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF333333),
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: const Color(0xFF28A745),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isPhone && value != 'Non renseigné'
                    ? InkWell(
                        onTap: () => _callNumber(value),
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF007BFF), // Bleu lien React identique
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
