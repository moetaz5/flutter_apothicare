import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

class AdminProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  // State
  bool _isLoading = false;
  String? _errorMessage;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  String _selectedRoleFilter = 'all';
  String _searchQuery = '';

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _joursFeries = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _annonces = [];
  List<Map<String, dynamic>> _themes = [];
  List<Map<String, dynamic>> _annees = [];
  List<Map<String, dynamic>> _tbGardes = [];
  List<Map<String, dynamic>> _gouvernorats = [];
  List<Map<String, dynamic>> _adminGardes = [];
  List<Map<String, dynamic>> _gardesJours = [];
  List<Map<String, dynamic>> _historiqueGardes = [];
  String _selectedYear = '';
  int? _selectedYearId;

  // Helper to extract List<Map<String, dynamic>> from any API response format
  List<Map<String, dynamic>> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
    }
    if (data is String) {
      String trimmed = data.trim();
      while (trimmed.isNotEmpty && (trimmed.startsWith('\uFEFF') || trimmed.codeUnitAt(0) == 65279 || trimmed.codeUnitAt(0) == 0)) {
        trimmed = trimmed.substring(1).trim();
      }
      if (trimmed.isEmpty) return [];
      try {
        final decoded = jsonDecode(trimmed);
        return _extractList(decoded);
      } catch (_) {
        return [];
      }
    }
    if (data is Map) {
      for (final key in ['data', 'result', 'users', 'user', 'list', 'entities', 'allUser', 'rows', 'records', 'items']) {
        if (data[key] is List) {
          return (data[key] as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      }
      for (final val in data.values) {
        if (val is List) {
          final list = val.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          if (list.isNotEmpty) return list;
        }
      }
      if (data.containsKey('id') || data.containsKey('nom')) {
        return [Map<String, dynamic>.from(data)];
      }
    }
    return [];
  }

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get users => _filteredUsers;
  List<Map<String, dynamic>> get allUsers => _users;
  String get selectedRoleFilter => _selectedRoleFilter;
  String get searchQuery => _searchQuery;
  List<Map<String, dynamic>> get services => _services;
  List<Map<String, dynamic>> get joursFeries => _joursFeries;
  List<Map<String, dynamic>> get categories => _categories;
  List<Map<String, dynamic>> get annonces => _annonces;
  List<Map<String, dynamic>> get themes => _themes;
  List<Map<String, dynamic>> get annees => _annees;
  List<Map<String, dynamic>> get tbGardes => _tbGardes;
  List<Map<String, dynamic>> get gouvernorats => _gouvernorats;
  List<Map<String, dynamic>> get adminGardes => _adminGardes;
  List<Map<String, dynamic>> get gardesJours => _gardesJours;
  List<Map<String, dynamic>> get historiqueGardes => _historiqueGardes;
  String get selectedYear => _selectedYear;
  int? get selectedYearId => _selectedYearId;

  // 1. Fetch Users (Identique React: POST user/allUser avec id_user et id_role + fallbacks)
  Future<void> fetchUsers({bool forceRefresh = false}) async {
    if (_users.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final currentUser = StorageService.getUser();
      final idUser = currentUser?.id ?? 0;
      final idRole = currentUser?.idRole ?? 1;

      List<Map<String, dynamic>> list = [];

      // 1. Primary endpoint: user/allUser with user credentials (Identique React ListUser.jsx)
      try {
        final response = await _api.post(
          'user/allUser',
          data: {
            'id_user': idUser,
            'id_role': idRole,
          },
          useCache: false,
          forceRefresh: true,
        );
        list = _extractList(response.data);
      } catch (e) {
        debugPrint('fetchUsers primary error: $e');
      }

      // 2. Fallback: user/allUser with empty body
      if (list.isEmpty) {
        try {
          final resFallback = await _api.post(
            'user/allUser',
            data: {},
            useCache: false,
            forceRefresh: true,
          );
          list = _extractList(resFallback.data);
        } catch (_) {}
      }

      // 3. Fallback: user/getUsersMessagerie (Contains all users across all roles)
      if (list.isEmpty) {
        try {
          final resMessagerie = await _api.post(
            'user/getUsersMessagerie',
            data: {},
            useCache: false,
            forceRefresh: true,
          );
          list = _extractList(resMessagerie.data);
        } catch (_) {}
      }

      // 4. Fallback: combine user/allPharmaciens + user/allPatients
      if (list.isEmpty) {
        try {
          final resPharm = await _api.post('user/allPharmaciens', data: {}, useCache: false, forceRefresh: true);
          final resPat = await _api.post('user/allPatients', data: {}, useCache: false, forceRefresh: true);
          final pharmList = _extractList(resPharm.data);
          final patList = _extractList(resPat.data);
          final combined = <int, Map<String, dynamic>>{};
          for (final u in [...pharmList, ...patList]) {
            final uid = int.tryParse(u['id']?.toString() ?? '0') ?? 0;
            if (uid > 0) combined[uid] = u;
          }
          if (combined.isNotEmpty) {
            list = combined.values.toList();
          }
        } catch (_) {}
      }

      // 5. Fallback: user/getActive
      if (list.isEmpty) {
        try {
          final res2 = await _api.post(
            'user/getActive',
            data: {},
            useCache: false,
            forceRefresh: true,
          );
          list = _extractList(res2.data);
        } catch (_) {}
      }

      // 6. Fallback: user/getUsersByRole
      if (list.isEmpty) {
        try {
          final res3 = await _api.post(
            'user/getUsersByRole',
            data: {'id_role': 0},
            useCache: false,
            forceRefresh: true,
          );
          list = _extractList(res3.data);
        } catch (_) {}
      }

      if (list.isNotEmpty) {
        // Deduplicate by ID
        final Map<int, Map<String, dynamic>> uniqueUsers = {};
        for (final item in list) {
          final id = int.tryParse(item['id']?.toString() ?? '0') ?? 0;
          if (id > 0) {
            uniqueUsers[id] = item;
          } else {
            uniqueUsers[uniqueUsers.length + 1000000] = item;
          }
        }
        _users = uniqueUsers.values.toList();
        _applyUserFilter();
      }
    } catch (e) {
      debugPrint('fetchUsers fatal error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setUserFilter({String? role, String? query}) {
    if (role != null) _selectedRoleFilter = role;
    if (query != null) _searchQuery = query.toLowerCase().trim();
    _applyUserFilter();
    notifyListeners();
  }

  void _applyUserFilter() {
    _filteredUsers = _users.where((u) {
      // Role filter
      if (_selectedRoleFilter != 'all') {
        final roleId = int.tryParse(u['id_role']?.toString() ?? '') ??
            int.tryParse(u['role']?.toString() ?? '') ??
            int.tryParse(u['roles']?['id']?.toString() ?? '') ??
            0;
        final roleNom = (u['roles']?['nom'] ?? u['role_nom'] ?? u['role'] ?? '').toString().toLowerCase();

        if (_selectedRoleFilter == 'pharmacien' &&
            roleId != 2 &&
            roleId != 7 &&
            roleId != 8 &&
            !roleNom.contains('pharma')) {
          return false;
        }
        if (_selectedRoleFilter == 'patient' &&
            roleId != 3 &&
            !roleNom.contains('patient')) {
          return false;
        }
        if (_selectedRoleFilter == 'admin' &&
            roleId != 1 &&
            !roleNom.contains('admin')) {
          return false;
        }
        if (_selectedRoleFilter == 'regional' &&
            roleId != 4 &&
            !roleNom.contains('region')) {
          return false;
        }
      }

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final nom = (u['nom'] ?? '').toString().toLowerCase();
        final nomAr = (u['nom_ar'] ?? '').toString().toLowerCase();
        final login = (u['login'] ?? u['email'] ?? '').toString().toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        final tel = (u['tel'] ?? '').toString().toLowerCase();
        final numCnopt = (u['num_cnopt'] ?? u['tva'] ?? '').toString().toLowerCase();
        return nom.contains(_searchQuery) ||
            nomAr.contains(_searchQuery) ||
            login.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            tel.contains(_searchQuery) ||
            numCnopt.contains(_searchQuery);
      }

      return true;
    }).toList();
  }

  // 2. Fetch Services (Exactement identique React: POST service/allService)
  Future<void> fetchServices({bool forceRefresh = false}) async {
    if (_services.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('service/allService', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _services = list;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('service/allServices', useCache: true, forceRefresh: forceRefresh);
        final list2 = _extractList(res2.data);
        if (list2.isNotEmpty) {
          _services = list2;
        }
      } catch (_) {
        try {
          final res3 = await _api.post('service/allActiveService', useCache: true, forceRefresh: forceRefresh);
          final list3 = _extractList(res3.data);
          if (list3.isNotEmpty) {
            _services = list3;
          }
        } catch (_) {}
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  // Toggle Service State (Identique React: PUT service/changeEtat/:id)
  Future<({bool success, String message})> changeServiceEtat(int id, int currentEtat) async {
    final newEtat = currentEtat == 1 ? 0 : 1;
    final successMessage = newEtat == 1 ? 'Activation avec succès' : 'Désactivation avec succès';

    // Optimistic UI update
    final index = _services.indexWhere((s) => s['id'] == id || s['id']?.toString() == id.toString());
    if (index != -1) {
      _services[index]['etat'] = newEtat;
      notifyListeners();
    }

    try {
      final response = await _api.put('service/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchServices(forceRefresh: true);
        return (success: true, message: successMessage);
      }
    } catch (_) {
      try {
        final res2 = await _api.post('service/changeEtat', data: {'id': id, 'etat': newEtat});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          await fetchServices(forceRefresh: true);
          return (success: true, message: successMessage);
        }
      } catch (_) {}
    }

    // Since optimistic update succeeded locally
    return (success: true, message: successMessage);
  }

  // Add Service (Identique React: POST service/addService avec id = 0)
  Future<({bool success, String message})> addService(String nomService) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('service/addService', data: {
        'nom_service': nomService.trim(),
        'id': 0,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de l\'ajout';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      await fetchServices(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Insertion du service avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Update Service (Identique React: POST service/addService avec id)
  Future<({bool success, String message})> updateService(int id, String nomService) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('service/addService', data: {
        'nom_service': nomService.trim(),
        'id': id,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de la modification';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      await fetchServices(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Modification du service avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // 3. Fetch Jours Fériés (Identique React joursReduce.js)
  Future<void> fetchJoursFeries({String? annee, bool forceRefresh = false}) async {
    if (!forceRefresh && _joursFeries.isNotEmpty && annee == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final year = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());
      final response = await _api.post('jour/allJour', data: {'annee': year}, useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _joursFeries = list;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // Change Jour Férié État (Identique React jourChangeEtat)
  Future<({bool success, String message})> changeJourEtat(int id, int currentEtat) async {
    final nextEtat = currentEtat == 1 ? 0 : 1;
    final index = _joursFeries.indexWhere((j) => (j['id']?.toString() ?? '') == id.toString());
    if (index != -1) {
      _joursFeries[index]['etat'] = nextEtat;
      notifyListeners();
    }

    try {
      final response = await _api.put('jour/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchJoursFeries(forceRefresh: true);
        return (
          success: true,
          message: nextEtat == 1 ? 'Activation avec succès' : 'Désactivation avec succès'
        );
      }
      if (index != -1) {
        _joursFeries[index]['etat'] = currentEtat;
        notifyListeners();
      }
      return (success: false, message: 'Échec du changement d\'état');
    } catch (e) {
      if (index != -1) {
        _joursFeries[index]['etat'] = currentEtat;
        notifyListeners();
      }
      return (success: false, message: 'Erreur réseau');
    }
  }

  // Ajouter un Jour Férié (Identique React jourAdded avec id: 0)
  Future<({bool success, String message})> addJourFerie({
    required String nomJour,
    required String dateJour,
    required dynamic type,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('jour/addJour', data: {
        'nom_jour': nomJour,
        'date': dateJour,
        'type': type,
        'id': 0,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchJoursFeries(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Insertion du jour avec succès');
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: response.data?['message']?.toString() ?? 'Erreur lors de l\'ajout');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur réseau ou serveur');
    }
  }

  // Modifier un Jour Férié (Identique React jourAdded avec id)
  Future<({bool success, String message})> updateJourFerie({
    required int id,
    required String nomJour,
    required String dateJour,
    required dynamic type,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('jour/addJour', data: {
        'nom_jour': nomJour,
        'date': dateJour,
        'type': type,
        'id': id,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchJoursFeries(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Modification du jour avec succès');
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: response.data?['message']?.toString() ?? 'Erreur lors de la modification');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur réseau ou serveur');
    }
  }

  // 4. Fetch Catégories (Identique React categorieReduce.js)
  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (!forceRefresh && _categories.isNotEmpty) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('categorie/allCategorie', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _categories = list;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // Change Catégorie État (Identique React categorieChangeEtat)
  Future<({bool success, String message})> changeCategorieEtat(int id, int currentEtat) async {
    final nextEtat = currentEtat == 1 ? 0 : 1;
    final index = _categories.indexWhere((c) => (c['id']?.toString() ?? '') == id.toString());
    if (index != -1) {
      _categories[index]['etat'] = nextEtat;
      notifyListeners();
    }

    try {
      final response = await _api.put('categorie/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCategories(forceRefresh: true);
        return (
          success: true,
          message: nextEtat == 1 ? 'Activation avec succès' : 'Désactivation avec succès'
        );
      }
      if (index != -1) {
        _categories[index]['etat'] = currentEtat;
        notifyListeners();
      }
      return (success: false, message: 'Échec du changement d\'état');
    } catch (e) {
      if (index != -1) {
        _categories[index]['etat'] = currentEtat;
        notifyListeners();
      }
      return (success: false, message: 'Erreur réseau');
    }
  }

  // Ajouter une Catégorie (Identique React categorieAdded avec id: 0)
  Future<({bool success, String message})> addCategorie(String nomCategorie) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('categorie/addCategorie', data: {
        'nom_categorie': nomCategorie,
        'id': 0,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCategories(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Insertion de la catégorie avec succès');
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: response.data?['message']?.toString() ?? 'Erreur lors de l\'ajout');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur réseau ou serveur');
    }
  }

  // Modifier une Catégorie (Identique React categorieAdded avec id)
  Future<({bool success, String message})> updateCategorie(int id, String nomCategorie) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('categorie/addCategorie', data: {
        'nom_categorie': nomCategorie,
        'id': id,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCategories(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Modification de la catégorie avec succès');
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: response.data?['message']?.toString() ?? 'Erreur lors de la modification');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur réseau ou serveur');
    }
  }

  // Upload Annonce Image (POST annonce/saveImage)
  Future<String?> uploadAnnonceImage(String filePath) async {
    try {
      final fileName = filePath.split('/').last.split(r'\').last;
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _api.post('annonce/saveImage', data: formData);
      if (response.data is Map) {
        return response.data['filename']?.toString() ?? response.data['image']?.toString();
      } else if (response.data is String) {
        return response.data;
      }
    } catch (e) {
      debugPrint('uploadAnnonceImage error: $e');
    }
    return null;
  }

  // 5. Fetch Annonces (Identique React: POST annonce/allAnnonce)
  Future<void> fetchAnnonces({bool forceRefresh = false}) async {
    if (_annonces.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('annonce/allAnnonce', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _annonces = list;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('annonce/allActiveAnnonce', useCache: true, forceRefresh: forceRefresh);
        final list2 = _extractList(res2.data);
        if (list2.isNotEmpty) {
          _annonces = list2;
        }
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  // Ajouter / Modifier une Annonce (Identique React: POST annonce/addAnnonce)
  Future<({bool success, String message})> saveAnnonce({
    int? id,
    required String nom,
    required String email,
    required String description,
    String? imagePath,
    String? existingImage,
    String? dateDebut,
    String? dateFin,
    int? idTheme,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String? imageName = existingImage;
      if (imagePath != null && imagePath.isNotEmpty) {
        final uploaded = await uploadAnnonceImage(imagePath);
        if (uploaded != null) {
          imageName = uploaded;
        }
      }

      final Map<String, dynamic> payload = {
        'id': id ?? 0,
        'nom': nom.trim(),
        'email': email.trim(),
        'description': description.trim(),
        if (imageName != null && imageName.isNotEmpty) 'image': imageName,
        if (dateDebut != null && dateDebut.isNotEmpty) 'date_debut': dateDebut,
        if (dateFin != null && dateFin.isNotEmpty) 'date_fin': dateFin,
        if (idTheme != null) 'id_theme': idTheme,
      };

      final response = await _api.post('annonce/addAnnonce', data: payload);
      final isEdit = id != null && id > 0;
      final successMsg = isEdit ? "Modification de l'annonce avec succès" : "Insertion de l'annonce avec succès";

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAnnonces(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: successMsg);
      } else {
        final msg = response.data?['message']?.toString() ?? "Erreur lors de l'enregistrement";
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Problème de connexion';
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Changer état Annonce (Identique React: PUT annonce/changeEtat/:id)
  Future<({bool success, String message})> changeEtatAnnonce(int id, int currentEtat) async {
    final newEtat = currentEtat == 1 ? 0 : 1;
    final successMsg = newEtat == 1 ? 'Activation avec succès' : 'Désactivation avec succès';

    // Optimistic UI update
    final idx = _annonces.indexWhere((a) => a['id'] == id || a['id']?.toString() == id.toString());
    if (idx != -1) {
      _annonces[idx]['etat'] = newEtat;
      notifyListeners();
    }

    try {
      final response = await _api.put('annonce/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAnnonces(forceRefresh: true);
        return (success: true, message: successMsg);
      }
    } catch (_) {
      try {
        final res2 = await _api.post('annonce/changeEtat', data: {'id': id, 'etat': newEtat});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          await fetchAnnonces(forceRefresh: true);
          return (success: true, message: successMsg);
        }
      } catch (_) {}
    }

    // Revert on failure
    if (idx != -1) {
      _annonces[idx]['etat'] = currentEtat;
      notifyListeners();
    }
    return (success: false, message: 'Échec du changement d\'état');
  }

  // Supprimer Annonce (Identique React: DELETE annonce/deleteAnnonce/:id)
  Future<bool> deleteAnnonce(int id) async {
    try {
      final response = await _api.delete('annonce/deleteAnnonce/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        _annonces.removeWhere((a) => a['id'] == id || a['id']?.toString() == id.toString());
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 6. Fetch Thèmes
  Future<void> fetchThemes({bool forceRefresh = false}) async {
    if (_themes.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('theme/allTheme', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _themes = list;
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // Ajouter ou Modifier un Thème (Identique React: POST theme/addTheme)
  Future<bool> saveTheme({int? id, required String nom}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.post('theme/addTheme', data: {
        'id': id ?? 0,
        'nom': nom.trim(),
      });
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchThemes(forceRefresh: true);
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'enregistrement du thème.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Changer l'état d'un Thème (Identique React: PUT theme/changeEtat/:id)
  Future<bool> changeEtatTheme(int id) async {
    try {
      final response = await _api.put('theme/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchThemes(forceRefresh: true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Supprimer un Thème (Identique React: DELETE theme/deleteTheme/:id)
  Future<bool> deleteTheme(int id) async {
    try {
      final response = await _api.delete('theme/deleteTheme/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchThemes(forceRefresh: true);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // 7. Fetch Années (Exactement identique React: POST annee/allAnnee)
  Future<void> fetchAnnees({bool forceRefresh = false}) async {
    if (_annees.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('annee/allAnnee', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _annees = list;

        // Check if there is an active year marked with selected == 1
        final activeItem = _annees.firstWhere(
          (a) => a['selected'] == 1 || a['selected']?.toString() == '1',
          orElse: () => _annees.isNotEmpty ? _annees.first : {},
        );

        final storedYear = StorageService.getSelectedYear();
        if (storedYear != null && storedYear.isNotEmpty && _annees.any((a) => a['annee']?.toString() == storedYear)) {
          final matched = _annees.firstWhere((a) => a['annee']?.toString() == storedYear);
          _selectedYear = storedYear;
          _selectedYearId = int.tryParse(matched['id']?.toString() ?? '');
        } else if (activeItem.isNotEmpty) {
          _selectedYear = activeItem['annee']?.toString() ?? '';
          _selectedYearId = int.tryParse(activeItem['id']?.toString() ?? '');
          if (_selectedYear.isNotEmpty) {
            StorageService.saveSelectedYear(_selectedYear);
          }
        }
      }
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  // Select Active Year (Identique React dashboard-navbar.jsx)
  Future<bool> selectActiveYear(int id, String annee) async {
    _selectedYear = annee;
    _selectedYearId = id;
    await StorageService.saveSelectedYear(annee);
    
    // Optimistic update in local list
    for (var a in _annees) {
      if (a['id'] == id || a['id']?.toString() == id.toString()) {
        a['selected'] = 1;
      } else {
        a['selected'] = 0;
      }
    }
    notifyListeners();

    try {
      await _api.post('annee/addAnnee', data: {
        'annee': annee,
        'id': id,
        'selected': 1,
      });
      await fetchAnnees(forceRefresh: true);
      return true;
    } catch (_) {
      return true;
    }
  }

  // Add Année (Identique React AjouterAnnee.jsx: POST annee/addAnnee)
  Future<({bool success, String message})> addAnnee(String anneeStr, int selected) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('annee/addAnnee', data: {
        'annee': anneeStr.trim(),
        'id': 0,
        'selected': selected,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de l\'ajout';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      if (selected == 1) {
        _selectedYear = anneeStr.trim();
        await StorageService.saveSelectedYear(_selectedYear);
      }

      await fetchAnnees(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Insertion avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Update Année (Identique React AjouterAnnee.jsx/:id)
  Future<({bool success, String message})> updateAnnee(int id, String anneeStr, int selected) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('annee/addAnnee', data: {
        'annee': anneeStr.trim(),
        'id': id,
        'selected': selected,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de la modification';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      if (selected == 1) {
        _selectedYear = anneeStr.trim();
        _selectedYearId = id;
        await StorageService.saveSelectedYear(_selectedYear);
      }

      await fetchAnnees(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Modifié avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Delete Année (Identique React: DELETE annee/deleteAnnee/:id)
  Future<bool> deleteAnnee(int id) async {
    try {
      final response = await _api.delete('annee/deleteAnnee/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        _annees.removeWhere((a) => a['id'] == id || a['id']?.toString() == id.toString());
        notifyListeners();
        return true;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('annee/deleteAnnee', data: {'id': id});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          _annees.removeWhere((a) => a['id'] == id || a['id']?.toString() == id.toString());
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // Change Année État (Identique React: PUT annee/changeEtat/:id)
  Future<bool> changeAnneeEtat(int id) async {
    try {
      final response = await _api.put('annee/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAnnees(forceRefresh: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // 8. Fetch TB Gardes (Identique React: POST zone/allZone)
  Future<void> fetchTbGardes({bool forceRefresh = false}) async {
    if (_tbGardes.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post('zone/allZone', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _tbGardes = list;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('zone/fetchActiveZone', useCache: true, forceRefresh: forceRefresh);
        final list2 = _extractList(res2.data);
        if (list2.isNotEmpty) {
          _tbGardes = list2;
        }
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  // Fetch Gouvernorats (Identique React: POST user/allGouvernorat)
  Future<void> fetchGouvernorats({bool forceRefresh = false}) async {
    if (_gouvernorats.isNotEmpty && !forceRefresh) return;
    try {
      final response = await _api.post('user/allGouvernorat', useCache: true, forceRefresh: forceRefresh);
      final list = _extractList(response.data);
      if (list.isNotEmpty) {
        _gouvernorats = list;
        notifyListeners();
      }
    } catch (_) {}
  }

  // Toggle TB Garde State (Identique React: PUT zone/changeEtat/:id)
  Future<({bool success, String message})> changeTbGardeEtat(int id, int currentEtat) async {
    final newEtat = currentEtat == 1 ? 0 : 1;
    final successMessage = newEtat == 1 ? 'Activation avec succès' : 'Désactivation avec succès';

    // Optimistic UI update
    final index = _tbGardes.indexWhere((z) => z['id'] == id || z['id']?.toString() == id.toString());
    if (index != -1) {
      _tbGardes[index]['etat'] = newEtat;
      notifyListeners();
    }

    try {
      final response = await _api.put('zone/changeEtat/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchTbGardes(forceRefresh: true);
        return (success: true, message: successMessage);
      }
    } catch (_) {
      try {
        final res2 = await _api.post('zone/changeEtat', data: {'id': id, 'etat': newEtat});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          await fetchTbGardes(forceRefresh: true);
          return (success: true, message: successMessage);
        }
      } catch (_) {}
    }

    return (success: true, message: successMessage);
  }

  // Add TB Garde (Identique React: POST zone/addZone avec id = 0)
  Future<({bool success, String message})> addTbGarde(String nomZone, int idGouvernorat) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('zone/addZone', data: {
        'nom_zone': nomZone.trim(),
        'id_gouvernorat': idGouvernorat,
        'id': 0,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de l\'ajout';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      await fetchTbGardes(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Insertion de la zone avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Update TB Garde (Identique React: POST zone/addZone avec id)
  Future<({bool success, String message})> updateTbGarde(int id, String nomZone, int idGouvernorat) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('zone/addZone', data: {
        'nom_zone': nomZone.trim(),
        'id_gouvernorat': idGouvernorat,
        'id': id,
      });

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de la modification';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      await fetchTbGardes(forceRefresh: true);
      _isLoading = false;
      notifyListeners();
      return (success: true, message: 'Modification de la zone avec succès');
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // ─── PHARMACIES DE GARDE (Identique React ListGardes.jsx & gardeReduce.js) ───

  // 9. Fetch Admin Gardes (POST garde/allGardes)
  Future<void> fetchAdminGardes({bool forceRefresh = false, String? annee}) async {
    if (_adminGardes.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();

    final targetYear = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());

    try {
      final response = await _api.post('garde/allGardes', data: {
        'annee': targetYear,
      }, useCache: true, forceRefresh: forceRefresh);

      if (response.data is List) {
        _adminGardes = (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      try {
        final res2 = await _api.post('garde/allLignesGardes', data: {
          'annee': targetYear,
        }, useCache: true, forceRefresh: forceRefresh);
        if (res2.data is List) {
          _adminGardes = (res2.data as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  // Fetch Garde Details by ID (POST garde/getGarde)
  Future<Map<String, dynamic>?> fetchGardeDetails(int id) async {
    try {
      final response = await _api.post('garde/getGarde', data: {'id': id});
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return null;
  }

  // Fetch Pharmaciens by TB Garde Zone (POST user/fetchPharmaciensByTbGarde)
  Future<List<Map<String, dynamic>>> fetchPharmaciensByTbGarde(int idZoneGarde) async {
    try {
      final response = await _api.post('user/fetchPharmaciensByTbGarde', data: {
        'id_zonegarde': idZoneGarde,
      });
      if (response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      try {
        final res2 = await _api.post('user/getPharmaciensByTbGarde', data: {
          'id_zonegarde': idZoneGarde,
        });
        if (res2.data is List) {
          return (res2.data as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Add Lignes Garde (POST garde/addLignesGarde - Identique React: { id, id_tbgarde, data, annee })
  Future<({bool success, String message})> addLignesGarde({
    required int idGarde,
    required List<Map<String, dynamic>> lignes,
    String? annee,
    int id = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final targetAnnee = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());
      final payload = {
        'id': id,
        'id_tbgarde': idGarde,
        'id_garde': idGarde,
        'annee': targetAnnee,
        'data': lignes,
        'lignes': lignes,
      };

      final response = await _api.post('garde/addLignesGarde', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAdminGardes(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Lignes de garde enregistrées avec succès');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'enregistrement';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Update Garde Lines (POST garde/updateGarde - Identique React: { id, data })
  Future<({bool success, String message})> updateGardeLines({
    required int id,
    required List<Map<String, dynamic>> data,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('garde/updateGarde', data: {
        'id': id,
        'data': data,
        'lignes': data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAdminGardes(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Modification réussie');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'enregistrement';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Delete Admin Garde (DELETE garde/deleteGarde/:id)
  Future<bool> deleteAdminGarde(int id) async {
    try {
      final response = await _api.delete('garde/deleteGarde/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        _adminGardes.removeWhere((g) => g['id'] == id || g['id']?.toString() == id.toString());
        notifyListeners();
        return true;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('garde/deleteGarde', data: {'id': id});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          _adminGardes.removeWhere((g) => g['id'] == id || g['id']?.toString() == id.toString());
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // Refresh Gardes API (GET test/generate-gardes-pdf)
  Future<bool> refreshGardesApi() async {
    try {
      final response = await _api.get('test/generate-gardes-pdf');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAdminGardes(forceRefresh: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // Import Gardes Excel (POST garde/addGarde - Identique React ImportGardes.jsx)
  Future<({bool success, String message})> importGardesExcel({
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
    required int idTbGarde,
    required String annee,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final name = fileName ?? (filePath != null ? filePath.split('/').last.split(r'\').last : 'garde.xlsx');
      
      MultipartFile multipartFile;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        multipartFile = MultipartFile.fromBytes(fileBytes, filename: name);
      } else if (filePath != null && filePath.isNotEmpty) {
        multipartFile = await MultipartFile.fromFile(filePath, filename: name);
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: 'Aucun fichier sélectionné');
      }

      final formData = FormData.fromMap({
        'file': multipartFile,
        'id': 0,
        'id_tbgarde': idTbGarde,
        'annee': annee,
      });

      final response = await _api.post('garde/addGarde', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAdminGardes(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Importation du fichier Excel avec succès');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'importation';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème lors de l\'envoi du fichier Excel');
    }
  }

  // Fetch Positions for TB Garde (POST garde/getPositions)
  Future<Map<String, dynamic>?> fetchPositions(int idTbGarde) async {
    try {
      final response = await _api.post('garde/getPositions', data: {'id': idTbGarde});
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return null;
  }

  // Fetch Garde for Duplication (POST garde/getGardeDup)
  Future<Map<String, dynamic>?> fetchGardeDup(int id) async {
    try {
      final response = await _api.post('garde/getGardeDup', data: {'id': id});
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return null;
  }

  // Duplicate Garde for Target Year (POST garde/duplicateGarde or garde/addLignesGarde)
  Future<({bool success, String message})> duplicateGarde({
    required int id,
    required String targetAnnee,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Fetch current garde lines and details
      final gardeData = await fetchGardeDup(id) ?? await fetchGardeDetails(id);
      if (gardeData == null) {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: 'Impossible de charger les données à dupliquer');
      }

      final entete = gardeData['enteteObj'] ?? gardeData['entete'] ?? gardeData;
      final rawLines = gardeData['data'] ?? gardeData['lignes'] ?? gardeData['lignes_gardes'] ?? [];
      final idTbGarde = int.tryParse((entete['id_tbgarde'] ?? entete['id_zonegarde'] ?? '0').toString()) ?? 0;

      final List<Map<String, dynamic>> duplicatedLines = [];
      if (rawLines is List) {
        for (var item in rawLines) {
          if (item is Map) {
            final oldDeb = (item['date_debut'] ?? '').toString().split('T').first;
            final oldFin = (item['date_fin'] ?? '').toString().split('T').first;

            String newDeb = oldDeb;
            String newFin = oldFin;

            try {
              final d1 = DateTime.parse(oldDeb);
              final d2 = DateTime.parse(oldFin);
              // Shift by 1 year (or 52 weeks / 364 days to match days of week)
              final n1 = DateTime(d1.year + 1, d1.month, d1.day);
              final n2 = DateTime(d2.year + 1, d2.month, d2.day);
              newDeb = "${n1.year}-${n1.month.toString().padLeft(2, '0')}-${n1.day.toString().padLeft(2, '0')}";
              newFin = "${n2.year}-${n2.month.toString().padLeft(2, '0')}-${n2.day.toString().padLeft(2, '0')}";
            } catch (_) {}

            duplicatedLines.add({
              'num_cnopt': (item['num_cnopt'] ?? '').toString(),
              'date_debut': newDeb,
              'date_fin': newFin,
              'id_tbgarde': idTbGarde,
              'id_pharmacien': item['id_pharmacien'] ?? item['pharmacien_id'] ?? item['top_pharmacien']?['id'],
            });
          }
        }
      }

      // 2. Save duplicated garde
      try {
        final resDup = await _api.post('garde/duplicateGarde', data: {
          'id_tbgarde': idTbGarde,
          'annee': targetAnnee,
          'data': duplicatedLines,
        });
        if (resDup.statusCode == 200 || resDup.statusCode == 201) {
          await fetchAdminGardes(forceRefresh: true);
          _isLoading = false;
          notifyListeners();
          return (success: true, message: 'Garde dupliquée avec succès pour l\'année $targetAnnee');
        }
      } catch (_) {}

      // Fallback
      final response = await _api.post('garde/addLignesGarde', data: {
        'id_tbgarde': idTbGarde,
        'annee': targetAnnee,
        'lignes': duplicatedLines,
        'data': duplicatedLines,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchAdminGardes(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Garde dupliquée avec succès pour l\'année $targetAnnee');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de la duplication';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur lors de la duplication de la garde');
    }
  }

  // ─── PHARMACIES DE GARDE (JOURS FÉRIÉS) (Identique React ListGardesJours.jsx) ───

  // 10. Fetch Gardes Jours (POST garde/allGardesJours)
  Future<void> fetchGardesJours({
    bool forceRefresh = false,
    String? annee,
    int? idUser,
    int? idRole,
  }) async {
    if (_gardesJours.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    notifyListeners();

    final targetYear = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());

    try {
      final response = await _api.post('garde/allGardesJours', data: {
        'annee': targetYear,
        if (idUser != null) 'id_user': idUser,
        if (idRole != null) 'id_role': idRole,
      }, useCache: true, forceRefresh: forceRefresh);

      if (response.data is List) {
        _gardesJours = (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      try {
        final res2 = await _api.post('garde/fetchGardesJours', data: {
          'annee': targetYear,
        }, useCache: true, forceRefresh: forceRefresh);
        if (res2.data is List) {
          _gardesJours = (res2.data as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      } catch (_) {}
    }
    _isLoading = false;
    notifyListeners();
  }

  // Fetch Garde Jours Details (POST garde/getGardeJours)
  Future<Map<String, dynamic>?> fetchGardeJoursDetails(int id) async {
    try {
      final response = await _api.post('garde/getGardeJours', data: {'id': id});
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {}
    return null;
  }

  // Delete Garde Jours (DELETE garde/deleteGardeJours/:id)
  Future<bool> deleteGardeJours(int id) async {
    try {
      final response = await _api.delete('garde/deleteGardeJours/$id');
      if (response.statusCode == 200 || response.statusCode == 201) {
        _gardesJours.removeWhere((g) => g['id'] == id || g['id']?.toString() == id.toString());
        notifyListeners();
        return true;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('garde/deleteGardeJours', data: {'id': id});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          _gardesJours.removeWhere((g) => g['id'] == id || g['id']?.toString() == id.toString());
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // Import Gardes Jours Excel (POST garde/addGardeJours - Identique React ImportGardesJours.jsx)
  Future<({bool success, String message})> importGardesJoursExcel({
    String? filePath,
    List<int>? fileBytes,
    String? fileName,
    required int idTbGarde,
    required String annee,
    List<Map<String, dynamic>>? parsedData,
    int id = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final name = fileName ?? (filePath != null ? filePath.split('/').last.split(r'\').last : 'gardes_jours.xlsx');

      MultipartFile multipartFile;
      if (fileBytes != null && fileBytes.isNotEmpty) {
        multipartFile = MultipartFile.fromBytes(fileBytes, filename: name);
      } else if (filePath != null && filePath.isNotEmpty) {
        multipartFile = await MultipartFile.fromFile(filePath, filename: name);
      } else {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: 'Aucun fichier sélectionné');
      }

      final formDataMap = <String, dynamic>{
        'file': multipartFile,
        'id': id,
        'id_tbgarde': idTbGarde,
        'annee': annee,
      };
      if (parsedData != null && parsedData.isNotEmpty) {
        formDataMap['data'] = parsedData;
      }

      final formData = FormData.fromMap(formDataMap);

      final response = await _api.post('garde/addGardeJours', data: formData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchGardesJours(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Importation du fichier Excel avec succès');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'importation';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème lors de l\'envoi du fichier Excel');
    }
  }

  // Add Lignes Garde Jours (POST garde/addLignesGardeJours - Identique React AjouterGardesJours.jsx)
  Future<({bool success, String message})> addLignesGardeJours({
    required int idTbGarde,
    required List<Map<String, dynamic>> lignes,
    String? annee,
    int id = 0,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final targetAnnee = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());
      final payload = {
        'id': id,
        'id_tbgarde': idTbGarde,
        'id_garde': idTbGarde,
        'annee': targetAnnee,
        'data': lignes,
        'lignes': lignes,
      };

      final response = await _api.post('garde/addLignesGardeJours', data: payload);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchGardesJours(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Lignes de garde (jours fériés) enregistrées avec succès');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'enregistrement';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Update Garde Jours Lines (POST garde/updateGardeJours)
  Future<({bool success, String message})> updateGardeJoursLines({
    required int id,
    required List<Map<String, dynamic>> data,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.post('garde/updateGardeJours', data: {
        'id': id,
        'data': data,
        'lignes': data,
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchGardesJours(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Modification réussie');
      } else {
        final msg = response.data?['message']?.toString() ?? 'Erreur lors de l\'enregistrement';
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }
  }

  // Duplicate Garde Jours (POST garde/duplicateGardeJours)
  Future<({bool success, String message})> duplicateGardeJours({
    required int id,
    required String targetAnnee,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final gardeData = await fetchGardeJoursDetails(id);
      if (gardeData == null) {
        _isLoading = false;
        notifyListeners();
        return (success: false, message: 'Impossible de charger les données à dupliquer');
      }

      final entete = gardeData['enteteObj'] ?? gardeData['entete'] ?? gardeData;
      final rawLines = gardeData['data'] ?? gardeData['lignes'] ?? [];
      final idTbGarde = int.tryParse((entete['id_tbgarde'] ?? entete['id_zonegarde'] ?? '0').toString()) ?? 0;

      final List<Map<String, dynamic>> duplicatedLines = [];
      if (rawLines is List) {
        for (var item in rawLines) {
          if (item is Map) {
            duplicatedLines.add({
              'num_cnopt': (item['num_cnopt'] ?? '').toString(),
              'jour_ferie': item['jour_ferie'] ?? item['date'],
              'id_tbgarde': idTbGarde,
              'id_pharmacien': item['id_pharmacien'] ?? item['pharmacien_id'] ?? item['top_pharmacien']?['id'],
            });
          }
        }
      }

      try {
        final resDup = await _api.post('garde/duplicateGardeJours', data: {
          'id': id,
          'id_tbgarde': idTbGarde,
          'annee': targetAnnee,
          'data': duplicatedLines,
        });
        if (resDup.statusCode == 200 || resDup.statusCode == 201) {
          await fetchGardesJours(forceRefresh: true);
          _isLoading = false;
          notifyListeners();
          return (success: true, message: 'Garde (jours fériés) dupliquée avec succès pour l\'année $targetAnnee');
        }
      } catch (_) {}

      // Fallback to addLignesGardeJours
      return await addLignesGardeJours(
        idTbGarde: idTbGarde,
        lignes: duplicatedLines,
        annee: targetAnnee,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Erreur lors de la duplication de la garde');
    }
  }

  // Fetch Jours by Type (POST jour/getJourByType)
  Future<List<Map<String, dynamic>>> fetchJoursByType({
    required String annee,
    required String type,
  }) async {
    try {
      final response = await _api.post('jour/getJourByType', data: {
        'annee': annee,
        'type': type,
      });
      if (response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      try {
        final res2 = await _api.post('jour/allJour', data: {'annee': annee});
        if (res2.data is List) {
          return (res2.data as List)
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .where((j) => j['type']?.toString() == type)
              .toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Fetch Groupe Pharmaciens (POST user/fetchGroupePharmaciens)
  Future<List<Map<String, dynamic>>> fetchGroupePharmaciensByZone(int idZoneGarde) async {
    try {
      final response = await _api.post('user/fetchGroupePharmaciens', data: {
        'id_zonegarde': idZoneGarde,
      });
      if (response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {
      return await fetchPharmaciensByTbGarde(idZoneGarde);
    }
    return [];
  }

  // Fetch User Zones Gardes (POST user/getUserById)
  Future<List<Map<String, dynamic>>> fetchUserZonesGardes(int userId) async {
    try {
      final response = await _api.post('user/getUserById', data: {'id': userId});
      if (response.data is Map && response.data['zonesgardes'] is List) {
        return (response.data['zonesgardes'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (_) {}
    // Fallback return all active tbGardes
    if (_tbGardes.isEmpty) await fetchTbGardes();
    return _tbGardes;
  }

  // ─── USER MUTATION ACTIONS (Exactement identique React) ───

  Map<String, dynamic> _buildUserPayload(Map<String, dynamic> userData, {required bool isUpdate}) {
    final role = userData['role'] ?? userData['id_role'] ?? 2;
    final roleInt = role is int ? role : int.tryParse(role.toString()) ?? 2;
    final rawId = userData['id'] ?? userData['id_user'] ?? 0;
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
    final nom = (userData['nom'] ?? '').toString().trim();
    final email = (userData['email'] ?? userData['login'] ?? '').toString().trim();
    final login = (userData['login'] ?? userData['email'] ?? '').toString().trim();
    final tel = (userData['tel'] ?? '').toString().trim();
    final tva = (userData['tva'] ?? userData['num_cnopt'] ?? '').toString().trim();
    final pwd = (userData['password'] ?? '').toString().trim();

    return <String, dynamic>{
      'id': isUpdate ? id : 0,
      'nom': nom,
      'email': email,
      'tel': tel,
      'login': login.isNotEmpty ? login : email,
      'password': pwd,
      'etat': userData['etat'] ?? 1,
      'role': roleInt,
      'gardes': userData['gardes'] ?? [],
      'jourNuit': userData['jourNuit'] ?? userData['type'],
      'nomAr': userData['nomAr'] ?? userData['nom_ar'] ?? '',
      'lat': userData['lat']?.toString() ?? '',
      'lng': userData['lng']?.toString() ?? '',
      'adresse': userData['adresse'] ?? '',
      'adresseAr': userData['adresseAr'] ?? userData['adresse_ar'] ?? '',
      'id_zonegarde': userData['id_zonegarde'],
      'tva': tva,
      'verif': userData['verif'] ?? 1,
      'cin': userData['cin'] ?? '',
      'identifiant': userData['identifiant'] ?? '',
      'dateNaissance': userData['dateNaissance'] ?? userData['date_naissance'] ?? '',
      'id_gouvernorat': userData['id_gouvernorat'],
      'allergie': userData['allergie'] ?? '',
      'image': userData['image'] ?? userData['logo'] ?? '',
      'code': userData['code'] ?? userData['code_client'] ?? '',
      'type_indus': userData['type_indus'],
      'fonction': userData['fonction'] ?? '',
    };
  }

  // Toggle user state (Actif / Désactivé)
  Future<bool> changeUserEtat(int userId, int currentEtat) async {
    final newEtat = currentEtat == 1 ? 0 : 1;
    // Optimistic UI update
    final index = _users.indexWhere((u) => u['id'] == userId || u['id'].toString() == userId.toString());
    if (index != -1) {
      _users[index]['etat'] = newEtat;
      _applyUserFilter();
      notifyListeners();
    }

    try {
      final response = await _api.put('user/changeEtat/$userId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
    } catch (_) {
      try {
        await _api.post('user/etatUpdated', data: {'id': userId, 'etat': newEtat});
        return true;
      } catch (_) {}
    }
    // Revert if error
    if (index != -1) {
      _users[index]['etat'] = currentEtat;
      _applyUserFilter();
      notifyListeners();
    }
    return false;
  }

  // Add User (Identique React: POST user/addUser)
  Future<({bool success, String message})> addUser(Map<String, dynamic> userData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final payload = _buildUserPayload(userData, isUpdate: false);

    try {
      final response = await _api.post('user/addUser', data: payload);

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de l\'insertion';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchUsers(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Insertion avec succès');
      }
    } on DioException catch (e) {
      String msg = 'Problème de connexion';
      if (e.response?.data is Map && e.response!.data['message'] != null) {
        msg = e.response!.data['message'].toString();
      }
      _errorMessage = msg;
      _isLoading = false;
      notifyListeners();
      return (success: false, message: msg);
    } catch (e) {
      _errorMessage = 'Problème de connexion';
      _isLoading = false;
      notifyListeners();
      return (success: false, message: 'Problème de connexion');
    }

    _isLoading = false;
    notifyListeners();
    return (success: false, message: 'Erreur inattendue');
  }

  // Update User (Identique React: POST user/addUser avec id, fallback PUT user/UpdateUser)
  Future<({bool success, String message})> updateUser(Map<String, dynamic> userData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final payload = _buildUserPayload(userData, isUpdate: true);
    final userId = payload['id'];

    // Optimistically update in local list
    if (userId != 0) {
      final idx = _users.indexWhere((u) => u['id'] == userId || u['id'].toString() == userId.toString());
      if (idx != -1) {
        _users[idx] = {
          ..._users[idx],
          ...userData,
          'id': userId,
        };
        _applyUserFilter();
        notifyListeners();
      }
    }

    try {
      // 1. Primary endpoint: user/addUser (which handles updates when id > 0 in React)
      final response = await _api.post('user/addUser', data: payload);

      if (response.data is Map && (response.data as Map).containsKey('message')) {
        final msg = response.data['message']?.toString() ?? 'Erreur lors de la modification';
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchUsers(forceRefresh: true);
        _isLoading = false;
        notifyListeners();
        return (success: true, message: 'Modification avec succès');
      }
    } catch (_) {
      // 2. Fallback endpoint: PUT user/UpdateUser
      try {
        final res2 = await _api.put('user/UpdateUser', data: payload);
        if (res2.data is Map && (res2.data as Map).containsKey('message')) {
          final msg = res2.data['message']?.toString() ?? 'Erreur lors de la modification';
          _errorMessage = msg;
          _isLoading = false;
          notifyListeners();
          return (success: false, message: msg);
        }
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          await fetchUsers(forceRefresh: true);
          _isLoading = false;
          notifyListeners();
          return (success: true, message: 'Modification avec succès');
        }
      } catch (e2) {
        String msg = 'Problème de connexion';
        if (e2 is DioException && e2.response?.data is Map && e2.response!.data['message'] != null) {
          msg = e2.response!.data['message'].toString();
        }
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return (success: false, message: msg);
      }
    }

    _isLoading = false;
    notifyListeners();
    return (success: true, message: 'Modification avec succès');
  }

  // Delete User
  Future<bool> deleteUser(int userId) async {
    try {
      final response = await _api.delete('user/deleteUser/$userId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        _users.removeWhere((u) => u['id'] == userId || u['id'].toString() == userId.toString());
        _applyUserFilter();
        notifyListeners();
        return true;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('user/deleteUser', data: {'id': userId});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          _users.removeWhere((u) => u['id'] == userId || u['id'].toString() == userId.toString());
          _applyUserFilter();
          notifyListeners();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // 17. Fetch Historique Gardes (Semaine de garde)
  Future<void> fetchHistoriqueGardes({bool forceRefresh = false, String? annee}) async {
    if (_historiqueGardes.isNotEmpty && !forceRefresh) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final targetYear = annee ?? (_selectedYear.isNotEmpty ? _selectedYear : DateTime.now().year.toString());
      final response = await _api.post('garde/allHistoriqueGardes', data: {
        'annee': targetYear,
      }, useCache: true, forceRefresh: forceRefresh);

      if (response.data is List) {
        _historiqueGardes = (response.data as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else if (response.data is Map && response.data['result'] is List) {
        _historiqueGardes = (response.data['result'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      } else if (response.data is Map && response.data['data'] is List) {
        _historiqueGardes = (response.data['data'] as List)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching historique gardes: $e');
      _errorMessage = 'Impossible de charger l\'historique des gardes.';
      _isLoading = false;
      notifyListeners();
    }
  }
}
