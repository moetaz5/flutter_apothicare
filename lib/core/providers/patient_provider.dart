import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../services/notification_service.dart';
import '../storage/storage_service.dart';

class PatientProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<dynamic> _medicaments = [];
  bool _isLoadingMedicaments = false;

  int _totalPoints = 0;
  String _identifiant = '';
  String _nom = '';
  String _email = '';
  bool _isLoadingPoints = false;

  List<dynamic> get medicaments => _medicaments;
  bool get isLoadingMedicaments => _isLoadingMedicaments;

  int get totalPoints => _totalPoints;
  String get identifiant => _identifiant;
  String get nom => _nom;
  String get email => _email;
  bool get isLoadingPoints => _isLoadingPoints;

  int get totalTraitements => _medicaments.length;

  int get traitementsActifs => _medicaments.where((item) {
        final reste = calculerReste(item['date_debut']?.toString(), item['duree']);
        return (reste is int && reste > 0);
      }).length;

  int get traitementsTermines => totalTraitements - traitementsActifs;

  List<dynamic> get activeMedicaments => _medicaments.where((item) {
        final reste = calculerReste(item['date_debut']?.toString(), item['duree']);
        return (reste is int && reste > 0);
      }).toList();

  static dynamic calculerReste(String? dateDebut, dynamic duree) {
    if (dateDebut == null || dateDebut.isEmpty || duree == null) return '-';
    final dureeInt = duree is int ? duree : int.tryParse(duree.toString()) ?? 0;
    final debut = DateTime.tryParse(dateDebut);
    if (debut == null) return '-';
    final today = DateTime.now();
    final differenceInDays = today.difference(debut).inDays;
    final reste = dureeInt - differenceInDays;
    return reste >= 0 ? reste : 0;
  }

  Future<void> fetchMedicamentsByPatient(dynamic patientId, {bool forceRefresh = false}) async {
    final targetId = patientId ?? StorageService.getUser()?.id;
    if (targetId == null) {
      _isLoadingMedicaments = false;
      notifyListeners();
      return;
    }

    if (_medicaments.isNotEmpty && !forceRefresh) {
      _isLoadingMedicaments = false;
      notifyListeners();
      return;
    }

    _isLoadingMedicaments = true;
    notifyListeners();

    try {
      final response = await _api.post(
        'patient/getMedicamentsByPatient',
        data: {
          'id': targetId,
          'id_patient': targetId,
        },
        useCache: true,
        forceRefresh: forceRefresh,
        options: Options(
          headers: {
            'id': targetId.toString(),
          },
        ),
      );

      if (response.data is List) {
        _medicaments = response.data;
      } else if (response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        if (map['data'] is List) {
          _medicaments = map['data'];
        } else if (map['medicaments'] is List) {
          _medicaments = map['medicaments'];
        } else if (map['entities'] is List) {
          _medicaments = map['entities'];
        } else {
          _medicaments = [];
        }
      } else {
        _medicaments = [];
      }
    } catch (e) {
      _medicaments = [];
    } finally {
      _isLoadingMedicaments = false;
      notifyListeners();
    }
  }

  List<dynamic> _allMedicamentsList = [];
  bool _isLoadingAllMedicaments = false;

  List<dynamic> get allMedicamentsList => _allMedicamentsList;
  bool get isLoadingAllMedicaments => _isLoadingAllMedicaments;

  Future<List<dynamic>> fetchAllMedicaments({bool forceRefresh = false}) async {
    if (_allMedicamentsList.isNotEmpty && !forceRefresh) {
      return _allMedicamentsList;
    }
    _isLoadingAllMedicaments = true;
    notifyListeners();

    try {
      final response = await _api.post('patient/allMedicaments', data: {});
      if (response.data is List) {
        _allMedicamentsList = response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        _allMedicamentsList = response.data['data'];
      }
    } catch (_) {}
    _isLoadingAllMedicaments = false;
    notifyListeners();
    return _allMedicamentsList;
  }

  Future<Map<String, dynamic>?> getProduit({String? imageSrc, String? codeBarre, String? nom}) async {
    try {
      final response = await _api.post(
        'patient/getProduit',
        data: {
          if (imageSrc != null) 'imageSrc': imageSrc,
          if (codeBarre != null) 'code_barre': codeBarre,
          if (nom != null) 'nom': nom,
        },
      );
      if (response.data is Map) {
        final map = Map<String, dynamic>.from(response.data);
        if (map['product'] is Map) {
          return Map<String, dynamic>.from(map['product']);
        }
        if (map['result'] is Map) {
          return Map<String, dynamic>.from(map['result']);
        }
        if (map['data'] is Map) {
          return Map<String, dynamic>.from(map['data']);
        }
        return map;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> addDispensation({
    required dynamic patientId,
    required List<Map<String, dynamic>> medicaments,
  }) async {
    try {
      final targetId = patientId ?? StorageService.getUser()?.id;
      final response = await _api.post(
        'patient/addDispensation',
        data: {
          'patientId': targetId,
          'id_patient': targetId,
          'medicaments': medicaments,
        },
      );

      bool isSuccess = false;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.data == null) {
          isSuccess = true;
        } else if (response.data is Map) {
          final map = response.data as Map;
          if (map['error'] == true || map['error'] == 'true') {
            isSuccess = false;
          } else {
            isSuccess = true;
          }
        } else {
          // List, String, int, bool etc. returned from backend
          isSuccess = true;
        }
      }

      if (isSuccess) {
        // Refresh patient's medicaments immediately
        await fetchMedicamentsByPatient(targetId, forceRefresh: true);
        
        final medName = medicaments.isNotEmpty
            ? (medicaments.first['designation']?.toString() ??
                medicaments.first['nom']?.toString() ??
                'Nouveau traitement')
            : 'Nouveau traitement';
        NotificationService.showDispensationNotification(
          patientName: 'Observance Patient',
          medicament: medName,
          payload: 'dispensation',
        );

        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error addDispensation: $e');
      return false;
    }
  }

  Future<void> fetchPatientPoints() async {
    _isLoadingPoints = true;
    notifyListeners();

    try {
      final response = await _api.post('user/getPatientPoint');
      if (response.data is Map) {
        final data = response.data;
        _totalPoints = int.tryParse(data['total_points']?.toString() ?? '0') ?? 0;
        final users = data['users'];
        if (users is Map) {
          _identifiant = users['identifiant']?.toString() ?? '';
          _nom = users['nom']?.toString() ?? '';
          _email = users['email']?.toString() ?? '';
        }
      }
    } catch (e) {
      // keep defaults
    } finally {
      _isLoadingPoints = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> getFichePatient(String identifier) async {
    final cleanNum = identifier.trim();
    if (cleanNum.isEmpty) return null;

    try {
      final response = await _api.post(
        'user/getFichePatient',
        data: {'num': cleanNum},
        options: Options(
          headers: {
            'num': cleanNum,
          },
        ),
      );

      if (response.data is Map) {
        final map = Map<String, dynamic>.from(response.data);
        if (map['error'] == true || map['id'] == null) {
          return null;
        }
        return map;
      }
    } catch (e) {
      debugPrint('Error getFichePatient: $e');
    }
    return null;
  }
}
