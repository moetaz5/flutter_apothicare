import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/garde_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/garde_provider.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/app_toast.dart';
import '../../../shared/widgets/app_bottom_nav_bar.dart';
import '../../../shared/widgets/app_loading_indicator.dart';
import 'widgets/custom_map_marker.dart';
import 'fiche_pharmacie_screen.dart';

class GardesMapScreen extends StatefulWidget {
  const GardesMapScreen({super.key});

  @override
  State<GardesMapScreen> createState() => _GardesMapScreenState();
}

class _GardesMapScreenState extends State<GardesMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isInitialLocating = true;
  bool _isSatellite = false;
  bool _isListView = false;
  bool _filterInjection = false;
  bool _filterVeterinaire = false;
  GardeModel? _selectedPharmacy;
  Set<Marker> _markers = {};
  bool _hasInitialFlyDone = false;

  LatLng _currentCameraCenter = const LatLng(34.7406, 10.7603);
  LatLng _lastSearchedCenter = const LatLng(34.7406, 10.7603);
  bool _showSearchThisAreaButton = false;
  bool _isAreaSearchActive = false;
  bool _hasLocationPermission = false;
  LatLng? _currentUserGpsLocation;
  StreamSubscription<Position>? _userGpsStreamSub;

  static const LatLng _tunisiaDefaultLocation = LatLng(34.7406, 10.7603); // Sfax / Tunisie
  static const int _maxVisibleMarkers = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CustomMapMarkerHelper.initMarkers();
      if (!mounted) return;
      _initLocationAndClosestPharmacies();
    });
  }

  Future<void> _initLocationAndClosestPharmacies() async {
    setState(() {
      _isInitialLocating = true;
      _isAreaSearchActive = false;
      _showSearchThisAreaButton = false;
      _selectedPharmacy = null;
      _filterInjection = false;
      _filterVeterinaire = false;
    });
    _searchController.clear();

    final provider = context.read<GardeProvider>();
    provider.setSearchQuery('');

    // Start loading pharmacies in parallel if not loaded yet
    final fetchFuture = provider.allGardes.isEmpty
        ? provider.fetchGardes()
        : Future.value();

    Position? userPos;
    bool hasPerm = false;

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      hasPerm = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

      if (hasPerm) {
        // 1. Fast: try last known position first
        userPos = await Geolocator.getLastKnownPosition();

        // 2. Fresh: fetch current position with timeout
        try {
          final fresh = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(milliseconds: 3500),
          );
          userPos = fresh;
        } catch (_) {}
      }
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _hasLocationPermission = hasPerm;
    });

    // Start live GPS tracking stream
    if (hasPerm) {
      _userGpsStreamSub?.cancel();
      _userGpsStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3,
        ),
      ).listen((pos) {
        if (!mounted) return;
        final newPos = LatLng(pos.latitude, pos.longitude);
        final wasNull = _currentUserGpsLocation == null;
        _currentUserGpsLocation = newPos;

        if (wasNull) {
          _currentCameraCenter = newPos;
          provider.resetToProximity(limit: 20, position: pos);
          _buildMarkers(provider.gardes, isProximityOnly: true);
          _animateToLocation(newPos.latitude, newPos.longitude, zoom: 15.5);
        } else {
          _buildMarkers(provider.gardes);
        }
        setState(() {});
      });
    }

    // Wait for pharmacies to be loaded
    await fetchFuture;
    if (!mounted) return;

    LatLng targetCenter = _tunisiaDefaultLocation;
    if (userPos != null) {
      targetCenter = LatLng(userPos.latitude, userPos.longitude);
      _currentUserGpsLocation = targetCenter;
    } else if (provider.currentPosition != null) {
      targetCenter = LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude);
      _currentUserGpsLocation = targetCenter;
    }

    _currentCameraCenter = targetCenter;
    _lastSearchedCenter = targetCenter;

    // Reset and compute the 20 closest pharmacies to the user
    provider.resetToProximity(limit: 20, position: userPos);

    if (!mounted) return;

    _buildMarkers(provider.gardes, isProximityOnly: true);

    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: targetCenter,
            zoom: 15.5,
          ),
        ),
      );
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isInitialLocating = false;
        _hasInitialFlyDone = true;
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _userGpsStreamSub?.cancel();
    super.dispose();
  }

  void _syncMarkersAndLocation(GardeProvider provider) {
    _buildMarkers(provider.gardes, isProximityOnly: !_isAreaSearchActive);
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final provider = context.read<GardeProvider>();
      provider.setSearchQuery(val);
      _buildMarkers(provider.gardes);
    });
  }

  void _onSearchSubmitted(String val) {
    FocusScope.of(context).unfocus();
    _debounceTimer?.cancel();
    if (!mounted) return;
    final provider = context.read<GardeProvider>();
    provider.setSearchQuery(val);
    _buildMarkers(provider.gardes);

    // Only move camera when user explicitly presses Search on keyboard
    if (val.trim().isNotEmpty && provider.gardes.isNotEmpty) {
      final first = provider.gardes.first;
      if (first.lat != null && first.lng != null && first.lat != 0) {
        _animateToLocation(first.lat!, first.lng!, zoom: 15.5);
      }
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentCameraCenter = position.target;

    final double dist = _calculateDistanceKm(
      _lastSearchedCenter.latitude,
      _lastSearchedCenter.longitude,
      position.target.latitude,
      position.target.longitude,
    );

    if (dist > 0.25 && !_showSearchThisAreaButton) {
      setState(() {
        _showSearchThisAreaButton = true;
      });
    }
  }

  void _onCameraIdle() {
    final double dist = _calculateDistanceKm(
      _lastSearchedCenter.latitude,
      _lastSearchedCenter.longitude,
      _currentCameraCenter.latitude,
      _currentCameraCenter.longitude,
    );

    if (dist > 0.25 && !_showSearchThisAreaButton) {
      setState(() {
        _showSearchThisAreaButton = true;
      });
    }
  }

  Future<void> _searchInThisArea() async {
    FocusScope.of(context).unfocus();
    final provider = context.read<GardeProvider>();
    _isAreaSearchActive = true;
    try {
      final controller = await _mapController.future;
      final LatLngBounds visibleRegion = await controller.getVisibleRegion();

      _lastSearchedCenter = _currentCameraCenter;
      provider.searchInBounds(
        minLat: visibleRegion.southwest.latitude,
        maxLat: visibleRegion.northeast.latitude,
        minLng: visibleRegion.southwest.longitude,
        maxLng: visibleRegion.northeast.longitude,
        centerLat: _currentCameraCenter.latitude,
        centerLng: _currentCameraCenter.longitude,
        limit: 20,
      );

      _buildMarkers(provider.gardes, isProximityOnly: false);

      if (mounted) {
        setState(() {
          _showSearchThisAreaButton = false;
          _selectedPharmacy = null;
        });
      }
    } catch (_) {
      _lastSearchedCenter = _currentCameraCenter;
      provider.searchInArea(_currentCameraCenter.latitude, _currentCameraCenter.longitude, limit: 20);
      _buildMarkers(provider.gardes, isProximityOnly: false);

      if (mounted) {
        setState(() {
          _showSearchThisAreaButton = false;
          _selectedPharmacy = null;
        });
      }
    }
  }

  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    try {
      final meters = Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
      return meters / 1000.0;
    } catch (_) {
      const double p = 0.017453292519943295;
      final double a = 0.5 -
          math.cos((lat2 - lat1) * p) / 2 +
          math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
      return 12742 * math.asin(math.sqrt(a > 0 ? a : 0));
    }
  }

  void _buildMarkers(List<GardeModel> pharmacies, {bool? isProximityOnly}) {
    final Set<Marker> newMarkers = {};

    // ─── GUARANTEED USER BLUE LOCATION DOT ───
    if (_currentUserGpsLocation != null && CustomMapMarkerHelper.userLocationMarker != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId('live_user_blue_dot'),
          position: _currentUserGpsLocation!,
          icon: CustomMapMarkerHelper.userLocationMarker!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 9999,
          flat: true,
          infoWindow: const InfoWindow(title: 'Votre position'),
        ),
      );
    }

    // ─── SERVICE FILTERING (Injection / Vétérinaire) ───
    final provider = context.read<GardeProvider>();
    final bool hasServiceFilter = _filterInjection || _filterVeterinaire;

    final List<GardeModel> sourceList = hasServiceFilter ? provider.allGardes : pharmacies;

    final List<GardeModel> activeFiltered = sourceList.where((ph) {
      if (_filterInjection && !ph.hasInjection) return false;
      if (_filterVeterinaire && !ph.hasVeterinaire) return false;
      return true;
    }).toList();

    // Sort by proximity to user GPS location or camera center so the 20 closest matching are displayed
    final refLat = _currentUserGpsLocation?.latitude ?? _currentCameraCenter.latitude;
    final refLng = _currentUserGpsLocation?.longitude ?? _currentCameraCenter.longitude;
    activeFiltered.sort((a, b) {
      final distA = (a.lat != null && a.lng != null && a.lat != 0)
          ? _calculateDistanceKm(refLat, refLng, a.lat!, a.lng!)
          : 99999.0;
      final distB = (b.lat != null && b.lng != null && b.lat != 0)
          ? _calculateDistanceKm(refLat, refLng, b.lat!, b.lng!)
          : 99999.0;
      return distA.compareTo(distB);
    });

    if (_selectedPharmacy != null) {
      final stillVisible = activeFiltered.any((p) => p.id == _selectedPharmacy!.id);
      if (!stillVisible) {
        _selectedPharmacy = null;
      } else if (_selectedPharmacy!.lat != null && _selectedPharmacy!.lng != null) {
        final selectedIndex = activeFiltered.indexWhere((p) => p.id == _selectedPharmacy!.id);
        if (selectedIndex >= _maxVisibleMarkers) {
          activeFiltered.removeAt(selectedIndex);
          activeFiltered.insert(0, _selectedPharmacy!);
        }
      }
    }

    // ─── STRICT MAXIMUM 20 PHARMACIES IN ALL CASES ───
    final int limit = activeFiltered.length > _maxVisibleMarkers ? _maxVisibleMarkers : activeFiltered.length;

    for (int i = 0; i < limit; i++) {
      final ph = activeFiltered[i];
      if (ph.lat != null && ph.lng != null && ph.lat != 0 && ph.lng != 0) {
        final isNight = ph.typeGarde?.toLowerCase().contains('nuit') ?? false;
        final isSelected = _selectedPharmacy?.id == ph.id;

        BitmapDescriptor icon = isNight
            ? (CustomMapMarkerHelper.nightMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
            : (CustomMapMarkerHelper.dayMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen));

        if (isSelected && CustomMapMarkerHelper.selectedMarker != null) {
          icon = CustomMapMarkerHelper.selectedMarker!;
        }

        newMarkers.add(
          Marker(
            markerId: MarkerId(ph.id?.toString() ?? '${ph.lat}_${ph.lng}'),
            position: LatLng(ph.lat!, ph.lng!),
            icon: icon,
            infoWindow: InfoWindow(
              title: ph.nomPharmacie ?? 'Pharmacie',
              snippet: '${ph.typeGarde ?? "Garde"} • ${ph.adresse ?? ""}',
            ),
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _selectedPharmacy = ph;
              });
              _buildMarkers(context.read<GardeProvider>().gardes);
              _animateToLocation(ph.lat!, ph.lng!, zoom: 15.5);
            },
          ),
        );
      }
    }
    setState(() {
      _markers = newMarkers;
    });
  }

  int _getFilteredCount(GardeProvider provider) {
    final bool hasServiceFilter = _filterInjection || _filterVeterinaire;
    final list = hasServiceFilter ? provider.allGardes : provider.gardes;
    int count;
    if (!hasServiceFilter) {
      count = list.length;
    } else {
      count = list.where((ph) {
        if (_filterInjection && !ph.hasInjection) return false;
        if (_filterVeterinaire && !ph.hasVeterinaire) return false;
        return true;
      }).length;
    }
    return count > _maxVisibleMarkers ? _maxVisibleMarkers : count;
  }

  Future<void> _animateToLocation(double lat, double lng, {double zoom = 15.2, double tilt = 0.0, double bearing = 0.0}) async {
    try {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoom,
            tilt: tilt,
            bearing: bearing,
          ),
        ),
      );
    } catch (_) {}
  }

  Future<void> _flyToUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position? pos;
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 3),
          );
        } catch (_) {
          pos = await Geolocator.getLastKnownPosition();
        }
      } else {
        pos = await Geolocator.getLastKnownPosition();
      }

      LatLng targetPos;
      if (pos != null) {
        targetPos = LatLng(pos.latitude, pos.longitude);
        _currentUserGpsLocation = targetPos;
      } else {
        if (!mounted) return;
        final provider = context.read<GardeProvider>();
        final curr = provider.currentPosition;
        if (curr != null) {
          targetPos = LatLng(curr.latitude, curr.longitude);
          _currentUserGpsLocation = targetPos;
        } else {
          targetPos = _tunisiaDefaultLocation;
        }
      }

      _currentCameraCenter = targetPos;
      if (mounted) {
        setState(() {
          _isAreaSearchActive = false;
          _showSearchThisAreaButton = false;
          _selectedPharmacy = null;
        });
        final provider = context.read<GardeProvider>();
        provider.resetToProximity(limit: 20, position: pos);
        _buildMarkers(provider.gardes, isProximityOnly: true);
      }
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: targetPos,
            zoom: 16.5,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    } catch (_) {}
  }

  

  void _callPharmacy(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final Uri uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openGoogleMapsRoute(GardeModel ph) async {
    final lat = ph.lat;
    final lng = ph.lng;
    if (lat == null || lng == null || lat == 0 || lng == 0) {
      if (mounted) {
        AppToast.showError('Coordonnées GPS de cette pharmacie non disponibles.', context);
      }
      return;
    }

    final Uri uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&dir_action=navigate');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {
        if (mounted) {
          AppToast.showError('Impossible d\'ouvrir Google Maps.', context);
        }
      }
    }
  }

  void _onBottomNavTapped(int index) {
    final user = context.read<AuthProvider>().currentUser;
    final int roleId = user?.idRole ?? 0;
    final bool isPharmacien = user?.isPharmacien == true ||
        user?.isJeunePharmacie == true ||
        roleId == 2 ||
        roleId == 4 ||
        roleId == 7 ||
        roleId == 8;
    final bool isAdmin = user?.isAdmin == true || roleId == 1;

    if (index == 0) {
      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
      } else if (isPharmacien) {
        Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
      }
    } else if (index == 1) {
      Navigator.pushReplacementNamed(context, AppRoutes.actualites);
    } else if (index == 2) {
      if (isAdmin) {
        Navigator.pushReplacementNamed(context, AppRoutes.adminProfile);
      } else if (isPharmacien) {
        Navigator.pushReplacementNamed(context, AppRoutes.pharmacienProfile);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.profile);
      }
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
    final provider = context.watch<GardeProvider>();
    final topPadding = MediaQuery.of(context).padding.top;
    final isAuth = context.watch<AuthProvider>().isAuthenticated;
    final bottomInset = isAuth ? 0.0 : MediaQuery.of(context).padding.bottom;

    final initialTarget = _currentUserGpsLocation ??
        (provider.currentPosition != null
            ? LatLng(provider.currentPosition!.latitude, provider.currentPosition!.longitude)
            : _tunisiaDefaultLocation);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: Stack(
          children: [
            // ─── HARDWARE-ACCELERATED MAP VIEW ───
            if (!_isListView)
              Positioned.fill(
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 15.0,
                  ),
                  mapType: _isSatellite ? MapType.hybrid : MapType.normal,
                  myLocationEnabled: _hasLocationPermission,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  markers: _markers,
                  onCameraMoveStarted: () {
                    FocusScope.of(context).unfocus();
                  },
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  onTap: (pos) {
                    FocusScope.of(context).unfocus();
                    if (_selectedPharmacy != null) {
                      setState(() {
                        _selectedPharmacy = null;
                      });
                      _buildMarkers(provider.gardes);
                    }
                  },
                  onMapCreated: (controller) {
                    if (!_mapController.isCompleted) {
                      _mapController.complete(controller);
                    }
                    if (_currentUserGpsLocation != null) {
                      controller.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: _currentUserGpsLocation!,
                            zoom: 15.5,
                          ),
                        ),
                      );
                    }
                    _syncMarkersAndLocation(provider);
                  },
                ),
              )
          else
            // ─── LIST VIEW ALTERNATIVE ───
            Positioned.fill(
              top: topPadding + 115,
              child: provider.isLoading
                  ? const Center(child: AppLoadingIndicator.page(message: 'Recherche des pharmacies de garde...'))
                  : provider.gardes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.mapPinOff, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              const Text(
                                'Aucune pharmacie trouvée dans cette zone.',
                                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )
                      : Builder(
                          builder: (context) {
                            final hasServiceFilter = _filterInjection || _filterVeterinaire;
                            final sourceList = hasServiceFilter ? provider.allGardes : provider.gardes;
                            final listFiltered = sourceList.where((ph) {
                              if (_filterInjection && !ph.hasInjection) return false;
                              if (_filterVeterinaire && !ph.hasVeterinaire) return false;
                              return true;
                            }).take(_maxVisibleMarkers).toList();

                            return ListView.separated(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + bottomInset),
                              itemCount: listFiltered.length,
                              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                              itemBuilder: (ctx, i) {
                                final ph = listFiltered[i];
                                return _buildListPharmacyCard(ph);
                              },
                            );
                          },
                        ),
            ),

          // ─── TOP BAR: NORMAL HEADER ───
          Positioned(
            top: topPadding + 6,
            left: 10,
            right: 10,
            child: RepaintBoundary(
              child: _buildNormalHeader(provider),
            ),
          ),

          // ─── FLOATING "RECHERCHER DANS CETTE ZONE" BUTTON ───
          if (!_isListView && _showSearchThisAreaButton)
            Positioned(
              top: topPadding + 112,
              left: 0,
              right: 0,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  elevation: 6,
                  shadowColor: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(30),
                  child: InkWell(
                    onTap: _searchInThisArea,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: AppColors.primaryGreen, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.search, size: 15, color: AppColors.primaryGreen),
                          SizedBox(width: 8),
                          Text(
                            'Rechercher dans cette zone',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.forestGreen,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ─── USER LOCATION BUTTON (Bottom Left) ───
          if (!_isListView)
            Positioned(
              bottom: _selectedPharmacy != null ? (295 + bottomInset) : (16 + bottomInset),
              left: 14,
              child: FloatingActionButton.small(
                heroTag: 'fab_user_location',
                onPressed: _flyToUserLocation,
                backgroundColor: Colors.white,
                foregroundColor: AppColors.forestGreen,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: const Icon(LucideIcons.crosshair, size: 20),
              ),
            ),

          // ─── SELECTED PHARMACY BOTTOM PREVIEW CARD ───
          if (!_isListView && _selectedPharmacy != null)
            Positioned(
              bottom: 14 + bottomInset,
              left: 14,
              right: 14,
              child: RepaintBoundary(
                child: _buildSelectedPharmacyCard(_selectedPharmacy!),
              ),
            ),

          // ─── INITIAL LOADING OVERLAY (Finding user location & 20 closest pharmacies) ───
          if (_isInitialLocating)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.90),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3.5,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Localisation en cours…',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Recherche des 20 pharmacies les plus proches',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      // ─── BOTTOM NAVIGATION BAR (Only when logged in) ───
      bottomNavigationBar: context.watch<AuthProvider>().isAuthenticated
          ? AppBottomNavBar(
              currentIndex: 0,
              notifCount: context.watch<AuthProvider>().unreadNotifications,
              onTap: _onBottomNavTapped,
            )
          : null,
    ),
  );
  }

  Widget _buildNormalHeader(GardeProvider provider) {
    final auth = context.watch<AuthProvider>();
    final isAuth = auth.isAuthenticated;

    return Column(
      children: [
        Row(
          children: [
            // Accueil / Login button
            InkWell(
              onTap: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  final user = context.read<AuthProvider>().currentUser;
                  final int roleId = user?.idRole ?? 0;
                  final bool isPharmacien = user?.isPharmacien == true ||
                      user?.isJeunePharmacie == true ||
                      roleId == 2 ||
                      roleId == 4 ||
                      roleId == 7 ||
                      roleId == 8;
                  final bool isAdmin = user?.isAdmin == true || roleId == 1;

                  if (!isAuth) {
                    Navigator.pushReplacementNamed(context, AppRoutes.signIn);
                  } else if (isAdmin) {
                    Navigator.pushReplacementNamed(context, AppRoutes.homeAdmin);
                  } else if (isPharmacien) {
                    Navigator.pushReplacementNamed(context, AppRoutes.homePharmacien);
                  } else {
                    Navigator.pushReplacementNamed(context, AppRoutes.homePatient);
                  }
                }
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.arrowLeft, size: 15, color: AppColors.forestGreen),
                    const SizedBox(width: 4),
                    Text(
                      isAuth ? 'Accueil' : 'Login',
                      style: const TextStyle(
                        color: AppColors.forestGreen,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Center count pill
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        (_filterInjection || _filterVeterinaire)
                            ? '${_getFilteredCount(provider)} avec ce service'
                            : (_isAreaSearchActive
                                ? '${_getFilteredCount(provider)} dans cette zone'
                                : '${_getFilteredCount(provider)} à proximité'),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forestGreen,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Right Toggle Buttons (Refresh, Satellite & Mode)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    setState(() {
                      _isAreaSearchActive = false;
                      _showSearchThisAreaButton = false;
                    });
                    await provider.fetchGardes(forceRefresh: true);
                    if (!mounted) return;
                    _buildMarkers(provider.gardes, isProximityOnly: true);
                    AppToast.showSuccess('Pharmacies de garde actualisées', context);
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      LucideIcons.refreshCw,
                      size: 15,
                      color: AppColors.forestGreen,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isSatellite ? AppColors.forestGreen : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      LucideIcons.globe,
                      size: 15,
                      color: _isSatellite ? Colors.white : AppColors.forestGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search Bar with Service Filters on the right
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.search, size: 16, color: AppColors.primaryGreen),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchSubmitted,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher pharmacie…',
                    hintStyle: TextStyle(fontSize: 12.0, color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(LucideIcons.x, size: 14, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  );
                },
              ),
              _buildRightFilterPill(
                icon: LucideIcons.syringe,
                label: 'Injection',
                isActive: _filterInjection,
                onTap: () {
                  setState(() {
                    _filterInjection = !_filterInjection;
                    if (_filterInjection) {
                      _filterVeterinaire = false;
                    }
                  });
                  final prov = context.read<GardeProvider>();
                  _buildMarkers(_filterInjection ? prov.allGardes : prov.gardes);
                },
              ),
              const SizedBox(width: 4),
              _buildRightFilterPill(
                icon: LucideIcons.pawPrint,
                label: 'Produit vét.',
                isActive: _filterVeterinaire,
                onTap: () {
                  setState(() {
                    _filterVeterinaire = !_filterVeterinaire;
                    if (_filterVeterinaire) {
                      _filterInjection = false;
                    }
                  });
                  final prov = context.read<GardeProvider>();
                  _buildMarkers(_filterVeterinaire ? prov.allGardes : prov.gardes);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightFilterPill({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        FocusScope.of(context).unfocus();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryGreen : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? Colors.white : AppColors.forestGreen,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedPharmacyCard(GardeModel ph) {
    final isNight = ph.typeGarde?.toLowerCase().contains('nuit') ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFFF3E8FF) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isNight ? LucideIcons.moon : LucideIcons.sun,
                  color: isNight ? const Color(0xFF7C3AED) : AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ph.nomPharmacie ?? 'Pharmacie',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ph.adresse?.isNotEmpty == true ? ph.adresse! : 'Adresse non spécifiée',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Close card button
              InkWell(
                onTap: () {
                  setState(() => _selectedPharmacy = null);
                  _buildMarkers(context.read<GardeProvider>().gardes);
                },
                child: const Icon(LucideIcons.x, size: 18, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Distance & Tel Row
          Row(
            children: [
              if (ph.distanceInKm != null) ...[
                const Icon(LucideIcons.navigation, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  '${ph.distanceInKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.forestGreen),
                ),
                const SizedBox(width: 14),
              ],
              if (ph.tel != null && ph.tel!.isNotEmpty) ...[
                const Icon(LucideIcons.phone, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: 4),
                Text(
                  ph.tel!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ],
            ],
          ),
          if (ph.hasInjection || ph.hasVeterinaire) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (ph.hasInjection)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.syringe, size: 12, color: AppColors.primaryGreen),
                        SizedBox(width: 4),
                        Text(
                          "Salle d'injection",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (ph.hasVeterinaire)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.pawPrint, size: 12, color: AppColors.primaryGreen),
                        SizedBox(width: 4),
                        Text(
                          "Produits vétérinaires",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Bouton Consulter la fiche (Identique React)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _navigateToFiche(ph),
              icon: const Icon(LucideIcons.fileText, size: 16),
              label: const Text(
                'Consulter la fiche',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Action Buttons: Appeler & Itinéraire
          Row(
            children: [
              if (ph.tel != null && ph.tel!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPharmacy(ph.tel),
                    icon: const Icon(LucideIcons.phoneCall, size: 14),
                    label: const Text('Appeler', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forestGreen,
                      side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (ph.tel != null && ph.tel!.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMapsRoute(ph),
                  icon: const Icon(LucideIcons.navigation, size: 14),
                  label: const Text('Itinéraire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToFiche(GardeModel ph) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FichePharmacieScreen(garde: ph),
      ),
    );
  }

  Widget _buildListPharmacyCard(GardeModel ph) {
    final isNight = ph.typeGarde?.toLowerCase().contains('nuit') ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isNight ? const Color(0xFFF3E8FF) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isNight ? LucideIcons.moon : LucideIcons.sun,
                      size: 13,
                      color: isNight ? const Color(0xFF7C3AED) : AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isNight ? 'Garde Nuit' : 'Garde Jour',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isNight ? const Color(0xFF7C3AED) : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (ph.distanceInKm != null)
                Text(
                  '${ph.distanceInKm!.toStringAsFixed(1)} km',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primaryGreen),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            ph.nomPharmacie ?? 'Pharmacie',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.forestGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ph.adresse?.isNotEmpty == true ? ph.adresse! : 'Adresse non spécifiée',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _navigateToFiche(ph),
                  icon: const Icon(LucideIcons.fileText, size: 14),
                  label: const Text('Fiche', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (ph.tel != null && ph.tel!.isNotEmpty) ...[
                OutlinedButton(
                  onPressed: () => _callPharmacy(ph.tel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forestGreen,
                    side: const BorderSide(color: AppColors.forestGreen),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(LucideIcons.phone, size: 14),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openGoogleMapsRoute(ph),
                  icon: const Icon(LucideIcons.navigation, size: 14),
                  label: const Text('Itinéraire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.forestGreen,
                    side: const BorderSide(color: AppColors.forestGreen),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
