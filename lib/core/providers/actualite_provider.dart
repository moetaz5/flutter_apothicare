import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/actualite_model.dart';
import '../network/api_client.dart';

class ActualiteProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<ActualiteModel> _allActualites = [];
  List<ActualiteModel> _filteredActualites = [];
  List<ThemeModel> _themes = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  int? _selectedThemeId;
  bool _isAdminMode = false;

  List<ActualiteModel> get actualites => _filteredActualites;
  List<ActualiteModel> get allActualites => _allActualites;
  List<ThemeModel> get themes => _themes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int? get selectedThemeId => _selectedThemeId;
  String get searchQuery => _searchQuery;

  Future<void> fetchActualites({bool forceRefresh = false, bool isAdmin = false}) async {
    _isAdminMode = isAdmin;
    if (forceRefresh) {
      _api.clearCache('settings');
      _api.clearCache('theme');
    } else if (_allActualites.isNotEmpty) {
      _refreshInBackground(isAdmin: isAdmin);
      return;
    }

    if (_allActualites.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      // 1. Fetch Themes (Cached for 5 minutes)
      await fetchThemes(forceRefresh: forceRefresh);

      // 2. Fetch Actualites
      final endpoint = isAdmin ? 'settings/allActualite' : 'settings/allActiveActualite';
      dynamic response;
      try {
        response = await _api.post(
          endpoint,
          data: {},
          useCache: !forceRefresh,
          cacheDuration: const Duration(minutes: 2),
        );
      } catch (_) {
        if (!isAdmin) {
          response = await _api.post(
            'settings/allActualites',
            data: {},
            useCache: !forceRefresh,
            cacheDuration: const Duration(minutes: 2),
          );
        } else {
          rethrow;
        }
      }

      if (response.data != null && response.data is List) {
        final list = response.data as List;
        _allActualites = list
            .map((item) => ActualiteModel.fromJson(item as Map<String, dynamic>))
            .toList();
      }

      _applyFilters();
    } catch (e) {
      if (_allActualites.isEmpty) {
        _errorMessage = 'Erreur lors du chargement des actualités.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchThemes({bool forceRefresh = false}) async {
    try {
      final themeRes = await _api.post(
        'theme/allTheme',
        data: {},
        useCache: !forceRefresh,
        cacheDuration: const Duration(minutes: 5),
      );
      if (themeRes.data != null && themeRes.data is List) {
        _themes = (themeRes.data as List)
            .map((item) => ThemeModel.fromJson(item as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void _refreshInBackground({bool isAdmin = false}) async {
    try {
      final endpoint = isAdmin ? 'settings/allActualite' : 'settings/allActiveActualite';
      final response = await _api.post(endpoint, data: {});
      if (response.data != null && response.data is List) {
        final list = response.data as List;
        _allActualites = list
            .map((item) => ActualiteModel.fromJson(item as Map<String, dynamic>))
            .toList();
        _applyFilters();
        notifyListeners();
      }
    } catch (_) {}
  }

  // Changer l'état d'une actualité (Activer / Désactiver)
  Future<bool> changeEtatActualite(int id) async {
    try {
      final res = await _api.put('settings/changeEtatActualite/$id');
      if (res.statusCode == 200 || res.statusCode == 201) {
        // Re-fetch or update locally
        await fetchActualites(forceRefresh: true, isAdmin: _isAdminMode);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Obtenir les détails d'une actualité par ID
  Future<ActualiteModel?> getActualiteById(int id) async {
    try {
      final res = await _api.post(
        'settings/getActualite',
        options: Options(headers: {'id': id}),
      );
      if (res.data != null && res.data is Map) {
        return ActualiteModel.fromJson(Map<String, dynamic>.from(res.data));
      }
    } catch (_) {}
    return null;
  }

  // Ajouter ou Modifier une actualité
  Future<bool> saveActualite({
    int? id,
    required String titre,
    required String description,
    int? idTheme,
    String? imagePath,
    String? videoPath,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> formMap = {
        'id': id ?? 0,
        'titre': titre,
        'description': description,
      };

      if (idTheme != null) {
        formMap['id_theme'] = idTheme;
      }

      if (imagePath != null && imagePath.isNotEmpty) {
        formMap['image'] = await MultipartFile.fromFile(
          imagePath,
          filename: imagePath.split('/').last.split(r'\').last,
        );
      }

      if (videoPath != null && videoPath.isNotEmpty) {
        formMap['video'] = await MultipartFile.fromFile(
          videoPath,
          filename: videoPath.split('/').last.split(r'\').last,
        );
      }

      final formData = FormData.fromMap(formMap);
      final response = await _api.post('settings/addActualite', data: formData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchActualites(forceRefresh: true, isAdmin: _isAdminMode);
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Erreur lors de l\'enregistrement de l\'actualité.';
      notifyListeners();
      return false;
    }
  }

  // Ajouter une vue
  Future<void> addVue({required int id, int? idUser}) async {
    try {
      await _api.post('settings/addVueActualite', data: {
        'id': id,
        'idUser': idUser,
      });
    } catch (_) {}
  }

  void setSelectedTheme(int? themeId) {
    if (_selectedThemeId == themeId) return;
    _selectedThemeId = themeId;
    _applyFilters();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    _filteredActualites = _allActualites.where((item) {
      // Theme filter
      if (_selectedThemeId != null && item.idTheme != _selectedThemeId) {
        return false;
      }
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final title = (item.titre ?? '').toLowerCase();
        final desc = (item.description ?? '').toLowerCase();
        if (!title.contains(_searchQuery) && !desc.contains(_searchQuery)) {
          return false;
        }
      }
      return true;
    }).toList();
  }
}
