import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  int _unreadNotifications = 0;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get unreadNotifications => _unreadNotifications;
  bool get isAuthenticated => _currentUser != null && StorageService.getToken() != null;

  AuthProvider() {
    _loadStoredUser();
  }

  void _loadStoredUser() {
    _currentUser = StorageService.getUser();
    notifyListeners();
  }

  bool _isFetchingNotifications = false;
  bool _isFetchingProfile = false;

  // Login
  Future<bool> login({required String login, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        'user/login',
        data: {
          'login': login.trim(),
          'password': password.trim(),
        },
        timeout: const Duration(seconds: 8),
      );

      Map<String, dynamic>? dataMap;
      if (response.data is Map<String, dynamic>) {
        dataMap = response.data as Map<String, dynamic>;
      } else if (response.data is Map) {
        dataMap = Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is String) {
        try {
          final decoded = jsonDecode(response.data as String);
          if (decoded is Map) {
            dataMap = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      final statusCode = response.statusCode ?? 200;
      final hasToken = dataMap != null && dataMap['token'] != null;

      if ((statusCode == 200 || statusCode == 201) && hasToken) {
        final token = dataMap['token'].toString();
        final rawData = dataMap['data'] is Map ? Map<String, dynamic>.from(dataMap['data'] as Map) : <String, dynamic>{};
        
        final user = UserModel.fromJson({
          ...rawData,
          'nb_point': dataMap['nb_point'],
        });

        // Verify if user has an authorized role (Admin, Pharmacien, Patient, etc.)
        final int roleId = user.idRole ?? 0;
        final bool isAuthorizedRole = roleId == 1 || roleId == 2 || roleId == 3 || roleId == 4 || roleId == 7 || roleId == 8;
        if (!isAuthorizedRole) {
          await StorageService.clearAll();
          _currentUser = null;
          _errorMessage = "Vous n'avez pas l'accès pour utiliser cette application.";
          _isLoading = false;
          notifyListeners();
          return false;
        }

        await StorageService.saveToken(token);
        await StorageService.saveUser(user);

        _currentUser = user;
        _isLoading = false;
        notifyListeners();

        // Background update for fresh profile details & unread badge (non-blocking)
        Future.microtask(() {
          fetchCurrentUserProfile();
          fetchUnreadNotifications();
        });

        return true;
      } else {
        final msg = dataMap?['message']?.toString() ??
            (statusCode == 401 ? 'Vérifier votre Login et Mot de passe !' : 'Login ou mot de passe incorrect.');
        _errorMessage = msg;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Erreur de connexion au serveur. Vérifiez vos identifiants ou votre connexion.';
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      if (_isLoading) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  // Register
  Future<bool> register(Map<String, dynamic> registrationData) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('user/addInscription', data: registrationData);
      _isLoading = false;
      notifyListeners();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      _errorMessage = 'Erreur lors de l\'inscription.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Reset Password (send reset email)
  Future<bool> sendResetPasswordEmail(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post('user/sendMail', data: {
        'email': email,
        'url': 'https://www.apothicare.tn/',
      });
      _isLoading = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _errorMessage = 'Impossible d\'envoyer le lien de réinitialisation.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fetch Notification Count
  Future<void> fetchUnreadNotifications() async {
    if (_currentUser?.id == null || _isFetchingNotifications) return;
    _isFetchingNotifications = true;
    try {
      final response = await _api.post('settings/getNotifActualites', data: {
        'id_user': _currentUser!.id,
      });
      if (response.data != null && response.data['nbRestant'] != null) {
        _unreadNotifications = int.tryParse(response.data['nbRestant'].toString()) ?? 0;
        notifyListeners();
      }
    } catch (e) {
      // Silently catch error
    } finally {
      _isFetchingNotifications = false;
    }
  }

  // Fetch Current User Profile
  Future<UserModel?> fetchCurrentUserProfile() async {
    if (_currentUser?.id == null || _isFetchingProfile) return _currentUser;
    _isFetchingProfile = true;
    try {
      final response = await _api.post(
        'user/getUser',
        data: {'id': _currentUser!.id},
        options: Options(headers: {'id': _currentUser!.id.toString()}),
      );
      if (response.data is Map) {
        final raw = response.data as Map<String, dynamic>;
        var updatedUser = UserModel.fromJson({
          ..._currentUser!.toJson(),
          ...raw,
        });

        // Also check user/getInfo for photo_profil if not present or to be sure
        try {
          final infoRes = await _api.post(
            'user/getInfo',
            data: {'id_user': _currentUser!.id},
            options: Options(headers: {'id': _currentUser!.id.toString()}),
          );
          if (infoRes.data is Map) {
            final resMap = infoRes.data as Map<String, dynamic>;
            final innerResult = resMap['result'] ?? resMap;
            if (innerResult is Map) {
              final pPhoto = innerResult['photo_profil'] ?? innerResult['photo'];
              if (pPhoto != null && pPhoto.toString().trim().isNotEmpty) {
                updatedUser = updatedUser.copyWith(photo: pPhoto.toString().trim());
              }
            }
          }
        } catch (_) {}

        _currentUser = updatedUser;
        await StorageService.saveUser(updatedUser);
        notifyListeners();
        return updatedUser;
      }
    } catch (_) {} finally {
      _isFetchingProfile = false;
    }
    return _currentUser;
  }

  // Update Profile
  Future<bool> updateProfile({
    required String nom,
    required String login,
    String? tel,
    String? password,
    String? photoProfil,
    String? fonction,
    String? cvJeune,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _currentUser?.id;
      final payload = <String, dynamic>{
        if (userId != null) 'id': userId,
        if (userId != null) 'id_user': userId,
        'nom': nom.trim(),
        'login': login.trim(),
        'tel': (tel != null && !tel.contains('@')) ? tel.trim() : (tel?.trim() ?? ''),
        'password': (password != null && password.trim().isNotEmpty) ? password.trim() : '',
        if (photoProfil != null) 'photo_profil': photoProfil,
        'fonction': fonction ?? '',
        if (cvJeune != null) 'cv_jeune': cvJeune,
      };

      Response? response;
      try {
        response = await _api.post(
          'user/updateProfile',
          data: payload,
          options: Options(
            headers: {
              if (userId != null) 'id': userId.toString(),
            },
          ),
        );
      } catch (postErr) {
        // Fallback to PUT user/UpdateUser if POST user/updateProfile fails
        try {
          response = await _api.put(
            'user/UpdateUser',
            data: payload,
            options: Options(
              headers: {
                if (userId != null) 'id': userId.toString(),
              },
            ),
          );
        } catch (_) {
          rethrow;
        }
      }

      final data = response.data;
      bool isSuccess = false;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data == true || data == 1 || data == '1' || data == 'true') {
          isSuccess = true;
        } else if (data is Map) {
          if (data['success'] == false) {
            _errorMessage = data['message']?.toString() ?? 'Erreur lors de la mise à jour';
            _isLoading = false;
            notifyListeners();
            return false;
          } else {
            isSuccess = true;
          }
        } else {
          isSuccess = true;
        }
      }

      if (isSuccess) {
        if (_currentUser != null) {
          final updated = UserModel(
            id: _currentUser!.id,
            nom: nom.trim(),
            idRole: _currentUser!.idRole,
            login: login.trim(),
            tel: tel?.trim() ?? _currentUser!.tel,
            idGarde: _currentUser!.idGarde,
            idGouvernorat: _currentUser!.idGouvernorat,
            identifiant: _currentUser!.identifiant,
            nbPoint: _currentUser!.nbPoint,
            numCnopt: _currentUser!.numCnopt,
            codeClient: _currentUser!.codeClient,
            typeIndus: _currentUser!.typeIndus,
            type: _currentUser!.type,
            heureRamadan: _currentUser!.heureRamadan,
            adresse: _currentUser!.adresse,
            lat: _currentUser!.lat,
            lng: _currentUser!.lng,
            photo: photoProfil ?? _currentUser!.photo,
          );
          _currentUser = updated;
          await StorageService.saveUser(updated);
        }
        await fetchCurrentUserProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Erreur lors de la mise à jour du profil';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } on DioException catch (e) {
      if (e.response?.data is Map && e.response?.data['message'] != null) {
        _errorMessage = e.response!.data['message'].toString();
      } else if (e.response?.data is String && (e.response!.data as String).isNotEmpty) {
        _errorMessage = e.response!.data.toString();
      } else {
        _errorMessage = 'Erreur serveur lors de la mise à jour du profil';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erreur serveur lors de la mise à jour du profil';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Delete User Account (DELETE user/deleteUser/:id)
  Future<bool> deleteAccount() async {
    final userId = _currentUser?.id;
    if (userId == null) return false;
    try {
      final response = await _api.delete('user/deleteUser/$userId');
      if (response.statusCode == 200 || response.statusCode == 201) {
        await logout();
        return true;
      }
    } catch (_) {
      try {
        final res2 = await _api.post('user/deleteUser', data: {'id': userId, 'etat': 0});
        if (res2.statusCode == 200 || res2.statusCode == 201) {
          await logout();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // Fetch User Images (Facade, Para, Injection)
  Future<Map<String, List<String>>> fetchUserImages(int? userId) async {
    final targetId = userId ?? _currentUser?.id;
    final result = <String, List<String>>{
      'facade': [],
      'para': [],
      'injection': [],
    };
    if (targetId == null) return result;
    try {
      final response = await _api.post(
        'image/allImages',
        data: {'id': targetId},
        options: Options(headers: {'id': targetId.toString()}),
      );
      if (response.data is List) {
        for (final item in response.data as List) {
          if (item is Map) {
            final type = item['type']?.toString() ?? '';
            final files = item['files'];
            if (files is List) {
              for (final f in files) {
                final fn = f['filename']?.toString();
                if (fn != null && fn.isNotEmpty) {
                  if (type == 'Image de la façade' || type == 'Façade pharmacie') {
                    result['facade']!.add(fn);
                  } else if (type == 'produit para' || type == 'Coin para') {
                    result['para']!.add(fn);
                  } else if (type == 'injection' || type == 'Salle d’injection') {
                    result['injection']!.add(fn);
                  }
                }
              }
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  // Update Full Pharmacien Profile
  Future<bool> updatePharmacienDetails({
    required String nom,
    String? nomAr,
    String? numCnopt,
    String? login,
    String? tel,
    String? tel2,
    String? adresse,
    String? adresseAr,
    String? delegation,
    int? idGouvernorat,
    int? idGarde,
    double? lat,
    double? lng,
    String? password,
    List<int>? serviceIds,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _currentUser?.id;
      final payload = <String, dynamic>{
        if (userId != null) 'id': userId,
        'nom': nom.trim(),
        'nom_ar': (nomAr != null && nomAr.trim().isNotEmpty) ? nomAr.trim() : '',
        'tva': (numCnopt != null && numCnopt.trim().isNotEmpty) ? numCnopt.trim() : '',
        'num_cnopt': (numCnopt != null && numCnopt.trim().isNotEmpty) ? numCnopt.trim() : '',
        'login': (login != null && login.trim().isNotEmpty) ? login.trim() : (_currentUser?.login ?? ''),
        'email': (login != null && login.trim().isNotEmpty) ? login.trim() : (_currentUser?.email ?? ''),
        'tel': (tel != null && tel.trim().isNotEmpty) ? tel.trim() : '',
        'tel2': (tel2 != null && tel2.trim().isNotEmpty) ? tel2.trim() : '',
        'adresse': (adresse != null && adresse.trim().isNotEmpty) ? adresse.trim() : '',
        'adresse_ar': (adresseAr != null && adresseAr.trim().isNotEmpty) ? adresseAr.trim() : '',
        'delegation': (delegation != null && delegation.trim().isNotEmpty) ? delegation.trim() : '',
        if (idGouvernorat != null) 'id_gouvernorat': idGouvernorat,
        if (idGarde != null) 'id_garde': idGarde,
        if (idGarde != null) 'id_zonegarde': idGarde,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (password != null && password.trim().isNotEmpty) 'password': password.trim(),
        if (serviceIds != null) 'services': serviceIds,
      };

      try {
        await _api.put(
          'user/UpdateUser',
          data: payload,
          options: Options(headers: {if (userId != null) 'id': userId.toString()}),
        );
      } catch (_) {
        try {
          await _api.post(
            'user/updateProfile',
            data: payload,
            options: Options(headers: {if (userId != null) 'id': userId.toString()}),
          );
        } catch (_) {}
      }

      // Update local storage and current user immediately
      if (_currentUser != null) {
        final updated = UserModel(
          id: _currentUser!.id,
          nom: nom.trim(),
          nomAr: nomAr?.trim() ?? _currentUser!.nomAr,
          idRole: _currentUser!.idRole,
          login: (login != null && login.trim().isNotEmpty) ? login.trim() : _currentUser!.login,
          tel: tel?.trim() ?? _currentUser!.tel,
          tel2: tel2?.trim() ?? _currentUser!.tel2,
          idGarde: idGarde ?? _currentUser!.idGarde,
          idGouvernorat: idGouvernorat ?? _currentUser!.idGouvernorat,
          identifiant: _currentUser!.identifiant,
          nbPoint: _currentUser!.nbPoint,
          numCnopt: numCnopt?.trim() ?? _currentUser!.numCnopt,
          codeClient: _currentUser!.codeClient,
          typeIndus: _currentUser!.typeIndus,
          type: _currentUser!.type,
          heureRamadan: _currentUser!.heureRamadan,
          adresse: adresse?.trim() ?? _currentUser!.adresse,
          adresseAr: adresseAr?.trim() ?? _currentUser!.adresseAr,
          delegation: delegation?.trim() ?? _currentUser!.delegation,
          gouvernoratNom: _currentUser!.gouvernoratNom,
          zoneGardeNom: _currentUser!.zoneGardeNom,
          lat: lat ?? _currentUser!.lat,
          lng: lng ?? _currentUser!.lng,
          photo: _currentUser!.photo,
          services: _currentUser!.services,
        );
        _currentUser = updated;
        await StorageService.saveUser(updated);
      }

      _api.clearCache('user');
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour des informations.';
      _isLoading = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch Gouvernorats
  Future<List<Map<String, dynamic>>> fetchGouvernorats() async {
    try {
      final response = await _api.post('user/allGouvernorat');
      if (response.data is List) {
        return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Fetch Delegations
  Future<List<Map<String, dynamic>>> fetchDelegations() async {
    try {
      final response = await _api.post('user/allDelegations');
      if (response.data is List) {
        return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  // Fetch Active Zones de Garde
  Future<List<Map<String, dynamic>>> fetchActiveZones() async {
    try {
      final response = await _api.post('zone/fetchActiveZone');
      if (response.data is List) {
        return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {
      try {
        final response = await _api.post('zone/allZone');
        if (response.data is List) {
          return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Fetch Active Services
  Future<List<Map<String, dynamic>>> fetchActiveServices() async {
    try {
      final response = await _api.post('service/allActiveService');
      if (response.data is List) {
        return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {
      try {
        final response = await _api.post('service/allServices');
        if (response.data is List) {
          return (response.data as List).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  // Logout
  Future<void> logout() async {
    try {
      await _api.post('user/logout');
    } catch (e) {
      // Continue clearing local state anyway
    }
    await StorageService.clearAll();
    _currentUser = null;
    _unreadNotifications = 0;
    notifyListeners();
  }
}
