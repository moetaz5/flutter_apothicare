import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/garde_model.dart';
import '../network/api_client.dart';

class GardeProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<GardeModel> _allGardes = [];
  List<GardeModel> _filteredGardes = [];
  List<String> _searchIndices = []; // precomputed lowercase search strings for high performance
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;
  String _searchQuery = '';
  String _filterType = 'Tous'; // 'Tous', 'Jour', 'Nuit'

  List<GardeModel> get gardes => _filteredGardes;
  List<GardeModel> get allGardes => _allGardes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Position? get currentPosition => _currentPosition;
  String get filterType => _filterType;

  // Calculate distance between coordinates
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  // Fetch Duty Pharmacies (Gardes) with fast caching
  Future<void> fetchGardes({bool isNightOnly = false, bool forceRefresh = false}) async {
    // If we already have data in memory and not forcing refresh, don't block
    if (_allGardes.isNotEmpty && !forceRefresh) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Get last known location instantly without waiting
      Geolocator.getLastKnownPosition().then((pos) {
        if (pos != null) {
          _currentPosition = pos;
          _recomputeDistancesAndSort();
        }
      }).catchError((_) {});

      // 2. Fetch API data immediately
      final endpoint = isNightOnly ? 'garde/allGardes' : 'garde/getGardesForPatient';
      final response = await _api.post(endpoint, data: {}, useCache: true, forceRefresh: forceRefresh);

      if (response.data != null && response.data is List) {
        final rawList = response.data as List;
        final currLat = _currentPosition?.latitude;
        final currLng = _currentPosition?.longitude;
        final hasLocation = currLat != null && currLng != null && currLat >= 30 && currLat <= 38;

        final refLat = hasLocation ? currLat : 34.7406; // Default Sfax / Tunisia center
        final refLng = hasLocation ? currLng : 10.7603;

        _allGardes = rawList.map((item) {
          var garde = GardeModel.fromJson(item as Map<String, dynamic>);
          if (garde.lat != null && garde.lng != null && garde.lat != 0) {
            final dist = _calculateDistance(refLat, refLng, garde.lat!, garde.lng!);
            garde = garde.copyWithDistance(dist);
          }
          return garde;
        }).toList();

        // Sort by distance to user or Tunisia center
        _allGardes.sort((a, b) => (a.distanceInKm ?? 99999).compareTo(b.distanceInKm ?? 99999));

        // Build precomputed search index for instant filtering
        _searchIndices = _allGardes.map((g) {
          return '${g.nomPharmacie ?? ''} ${g.adresse ?? ''} ${g.tel ?? ''}'.toLowerCase();
        }).toList();

        _applyFilters(notify: false, limit: 20);
      }
      _isLoading = false;
      notifyListeners();

      // 3. Request fresh GPS coordinates in background without blocking UI
      _updateLocationInBackground();
    } catch (e) {
      _errorMessage = 'Impossible de charger la liste des pharmacies.';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateLocationInBackground() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 4),
        );
        if (pos.latitude >= 30 && pos.latitude <= 38) {
          _currentPosition = pos;
          _recomputeDistancesAndSort();
        }
      }
    } catch (_) {}
  }

  void _recomputeDistancesAndSort() {
    if (_currentPosition == null || _allGardes.isEmpty) return;
    final currLat = _currentPosition!.latitude;
    final currLng = _currentPosition!.longitude;
    final isTunisia = currLat >= 30 && currLat <= 38 && currLng >= 7 && currLng <= 12.5;

    if (!isTunisia) return;

    _allGardes = _allGardes.map((garde) {
      if (garde.lat != null && garde.lng != null && garde.lat != 0) {
        final dist = _calculateDistance(currLat, currLng, garde.lat!, garde.lng!);
        return garde.copyWithDistance(dist);
      }
      return garde;
    }).toList();

    _allGardes.sort((a, b) => (a.distanceInKm ?? 99999).compareTo(b.distanceInKm ?? 99999));
    _applyFilters(notify: true, limit: 20);
  }

  int get totalOpenCount => _allGardes.length;

  void resetToProximity({int limit = 20, Position? position}) {
    if (position != null) {
      _currentPosition = position;
    }
    _searchQuery = '';
    _filterType = 'Tous';

    if (_allGardes.isEmpty) return;

    final currLat = _currentPosition?.latitude;
    final currLng = _currentPosition?.longitude;
    final hasLocation = currLat != null && currLng != null && currLat >= 30.0 && currLat <= 38.5 && currLng >= 7.0 && currLng <= 12.5;

    final refLat = hasLocation ? currLat : 34.7406;
    final refLng = hasLocation ? currLng : 10.7603;

    for (int i = 0; i < _allGardes.length; i++) {
      final g = _allGardes[i];
      if (g.lat != null && g.lng != null && g.lat != 0) {
        final dist = _calculateDistance(refLat, refLng, g.lat!, g.lng!);
        _allGardes[i] = g.copyWithDistance(dist);
      }
    }

    _allGardes.sort((a, b) => (a.distanceInKm ?? 99999).compareTo(b.distanceInKm ?? 99999));
    _applyFilters(notify: true, limit: limit);
  }

  void searchInArea(double centerLat, double centerLng, {int? limit}) {
    if (_allGardes.isEmpty) return;

    _allGardes = _allGardes.map((garde) {
      if (garde.lat != null && garde.lng != null && garde.lat != 0) {
        final dist = _calculateDistance(centerLat, centerLng, garde.lat!, garde.lng!);
        return garde.copyWithDistance(dist);
      }
      return garde;
    }).toList();

    _allGardes.sort((a, b) => (a.distanceInKm ?? 99999).compareTo(b.distanceInKm ?? 99999));
    _applyFilters(notify: true, limit: limit);
  }

  void searchInBounds({
    required double minLat,
    required double maxLat,
    required double minLng,
    required double maxLng,
    double? centerLat,
    double? centerLng,
  }) {
    if (_allGardes.isEmpty) return;

    final double cLat = centerLat ?? ((minLat + maxLat) / 2);
    final double cLng = centerLng ?? ((minLng + maxLng) / 2);

    final isAllTypes = _filterType == 'Tous';
    final targetTypeLower = _filterType.toLowerCase();
    final hasSearch = _searchQuery.isNotEmpty;

    final List<GardeModel> inBounds = [];

    // Add 4% padding around screen bounds so edge markers are not cut off
    final latPad = (maxLat - minLat).abs() * 0.04;
    final lngPad = (maxLng - minLng).abs() * 0.04;
    final effectiveMinLat = (minLat < maxLat ? minLat : maxLat) - latPad;
    final effectiveMaxLat = (minLat < maxLat ? maxLat : minLat) + latPad;
    final effectiveMinLng = (minLng < maxLng ? minLng : maxLng) - lngPad;
    final effectiveMaxLng = (minLng < maxLng ? maxLng : minLng) + lngPad;

    for (int i = 0; i < _allGardes.length; i++) {
      final g = _allGardes[i];
      if (g.lat == null || g.lng == null || g.lat == 0 || g.lng == 0) continue;

      if (g.lat! >= effectiveMinLat &&
          g.lat! <= effectiveMaxLat &&
          g.lng! >= effectiveMinLng &&
          g.lng! <= effectiveMaxLng) {
        if (!isAllTypes) {
          final gType = g.typeGarde?.toLowerCase() ?? 'jour';
          if (gType != targetTypeLower) continue;
        }

        if (hasSearch) {
          if (i < _searchIndices.length && !_searchIndices[i].contains(_searchQuery)) continue;
        }

        final dist = _calculateDistance(cLat, cLng, g.lat!, g.lng!);
        inBounds.add(g.copyWithDistance(dist));
      }
    }

    inBounds.sort((a, b) => (a.distanceInKm ?? 99999).compareTo(b.distanceInKm ?? 99999));

    _filteredGardes = inBounds;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (_searchQuery == clean) return;
    _searchQuery = clean;
    _applyFilters(notify: true);
  }

  void setFilterType(String type) {
    if (_filterType == type) return;
    _filterType = type;
    _applyFilters(notify: true);
  }

  void _applyFilters({bool notify = true, int? limit}) {
    if (_allGardes.isEmpty) {
      _filteredGardes = [];
      if (notify) notifyListeners();
      return;
    }

    final isAllTypes = _filterType == 'Tous';
    final targetTypeLower = _filterType.toLowerCase();
    final hasSearch = _searchQuery.isNotEmpty;

    final List<GardeModel> results = [];
    final count = _allGardes.length;

    for (int i = 0; i < count; i++) {
      final g = _allGardes[i];

      // Filter type check
      if (!isAllTypes) {
        final gType = g.typeGarde?.toLowerCase() ?? 'jour';
        if (gType != targetTypeLower) continue;
      }

      // Search query check
      if (hasSearch) {
        if (i < _searchIndices.length && !_searchIndices[i].contains(_searchQuery)) continue;
      }

      results.add(g);
      if (limit != null && results.length >= limit) break;
    }

    _filteredGardes = results;
    if (notify) notifyListeners();
  }

  Future<List<dynamic>> fetchGardesByCnopt({required String annee, required dynamic numCnopt}) async {
    try {
      final response = await _api.post('garde/fetchGardesByCnopt', data: {
        'annee': annee,
        'num_cnopt': numCnopt,
      });
      if (response.data is List) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching gardes by cnopt: $e');
      return [];
    }
  }

  Future<void> logPdfDownloadHistory() async {
    try {
      await _api.post('historique/update', data: {});
    } catch (_) {}
  }
}
