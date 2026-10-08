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
import 'widgets/route_service.dart';

class GardesMapScreen extends StatefulWidget {
  const GardesMapScreen({super.key});

  @override
  State<GardesMapScreen> createState() => _GardesMapScreenState();
}

class _GardesMapScreenState extends State<GardesMapScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  Timer? _guidanceProgressTimer;

  bool _isInitialLocating = true;
  bool _isSatellite = false;
  bool _isListView = false;
  GardeModel? _selectedPharmacy;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _hasInitialFlyDone = false;

  LatLng _currentCameraCenter = const LatLng(34.7406, 10.7603);
  LatLng _lastSearchedCenter = const LatLng(34.7406, 10.7603);
  bool _showSearchThisAreaButton = false;
  bool _isAreaSearchActive = false;
  bool _hasLocationPermission = false;
  LatLng? _currentUserGpsLocation;
  StreamSubscription<Position>? _userGpsStreamSub;

  // In-App Itinerary & Live Navigation State
  bool _isNavigating = false;
  bool _isCalculatingRoute = false;
  bool _isLiveGuiding = false; // Live Turn-by-Turn GPS Guidance Mode
  bool _isMuted = false;
  String _travelMode = 'driving'; // 'driving' or 'walking'
  RouteInfo? _currentRouteInfo;
  GardeModel? _navDestinationPharmacy;

  StreamSubscription<Position>? _positionStreamSub;
  LatLng? _liveUserPosition;
  double _currentBearing = 0.0;
  double _currentSpeedKmH = 0.0;
  double _remainingDistanceMeters = 0.0;
  int _remainingDurationMin = 0;
  String _etaTimeStr = '';
  int _currentStepIndex = 0;
  List<LatLng> _fullRoutePoints = [];
  int _lastPassedPolylineIndex = 0;

  static const LatLng _tunisiaDefaultLocation = LatLng(34.7406, 10.7603); // Sfax / Tunisie
  static const int _maxVisibleMarkers = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await CustomMapMarkerHelper.initMarkers();
      if (!mounted) return;

      final provider = context.read<GardeProvider>();

      // 1. Get user GPS location & check permissions
      Position? userPos;
      bool hasPerm = false;
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        hasPerm = permission == LocationPermission.always || permission == LocationPermission.whileInUse;
        if (hasPerm) {
          try {
            userPos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 4),
            );
          } catch (_) {
            userPos = await Geolocator.getLastKnownPosition();
          }
        } else {
          userPos = await Geolocator.getLastKnownPosition();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasLocationPermission = hasPerm;
        });
      }

      LatLng targetCenter = _tunisiaDefaultLocation;
      if (userPos != null && userPos.latitude >= 30.0 && userPos.latitude <= 38.5 && userPos.longitude >= 7.0 && userPos.longitude <= 12.5) {
        targetCenter = LatLng(userPos.latitude, userPos.longitude);
        _currentUserGpsLocation = targetCenter;
      }

      _currentCameraCenter = targetCenter;
      _lastSearchedCenter = targetCenter;

      // Start live GPS tracking stream
      if (hasPerm) {
        _userGpsStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 2,
          ),
        ).listen((pos) {
          if (pos.latitude >= 30.0 && pos.latitude <= 38.5 && pos.longitude >= 7.0 && pos.longitude <= 12.5 && mounted) {
            final newPos = LatLng(pos.latitude, pos.longitude);
            _currentUserGpsLocation = newPos;
            if (_isNavigating && !_isLiveGuiding) {
              _updateRouteProgress(newPos, speed: pos.speed, heading: pos.heading);
            }
            if (!_isNavigating) {
              _buildMarkers(context.read<GardeProvider>().gardes);
            }
            setState(() {});
          }
        });
      }

      // 2. Load or reset to user proximity (always 20 closest)
      if (provider.allGardes.isNotEmpty) {
        provider.resetToProximity(limit: 20, position: userPos);
      } else {
        await provider.fetchGardes();
      }

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

      setState(() {
        _isInitialLocating = false;
        _hasInitialFlyDone = true;
        _hasLocationPermission = hasPerm;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _guidanceProgressTimer?.cancel();
    _searchController.dispose();
    _positionStreamSub?.cancel();
    _userGpsStreamSub?.cancel();
    super.dispose();
  }

  void _syncMarkersAndLocation(GardeProvider provider) {
    _buildMarkers(provider.gardes, isProximityOnly: !_isAreaSearchActive);

    if (provider.gardes.isNotEmpty && !_hasInitialFlyDone) {
      final firstValid = provider.gardes.firstWhere(
        (p) => p.lat != null && p.lng != null && p.lat != 0,
        orElse: () => provider.gardes.first,
      );

      if (firstValid.lat != null && firstValid.lng != null && firstValid.lat != 0) {
        _hasInitialFlyDone = true;
        _currentCameraCenter = LatLng(firstValid.lat!, firstValid.lng!);
        _lastSearchedCenter = _currentCameraCenter;
        _animateToLocation(firstValid.lat!, firstValid.lng!, zoom: 15.2);
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 180), () {
      final provider = context.read<GardeProvider>();
      provider.setSearchQuery(val);
      _buildMarkers(provider.gardes);

      if (val.trim().isNotEmpty && provider.gardes.isNotEmpty) {
        final first = provider.gardes.first;
        if (first.lat != null && first.lng != null && first.lat != 0) {
          _animateToLocation(first.lat!, first.lng!, zoom: 15.5);
        }
      }
    });
  }

  void _onCameraMove(CameraPosition position) {
    _currentCameraCenter = position.target;

    if (_isNavigating || _isLiveGuiding) return;

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
    if (_isNavigating || _isLiveGuiding) return;

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
      provider.searchInArea(_currentCameraCenter.latitude, _currentCameraCenter.longitude, limit: null);
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

    // ─── ITINERARY & LIVE GUIDANCE: ONLY SHOW DESTINATION PHARMACY ───
    if ((_isNavigating || _isLiveGuiding) && _navDestinationPharmacy != null) {
      final ph = _navDestinationPharmacy!;
      if (ph.lat != null && ph.lng != null && ph.lat != 0 && ph.lng != 0) {
        final isNight = ph.typeGarde?.toLowerCase().contains('nuit') ?? false;
        final BitmapDescriptor icon = CustomMapMarkerHelper.selectedMarker ??
            (isNight
                ? (CustomMapMarkerHelper.nightMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet))
                : (CustomMapMarkerHelper.dayMarker ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)));

        newMarkers.add(
          Marker(
            markerId: MarkerId('dest_${ph.id ?? "${ph.lat}_${ph.lng}"}'),
            position: LatLng(ph.lat!, ph.lng!),
            icon: icon,
            infoWindow: InfoWindow(
              title: ph.nomPharmacie ?? 'Pharmacie',
              snippet: '${ph.typeGarde ?? "Garde"} • ${ph.adresse ?? ""}',
            ),
          ),
        );
      }

      setState(() {
        _markers = newMarkers;
      });
      return;
    }

    // ─── NORMAL / AREA DISPLAY ───
    // Initial proximity mode shows the 20 closest pharmacies.
    // Area Search mode ("Rechercher dans cette zone") shows ALL pharmacies visible in the bounds.
    final bool shouldLimitTo20 = isProximityOnly ?? (!_isAreaSearchActive);
    final int limit = shouldLimitTo20
        ? (pharmacies.length > _maxVisibleMarkers ? _maxVisibleMarkers : pharmacies.length)
        : pharmacies.length;

    for (int i = 0; i < limit; i++) {
      final ph = pharmacies[i];
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
      if (pos != null && pos.latitude >= 30.0 && pos.latitude <= 38.5 && pos.longitude >= 7.0 && pos.longitude <= 12.5) {
        targetPos = LatLng(pos.latitude, pos.longitude);
      } else if (_isNavigating && _currentRouteInfo != null && _currentRouteInfo!.points.isNotEmpty) {
        targetPos = _currentRouteInfo!.points.first;
      } else {
        if (!mounted) return;
        final provider = context.read<GardeProvider>();
        final curr = provider.currentPosition;
        if (curr != null && curr.latitude >= 30.0 && curr.latitude <= 38.5 && curr.longitude >= 7.0 && curr.longitude <= 12.5) {
          targetPos = LatLng(curr.latitude, curr.longitude);
        } else {
          targetPos = _tunisiaDefaultLocation;
        }
      }

      _currentCameraCenter = targetPos;
      if (!_isNavigating && !_isLiveGuiding && mounted) {
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
            zoom: _isNavigating ? 17.5 : 16.5,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
    } catch (_) {
      if (_currentRouteInfo != null && _currentRouteInfo!.points.isNotEmpty) {
        final controller = await _mapController.future;
        await controller.animateCamera(
          CameraUpdate.newLatLngZoom(_currentRouteInfo!.points.first, 17.0),
        );
      }
    }
  }

  Future<void> _fitRouteOverview() async {
    if (_currentRouteInfo != null && _currentRouteInfo!.points.isNotEmpty) {
      final bounds = InAppRouteService.createBounds(_currentRouteInfo!.points);
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    }
  }

  // ─── IN-APP ITINERARY CALCULATION ───
  Future<void> _startInAppRoute(GardeModel ph) async {
    if (ph.lat == null || ph.lng == null || ph.lat == 0) return;

    setState(() {
      _isListView = false;
      _isCalculatingRoute = true;
      _navDestinationPharmacy = ph;
      _selectedPharmacy = ph;
    });

    final provider = context.read<GardeProvider>();
    LatLng origin;
    final curr = provider.currentPosition;
    final isTunisia = curr != null && curr.latitude >= 30 && curr.latitude <= 38 && curr.longitude >= 7 && curr.longitude <= 12;

    if (isTunisia) {
      origin = LatLng(curr.latitude, curr.longitude);
    } else {
      origin = LatLng(ph.lat! + 0.008, ph.lng! - 0.009);
    }

    final LatLng destination = LatLng(ph.lat!, ph.lng!);

    final routeInfo = await InAppRouteService.calculateRoute(
      origin: origin,
      destination: destination,
      profile: _travelMode,
    );

    if (!mounted) return;

    if (routeInfo != null && routeInfo.points.isNotEmpty) {
      final Set<Polyline> newPolylines = {
        // Drop shadow polyline for 3D depth
        Polyline(
          polylineId: const PolylineId('route_shadow'),
          points: routeInfo.points,
          color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
          width: 8,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
        // Active route polyline (Google Maps vibrant blue)
        Polyline(
          polylineId: const PolylineId('route_active'),
          points: routeInfo.points,
          color: const Color(0xFF2563EB),
          width: 5,
          jointType: JointType.round,
          endCap: Cap.roundCap,
          startCap: Cap.roundCap,
        ),
      };

      setState(() {
        _isNavigating = true;
        _isCalculatingRoute = false;
        _currentRouteInfo = routeInfo;
        _fullRoutePoints = List<LatLng>.from(routeInfo.points);
        _lastPassedPolylineIndex = 0;
        _polylines = newPolylines;
        _remainingDistanceMeters = routeInfo.distanceKm * 1000.0;
        _remainingDurationMin = routeInfo.durationMinutes;
        final eta = DateTime.now().add(Duration(minutes: _remainingDurationMin));
        _etaTimeStr = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
      });

      _buildMarkers(provider.gardes);

      try {
        final bounds = InAppRouteService.createBounds(routeInfo.points);
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
      } catch (_) {}
    } else {
      setState(() {
        _isCalculatingRoute = false;
      });
      if (mounted) {
        AppToast.showError('Impossible de calculer l\'itinéraire.', context);
      }
    }
  }

  // ─── LIVE TURN-BY-TURN GUIDANCE WITH BEARING & TILT ───
  Future<void> _startLiveNavigation() async {
    if (_currentRouteInfo == null || _currentRouteInfo!.points.isEmpty || _navDestinationPharmacy == null) return;

    final provider = context.read<GardeProvider>();
    LatLng startPos;
    final curr = provider.currentPosition;
    final isTunisia = curr != null && curr.latitude >= 30.0 && curr.latitude <= 38.5 && curr.longitude >= 7.0 && curr.longitude <= 12.5;

    if (isTunisia) {
      startPos = LatLng(curr.latitude, curr.longitude);
    } else {
      startPos = _currentRouteInfo!.points.first;
    }

    _liveUserPosition = startPos;

    // Calculate initial bearing towards second point on route
    if (_currentRouteInfo!.points.length > 1) {
      _currentBearing = InAppRouteService.calculateBearing(startPos, _currentRouteInfo!.points[1]);
    } else {
      _currentBearing = 0.0;
    }

    double initialDistMeters = _currentRouteInfo!.distanceKm * 1000.0;
    if (_navDestinationPharmacy?.lat != null && _navDestinationPharmacy?.lng != null) {
      final destPos = LatLng(_navDestinationPharmacy!.lat!, _navDestinationPharmacy!.lng!);
      initialDistMeters = _calculateDistanceKm(startPos.latitude, startPos.longitude, destPos.latitude, destPos.longitude) * 1000.0;
    }

    final int initialDurationMin = _currentRouteInfo!.durationMinutes > 0
        ? _currentRouteInfo!.durationMinutes
        : (_travelMode == 'driving' ? (initialDistMeters / 450.0) : (initialDistMeters / 80.0)).ceil().clamp(1, 999);
    final eta = DateTime.now().add(Duration(minutes: initialDurationMin));

    setState(() {
      _isLiveGuiding = true;
      _currentStepIndex = 0;
      _remainingDistanceMeters = initialDistMeters;
      _remainingDurationMin = initialDurationMin;
      _etaTimeStr = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';
      _currentSpeedKmH = 0.0;
    });

    _buildMarkers(provider.gardes);

    // 3D driver perspective: zoom 18.5, tilt 50°, bearing aligned with road
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: startPos,
            zoom: 18.5,
            tilt: 50.0,
            bearing: _currentBearing,
          ),
        ),
      );
    } catch (_) {}

    // Listen to real-world GPS stream (only updates when user physically moves)
    _positionStreamSub?.cancel();
    try {
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 2,
        ),
      ).listen((Position pos) {
        if (pos.latitude >= 30.0 && pos.latitude <= 38.5 && pos.longitude >= 7.0 && pos.longitude <= 12.5) {
          _onLiveLocationUpdate(pos);
        }
      });
    } catch (_) {}
  }

  void _onLiveLocationUpdate(Position pos) async {
    if (!_isLiveGuiding || !mounted) return;

    final newPos = LatLng(pos.latitude, pos.longitude);
    _updateRouteProgress(newPos, speed: pos.speed, heading: pos.heading);

    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newPos,
            zoom: 18.5,
            tilt: 50.0,
            bearing: _currentBearing,
          ),
        ),
      );
    } catch (_) {}

    if (mounted) setState(() {});
  }

  void _updateRouteProgress(LatLng newPos, {double? speed, double? heading}) {
    if (!_isNavigating || _fullRoutePoints.isEmpty || _navDestinationPharmacy == null) return;

    _liveUserPosition = newPos;
    if (speed != null) {
      _currentSpeedKmH = (speed * 3.6).clamp(0.0, 160.0);
    }

    if (heading != null && heading > 0 && heading <= 360) {
      _currentBearing = heading;
    }

    // Find closest point index on _fullRoutePoints from current progress forward
    int closestIdx = _lastPassedPolylineIndex;
    double minDist = double.infinity;
    for (int i = _lastPassedPolylineIndex; i < _fullRoutePoints.length; i++) {
      final d = _calculateDistanceKm(newPos.latitude, newPos.longitude, _fullRoutePoints[i].latitude, _fullRoutePoints[i].longitude) * 1000.0;
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    _lastPassedPolylineIndex = closestIdx;

    // Slice remaining polyline points from current user position to destination
    final List<LatLng> remainingPoints = [newPos];
    if (_lastPassedPolylineIndex + 1 < _fullRoutePoints.length) {
      remainingPoints.addAll(_fullRoutePoints.sublist(_lastPassedPolylineIndex + 1));
    } else if (_navDestinationPharmacy?.lat != null && _navDestinationPharmacy?.lng != null) {
      remainingPoints.add(LatLng(_navDestinationPharmacy!.lat!, _navDestinationPharmacy!.lng!));
    }

    if ((heading == null || heading <= 0) && remainingPoints.length > 1) {
      _currentBearing = InAppRouteService.calculateBearing(newPos, remainingPoints[1]);
    }

    // Calculate total remaining distance in meters along the path
    double distAlongPoints = 0.0;
    for (int i = 0; i < remainingPoints.length - 1; i++) {
      distAlongPoints += _calculateDistanceKm(
        remainingPoints[i].latitude,
        remainingPoints[i].longitude,
        remainingPoints[i + 1].latitude,
        remainingPoints[i + 1].longitude,
      ) * 1000.0;
    }

    final destPos = LatLng(_navDestinationPharmacy!.lat!, _navDestinationPharmacy!.lng!);
    final directDistToDest = _calculateDistanceKm(newPos.latitude, newPos.longitude, destPos.latitude, destPos.longitude) * 1000.0;
    final totalRemainingMeters = directDistToDest < 30 ? directDistToDest : (distAlongPoints > 0 ? distAlongPoints : directDistToDest);

    _remainingDistanceMeters = totalRemainingMeters;

    // Calculate remaining duration down to 0 min at destination
    if (totalRemainingMeters <= 25) {
      _remainingDurationMin = 0;
      if (_isLiveGuiding) {
        AppToast.showSuccess('🎉 Vous êtes arrivé à la pharmacie !', context);
      }
    } else {
      _remainingDurationMin = (_travelMode == 'driving'
          ? (totalRemainingMeters / 450.0).ceil()
          : (totalRemainingMeters / 80.0).ceil()).clamp(1, 999);
    }

    final eta = DateTime.now().add(Duration(minutes: _remainingDurationMin));
    _etaTimeStr = '${eta.hour.toString().padLeft(2, '0')}:${eta.minute.toString().padLeft(2, '0')}';

    // Update dynamic trimmed polyline (blue route line shrinks as user moves)
    _polylines = {
      Polyline(
        polylineId: const PolylineId('route_shadow'),
        points: remainingPoints,
        color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
        width: 8,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('route_active'),
        points: remainingPoints,
        color: const Color(0xFF2563EB),
        width: 5,
        jointType: JointType.round,
        endCap: Cap.roundCap,
        startCap: Cap.roundCap,
      ),
    };

    _updateActiveStep(newPos);
  }

  void _updateActiveStep(LatLng userPos) {
    if (_currentRouteInfo == null || _currentRouteInfo!.stepDetails.isEmpty) return;
    for (int i = _currentStepIndex; i < _currentRouteInfo!.stepDetails.length; i++) {
      final step = _currentRouteInfo!.stepDetails[i];
      final d = _calculateDistanceKm(userPos.latitude, userPos.longitude, step.location.latitude, step.location.longitude) * 1000.0;
      if (d < 40 && i + 1 < _currentRouteInfo!.stepDetails.length) {
        _currentStepIndex = i + 1;
        break;
      }
    }
  }

  Future<void> _recenterLiveNavigation() async {
    final target = _liveUserPosition ??
        (_currentRouteInfo != null && _currentRouteInfo!.points.isNotEmpty
            ? _currentRouteInfo!.points.first
            : null);
    if (target == null) return;
    try {
      final controller = await _mapController.future;
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 18.5,
            tilt: 50.0,
            bearing: _currentBearing,
          ),
        ),
      );
    } catch (_) {}
  }

  void _stopLiveGuiding() async {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _guidanceProgressTimer?.cancel();
    _guidanceProgressTimer = null;
    setState(() {
      _isLiveGuiding = false;
    });

    if (_currentRouteInfo != null && _currentRouteInfo!.points.isNotEmpty) {
      final bounds = InAppRouteService.createBounds(_currentRouteInfo!.points);
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
    }
  }

  void _exitInAppRoute() {
    _positionStreamSub?.cancel();
    _positionStreamSub = null;
    _guidanceProgressTimer?.cancel();
    _guidanceProgressTimer = null;
    setState(() {
      _isNavigating = false;
      _isLiveGuiding = false;
      _currentRouteInfo = null;
      _fullRoutePoints = [];
      _lastPassedPolylineIndex = 0;
      _navDestinationPharmacy = null;
      _polylines = {};
      _selectedPharmacy = null;
    });
    _buildMarkers(context.read<GardeProvider>().gardes);
  }

  void _toggleTravelMode(String mode) {
    if (_travelMode == mode) return;
    setState(() {
      _travelMode = mode;
    });
    if (_navDestinationPharmacy != null) {
      _startInAppRoute(_navDestinationPharmacy!);
    }
  }

  void _callPharmacy(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return;
    final Uri uri = Uri.parse('tel:${phone.trim()}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openExternalGps(GardeModel? garde) async {
    if (garde?.lat == null || garde?.lng == null) return;
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${garde!.lat},${garde.lng}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

    final initialTarget = (provider.gardes.isNotEmpty && provider.gardes.first.lat != null && provider.gardes.first.lat != 0)
        ? LatLng(provider.gardes.first.lat!, provider.gardes.first.lng!)
        : _tunisiaDefaultLocation;

    return Scaffold(
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
                compassEnabled: !_isLiveGuiding,
                rotateGesturesEnabled: true,
                tiltGesturesEnabled: true,
                markers: _markers,
                polylines: _polylines,
                onCameraMove: _onCameraMove,
                onCameraIdle: _onCameraIdle,
                onTap: (pos) {
                  if (!_isNavigating && !_isLiveGuiding && _selectedPharmacy != null) {
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
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: provider.gardes.length,
                          separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final ph = provider.gardes[i];
                            return _buildListPharmacyCard(ph);
                          },
                        ),
            ),

          // ─── TOP BAR: LIVE GUIDANCE BANNER OR ROUTE HEADER OR NORMAL HEADER ───
          if (_isLiveGuiding && _navDestinationPharmacy != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: RepaintBoundary(
                child: _buildLiveNavigationTopBanner(topPadding),
              ),
            )
          else
            Positioned(
              top: topPadding + 6,
              left: 10,
              right: 10,
              child: RepaintBoundary(
                child: _isNavigating && _navDestinationPharmacy != null
                    ? _buildInAppRouteHeader()
                    : _buildNormalHeader(provider),
              ),
            ),

          // ─── FLOATING "RECHERCHER DANS CETTE ZONE" BUTTON ───
          if (!_isListView && !_isNavigating && !_isLiveGuiding && _showSearchThisAreaButton)
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

          // ─── LIVE GUIDANCE RIGHT SIDE CONTROLS (Google Maps Style) ───
          if (_isLiveGuiding) ...[
            Positioned(
              right: 16,
              top: topPadding + 140,
              child: Column(
                children: [
                  _buildLiveActionCircle(
                    icon: LucideIcons.compass,
                    iconColor: Colors.redAccent,
                    onTap: _recenterLiveNavigation,
                  ),
                  const SizedBox(height: 10),
                  _buildLiveActionCircle(
                    icon: LucideIcons.globe,
                    iconColor: _isSatellite ? Colors.white : AppColors.forestGreen,
                    bgColor: _isSatellite ? AppColors.forestGreen : Colors.white,
                    onTap: () => setState(() => _isSatellite = !_isSatellite),
                  ),
                  const SizedBox(height: 10),
                  _buildLiveActionCircle(
                    icon: _isMuted ? LucideIcons.volumeX : LucideIcons.volume2,
                    iconColor: _isMuted ? Colors.redAccent : AppColors.forestGreen,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 100,
              left: 16,
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentSpeedKmH > 1 ? '${_currentSpeedKmH.toInt()}' : '--',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const Text(
                      'km/h',
                      style: TextStyle(fontSize: 9.0, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ─── USER LOCATION & OVERVIEW BUTTONS (Bottom Left) ───
          if (!_isListView && !_isLiveGuiding)
            Positioned(
              bottom: (_isNavigating || _selectedPharmacy != null) ? 220 : 16,
              left: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Full Route Overview button (in navigation mode)
                  if (_isNavigating) ...[
                    FloatingActionButton.small(
                      heroTag: 'fab_fit_route',
                      onPressed: _fitRouteOverview,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.forestGreen,
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: const Icon(LucideIcons.maximize2, size: 20),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // User Location Target button
                  FloatingActionButton.small(
                    heroTag: 'fab_user_location',
                    onPressed: _flyToUserLocation,
                    backgroundColor: Colors.white,
                    foregroundColor: _isNavigating ? const Color(0xFF2563EB) : AppColors.forestGreen,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: const Icon(LucideIcons.crosshair, size: 20),
                  ),
                ],
              ),
            ),

          // ─── LIVE GUIDANCE BOTTOM BAR (Floating Card above Bottom Nav) ───
          if (_isLiveGuiding && _navDestinationPharmacy != null)
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: RepaintBoundary(
                child: _buildLiveNavigationBottomBar(),
              ),
            ),

          // ─── IN-APP NAVIGATION PREVIEW PANEL (Before "Démarrer") ───
          if (!_isListView && !_isLiveGuiding && _isNavigating && _navDestinationPharmacy != null)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: RepaintBoundary(
                child: _buildInAppRouteBottomCard(),
              ),
            ),

          // ─── SELECTED PHARMACY BOTTOM PREVIEW CARD ───
          if (!_isListView && !_isNavigating && !_isLiveGuiding && _selectedPharmacy != null)
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: RepaintBoundary(
                child: _buildSelectedPharmacyCard(_selectedPharmacy!),
              ),
            ),

          // ─── INITIAL LOADING OVERLAY (Finding user location & 20 closest pharmacies) ───
          if (_isInitialLocating && provider.isLoading)
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
    );
  }

  // ─── TOP LIVE NAVIGATION BANNER (Dark Emerald Green - Google Maps Style) ───
  Widget _buildLiveNavigationTopBanner(double topPadding) {
    final step = (_currentRouteInfo != null &&
            _currentRouteInfo!.stepDetails.isNotEmpty &&
            _currentStepIndex < _currentRouteInfo!.stepDetails.length)
        ? _currentRouteInfo!.stepDetails[_currentStepIndex]
        : null;

    final nextStep = (_currentRouteInfo != null &&
            _currentRouteInfo!.stepDetails.length > _currentStepIndex + 1)
        ? _currentRouteInfo!.stepDetails[_currentStepIndex + 1]
        : null;

    final mainTarget = step?.streetName.isNotEmpty == true
        ? 'vers ${step!.streetName}'
        : 'vers ${_navDestinationPharmacy?.nomPharmacie ?? "Destination"}';

    IconData maneuverIcon = LucideIcons.arrowUp;
    if (step != null) {
      if (step.modifier.contains('left')) {
        maneuverIcon = LucideIcons.cornerUpLeft;
      } else if (step.modifier.contains('right')) {
        maneuverIcon = LucideIcons.cornerUpRight;
      } else if (step.type.contains('roundabout')) {
        maneuverIcon = LucideIcons.refreshCcw;
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF044E3D), // Google Maps dark green
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Big Maneuver Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(maneuverIcon, color: Colors.white, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step != null ? step.instruction : mainTarget,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _navDestinationPharmacy?.nomPharmacie ?? 'Pharmacie',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (nextStep != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF02382C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Puis ',
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const Icon(LucideIcons.cornerUpRight, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      nextStep.streetName.isNotEmpty ? nextStep.streetName : nextStep.instruction,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── LIVE NAVIGATION BOTTOM BAR (Floating Card above Bottom Navigation) ───
  Widget _buildLiveNavigationBottomBar() {
    final distStr = _remainingDistanceMeters >= 1000
        ? '${(_remainingDistanceMeters / 1000.0).toStringAsFixed(1)} km'
        : '${_remainingDistanceMeters.round()} m';
    final durationStr = (_remainingDistanceMeters <= 25) || _remainingDurationMin == 0
        ? '0 min'
        : '$_remainingDurationMin min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Close / Exit Guidance Button
          InkWell(
            onTap: _stopLiveGuiding,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Icon(LucideIcons.x, size: 20, color: Color(0xFF374151)),
            ),
          ),
          const SizedBox(width: 14),

          // Central Duration & ETA
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  durationStr,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF15803D), // Vivid Green
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$distStr • $_etaTimeStr',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Re-center Navigation Button
          InkWell(
            onTap: _recenterLiveNavigation,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: const Icon(LucideIcons.crosshair, size: 20, color: Color(0xFF2563EB)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveActionCircle({
    required IconData icon,
    required Color iconColor,
    Color bgColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  // ─── NORMAL HEADER WIDGET ───
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
                        _isAreaSearchActive
                            ? '${provider.gardes.length} dans cette zone'
                            : '${provider.gardes.length} à proximité',
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
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => setState(() => _isListView = !_isListView),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: _isListView ? AppColors.forestGreen : Colors.white,
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
                        Icon(
                          _isListView ? LucideIcons.map : LucideIcons.list,
                          size: 15,
                          color: _isListView ? Colors.white : AppColors.forestGreen,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isListView ? 'Carte' : 'Liste',
                          style: TextStyle(
                            color: _isListView ? Colors.white : AppColors.forestGreen,
                            fontSize: 12.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Search & Filter Pills
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
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
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Rechercher pharmacie, ville…',
                    hintStyle: TextStyle(fontSize: 12.0, color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _buildMiniFilter('Tous', provider),
              const SizedBox(width: 3),
              _buildMiniFilter('Jour', provider),
              const SizedBox(width: 3),
              _buildMiniFilter('Nuit', provider),
            ],
          ),
        ),
      ],
    );
  }

  // ─── IN-APP ROUTE HEADER (Route Preview Mode) ───
  Widget _buildInAppRouteHeader() {
    final ph = _navDestinationPharmacy!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Exit Navigation Button
              InkWell(
                onTap: _exitInAppRoute,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(LucideIcons.x, size: 18, color: AppColors.forestGreen),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Itinéraire en direct',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      ph.nomPharmacie ?? 'Pharmacie',
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.forestGreen,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isCalculatingRoute)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primaryGreen),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Mode Toggle Pills (Driving / Walking)
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _toggleTravelMode('driving'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _travelMode == 'driving' ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.car,
                          size: 14,
                          color: _travelMode == 'driving' ? Colors.white : const Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'En voiture',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _travelMode == 'driving' ? Colors.white : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: () => _toggleTravelMode('walking'),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: _travelMode == 'walking' ? const Color(0xFF2563EB) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.footprints,
                          size: 14,
                          color: _travelMode == 'walking' ? Colors.white : const Color(0xFF4B5563),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'À pied',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _travelMode == 'walking' ? Colors.white : const Color(0xFF4B5563),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── IN-APP ROUTE BOTTOM CARD (Google Maps Preview & "Démarrer" button) ───
  Widget _buildInAppRouteBottomCard() {
    final ph = _navDestinationPharmacy!;
    final info = _currentRouteInfo;
    final double distKm = _remainingDistanceMeters > 0 ? (_remainingDistanceMeters / 1000.0) : (info?.distanceKm ?? 0.0);
    final String durationStr = (_remainingDistanceMeters <= 25 && _isNavigating) || _remainingDurationMin == 0
        ? '0 min'
        : '$_remainingDurationMin min';
    final String distanceStr = _remainingDistanceMeters < 1000 && _remainingDistanceMeters > 0
        ? '${_remainingDistanceMeters.round()} m'
        : '${distKm.toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Travel Time Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _travelMode == 'walking' ? const Color(0xFFEFF6FF) : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  durationStr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _travelMode == 'walking' ? const Color(0xFF2563EB) : const Color(0xFF15803D),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          distanceStr,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestGreen,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: Colors.grey)),
                        const SizedBox(width: 6),
                        Text(
                          _travelMode == 'walking' ? 'À pied' : 'Trafic fluide',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _travelMode == 'walking' ? const Color(0xFF2563EB) : AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      ph.adresse?.isNotEmpty == true ? ph.adresse! : 'Destination pharmacie',
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
            ],
          ),
          if (info != null && info.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.cornerUpRight, size: 16, color: Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      info.steps.first,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Action Buttons: Démarrer Navigation (Google Maps Style) & Appeler & Guidage
          Row(
            children: [
              // Google Maps "Démarrer" Button (Cyan/Green Primary)
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: _startLiveNavigation,
                  icon: const Icon(LucideIcons.navigation, size: 16),
                  label: const Text('Démarrer', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E), // Google Maps Navigation Cyan/Green
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // External GPS button
              OutlinedButton.icon(
                onPressed: () => _openExternalGps(ph),
                icon: const Icon(LucideIcons.externalLink, size: 14),
                label: const Text('GPS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB), width: 1.2),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
              ),
              const SizedBox(width: 8),
              // Close Preview
              ElevatedButton(
                onPressed: _exitInAppRoute,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF3F4F6),
                  foregroundColor: const Color(0xFF4B5563),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: const Text('Quitter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniFilter(String label, GardeProvider provider) {
    final isSelected = provider.filterType == label;

    return InkWell(
      onTap: () {
        provider.setFilterType(label);
        _buildMarkers(provider.gardes);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
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
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              if (ph.tel != null && ph.tel!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPharmacy(ph.tel),
                    icon: const Icon(LucideIcons.phoneCall, size: 15),
                    label: const Text('Appeler', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forestGreen,
                      side: const BorderSide(color: AppColors.forestGreen, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (ph.tel != null && ph.tel!.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () => _startInAppRoute(ph),
                  icon: const Icon(LucideIcons.navigation, size: 15),
                  label: const Text('Itinéraire', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
              if (ph.tel != null && ph.tel!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _callPharmacy(ph.tel),
                    icon: const Icon(LucideIcons.phone, size: 14),
                    label: Text(ph.tel!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.forestGreen,
                      side: const BorderSide(color: AppColors.forestGreen),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (ph.tel != null && ph.tel!.isNotEmpty) const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _startInAppRoute(ph),
                  icon: const Icon(LucideIcons.navigation, size: 14),
                  label: const Text('Itinéraire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
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
