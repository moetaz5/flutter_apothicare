import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';

class TraitementProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<dynamic> _traitements = [];
  bool _isLoading = false;
  String? _selectedCategory;
  String _searchQuery = '';

  List<dynamic> get traitements => _traitements;
  bool get isLoading => _isLoading;
  String? get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  List<Map<String, dynamic>> get categories {
    final List<Map<String, dynamic>> cats = [];
    final Set<dynamic> seenIds = {};

    for (final item in _traitements) {
      if (item is Map && item['categories'] is Map) {
        final cat = item['categories'] as Map<String, dynamic>;
        final id = cat['id'];
        if (id != null && !seenIds.contains(id)) {
          seenIds.add(id);
          cats.add(cat);
        }
      }
    }
    return cats;
  }

  List<dynamic> get filteredTraitements {
    return _traitements.where((item) {
      if (item is! Map) return false;
      final nom = (item['nom'] ?? '').toString().toLowerCase();
      final doctor = (item['doctor'] ?? '').toString().toLowerCase();
      final catName = (item['categories'] is Map ? item['categories']['nom'] ?? '' : '').toString().toLowerCase();

      final matchesQuery = _searchQuery.isEmpty ||
          nom.contains(_searchQuery.toLowerCase()) ||
          doctor.contains(_searchQuery.toLowerCase()) ||
          catName.contains(_searchQuery.toLowerCase());

      final catId = item['categories'] is Map ? item['categories']['id']?.toString() : null;
      final matchesCategory = _selectedCategory == null || _selectedCategory!.isEmpty || catId == _selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  void setCategory(String? catId) {
    _selectedCategory = catId;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchTraitements({int? annee, dynamic patientId, int? idRole, bool forceRefresh = false}) async {
    if (_traitements.isNotEmpty && !forceRefresh) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    final currentYear = annee ?? DateTime.now().year;

    try {
      if (idRole == 1) {
        final response = await _api.post(
          'traitement/allTraitement',
          data: {'annee': currentYear},
        );
        if (response.data is List) {
          _traitements = response.data;
        } else {
          _traitements = [];
        }
      } else {
        final response = await _api.post(
          'traitement/getTraitementsByPatient',
          data: {'annee': currentYear, 'id_patient': patientId},
        );
        if (response.data is List) {
          _traitements = response.data;
        } else {
          _traitements = [];
        }
      }
    } catch (e) {
      _traitements = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getTraitementById(dynamic id) async {
    try {
      final response = await _api.post(
        'traitement/getTraitement',
        options: Options(headers: {'id': id.toString()}),
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> sendQuizResponse({
    required dynamic patientId,
    required int point,
    required dynamic traitementId,
  }) async {
    try {
      final response = await _api.post(
        'traitement/sendResponse',
        data: {
          'id_patient': patientId,
          'point': point,
          'id_traitement': traitementId,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
