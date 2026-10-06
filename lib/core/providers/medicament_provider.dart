import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

class DemandeMedicamentItem {
  final int id;
  final int? idPharmacien;
  final int? idMedicament;
  final int? idGouvernorat;
  final int? idTbgarde;
  final int? type; // 1: Rupture, 2: Échange
  final String? dateExpiration;
  final DateTime? createdAt;
  final String? produit;
  final String? image;
  final String? pharmacienNom;
  final Map<String, dynamic>? rawUser;
  final Map<String, dynamic>? rawMedicament;
  final List<GrossisteItem> grossistes;

  DemandeMedicamentItem({
    required this.id,
    this.idPharmacien,
    this.idMedicament,
    this.idGouvernorat,
    this.idTbgarde,
    this.type,
    this.dateExpiration,
    this.createdAt,
    this.produit,
    this.image,
    this.pharmacienNom,
    this.rawUser,
    this.rawMedicament,
    this.grossistes = const [],
  });

  factory DemandeMedicamentItem.fromJson(Map<String, dynamic> json) {
    final med = json['medicaments'] is Map ? json['medicaments'] : null;
    final user = json['users'] is Map ? json['users'] : null;

    List<GrossisteItem> grossList = [];
    if (json['demande_grossistes'] is List) {
      grossList = (json['demande_grossistes'] as List)
          .map((g) => GrossisteItem(
                id: g['id_grossiste'] is int
                    ? g['id_grossiste']
                    : int.tryParse(g['id_grossiste']?.toString() ?? '0') ?? 0,
                nom: g['grossiste']?.toString() ?? g['nom']?.toString() ?? '',
              ))
          .toList();
    }

    DateTime? created;
    if (json['createdAt'] != null) {
      created = DateTime.tryParse(json['createdAt'].toString());
    }

    return DemandeMedicamentItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      idPharmacien: json['id_pharmacien'] is int
          ? json['id_pharmacien']
          : int.tryParse(json['id_pharmacien']?.toString() ?? ''),
      idMedicament: json['id_medicament'] is int
          ? json['id_medicament']
          : int.tryParse(json['id_medicament']?.toString() ?? ''),
      idGouvernorat: json['id_gouvernorat'] is int
          ? json['id_gouvernorat']
          : int.tryParse(json['id_gouvernorat']?.toString() ?? ''),
      idTbgarde: json['id_tbgarde'] is int
          ? json['id_tbgarde']
          : int.tryParse(json['id_tbgarde']?.toString() ?? ''),
      type: json['type'] is int ? json['type'] : int.tryParse(json['type']?.toString() ?? '1') ?? 1,
      dateExpiration: json['date_expiration']?.toString(),
      createdAt: created,
      produit: med?['produit']?.toString() ?? med?['nom']?.toString() ?? 'Médicament',
      image: med?['image']?.toString(),
      pharmacienNom: user?['nom']?.toString() ?? user?['name']?.toString() ?? 'Inconnu',
      rawUser: user != null ? Map<String, dynamic>.from(user) : null,
      rawMedicament: med != null ? Map<String, dynamic>.from(med) : null,
      grossistes: grossList,
    );
  }
}

class GrossisteItem {
  final int id;
  final String nom;

  GrossisteItem({required this.id, required this.nom});

  factory GrossisteItem.fromJson(Map<String, dynamic> json) {
    return GrossisteItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nom: json['nom']?.toString() ?? json['grossiste']?.toString() ?? '',
    );
  }
}

class OptionItem {
  final dynamic value;
  final String label;

  OptionItem({required this.value, required this.label});
}

class MedicamentProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<DemandeMedicamentItem> _demandes = [];
  List<DemandeMedicamentItem> get demandes => _demandes;

  List<OptionItem> _medicaments = [];
  List<OptionItem> get medicaments => _medicaments;

  List<OptionItem> _gouvernorats = [];
  List<OptionItem> get gouvernorats => _gouvernorats;

  List<OptionItem> _zones = [];
  List<OptionItem> get zones => _zones;

  List<GrossisteItem> _grossistes = [];
  List<GrossisteItem> get grossistes => _grossistes;

  bool _isLoadingDemandes = false;
  bool get isLoadingDemandes => _isLoadingDemandes;

  bool _isLoadingMedicaments = false;
  bool get isLoadingMedicaments => _isLoadingMedicaments;

  bool _isSubmitting = false;
  bool get isSubmitting => _isSubmitting;

  int? _updatingId;
  int? get updatingId => _updatingId;

  // ─── Fetch Demandes ───
  Future<void> fetchDemandes({bool forceRefresh = false}) async {
    if (_demandes.isNotEmpty && !forceRefresh) {
      _refreshDemandesInBackground();
      return;
    }

    if (_demandes.isEmpty) {
      _isLoadingDemandes = true;
      notifyListeners();
    }

    try {
      final user = StorageService.getUser();
      final idPharmacien = user?.id;
      final idGouvernorat = user?.idGouvernorat;
      final idTbgarde = user?.idGarde;

      final response = await _api.post(
        'medicament/allDemandes',
        data: {
          if (idPharmacien != null) 'id_pharmacien': idPharmacien,
          if (idGouvernorat != null) 'id_gouvernorat': idGouvernorat,
          if (idTbgarde != null) 'id_tbgarde': idTbgarde,
        },
        useCache: !forceRefresh,
        cacheDuration: const Duration(minutes: 1),
      );

      List rawList = [];
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        rawList = response.data['data'];
      } else if (response.data is Map && response.data['entities'] is List) {
        rawList = response.data['entities'];
      }

      _demandes = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => DemandeMedicamentItem.fromJson(j))
          .toList();
    } catch (e) {
      debugPrint('Error fetching demandes: $e');
    } finally {
      _isLoadingDemandes = false;
      notifyListeners();
    }
  }

  void _refreshDemandesInBackground() async {
    try {
      final user = StorageService.getUser();
      final idPharmacien = user?.id;
      final idGouvernorat = user?.idGouvernorat;
      final idTbgarde = user?.idGarde;

      final response = await _api.post(
        'medicament/allDemandes',
        data: {
          if (idPharmacien != null) 'id_pharmacien': idPharmacien,
          if (idGouvernorat != null) 'id_gouvernorat': idGouvernorat,
          if (idTbgarde != null) 'id_tbgarde': idTbgarde,
        },
      );

      List rawList = [];
      if (response.data is List) {
        rawList = response.data;
      } else if (response.data is Map && response.data['data'] is List) {
        rawList = response.data['data'];
      } else if (response.data is Map && response.data['entities'] is List) {
        rawList = response.data['entities'];
      }

      _demandes = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => DemandeMedicamentItem.fromJson(j))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  // ─── Fetch Dropdown Options (Medicaments, Gouvernorats, Zones, Grossistes) ───
  Future<void> fetchAllOptions() async {
    // Launch all independently with caching so medicaments are ready right away
    fetchMedicaments();
    _fetchGouvernorats();
    _fetchZones();
    _fetchGrossistes();
  }

  Future<void> fetchMedicaments({bool force = false}) async {
    if (_medicaments.isNotEmpty && !force) return;
    if (_medicaments.isEmpty) {
      _isLoadingMedicaments = true;
      notifyListeners();
    }

    try {
      final res = await _api.post(
        'patient/allMedicaments',
        data: {},
        useCache: !force,
        cacheDuration: const Duration(minutes: 10),
      );
      List list = [];
      if (res.data is List) {
        list = res.data;
      } else if (res.data is Map && res.data['data'] is List) {
        list = res.data['data'];
      }
      _medicaments = list.map((e) {
        final id = e['id'];
        final nom = (e['produit'] ?? e['nom'] ?? 'Médicament').toString();
        return OptionItem(value: id, label: nom);
      }).toList();
    } catch (e) {
      debugPrint('Error fetching medicaments: $e');
    } finally {
      _isLoadingMedicaments = false;
      notifyListeners();
    }
  }

  Future<void> _fetchGouvernorats() async {
    try {
      final res = await _api.post(
        'user/allGouvernorat',
        data: {},
        useCache: true,
        cacheDuration: const Duration(minutes: 10),
      );
      List list = [];
      if (res.data is List) {
        list = res.data;
      } else if (res.data is Map && res.data['data'] is List) {
        list = res.data['data'];
      }
      _gouvernorats = list.map((e) {
        final id = e['id'];
        final nom = (e['nom'] ?? e['designation'] ?? '').toString();
        return OptionItem(value: id, label: nom);
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching gouvernorats: $e');
    }
  }

  Future<void> _fetchZones() async {
    try {
      final res = await _api.post(
        'zone/fetchActiveZone',
        data: {},
        useCache: true,
        cacheDuration: const Duration(minutes: 10),
      );
      List list = [];
      if (res.data is List) {
        list = res.data;
      } else if (res.data is Map && res.data['data'] is List) {
        list = res.data['data'];
      }
      _zones = list.map((e) {
        final id = e['id'];
        final designation = (e['designation'] ?? e['nom'] ?? '').toString();
        return OptionItem(value: id, label: designation);
      }).toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching active zones: $e');
    }
  }

  Future<void> _fetchGrossistes() async {
    try {
      final res = await _api.post(
        'medicament/allGrossistes',
        data: {},
        useCache: true,
        cacheDuration: const Duration(minutes: 10),
      );
      List list = [];
      if (res.data is List) {
        list = res.data;
      } else if (res.data is Map && res.data['data'] is List) {
        list = res.data['data'];
      }
      _grossistes = list
          .whereType<Map<String, dynamic>>()
          .map((e) => GrossisteItem.fromJson(e))
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching grossistes: $e');
    }
  }

  // ─── Add Demande ───
  Future<bool> addDemande({
    required dynamic idMedicament,
    dynamic idGouvernorat,
    dynamic idTbgarde,
    required dynamic type,
    String? dateExpiration,
    List<dynamic>? grossistes,
  }) async {
    _isSubmitting = true;
    notifyListeners();

    try {
      final user = StorageService.getUser();
      final idPharmacien = user?.id;

      final payload = {
        'id_medicament': idMedicament,
        'id_gouvernorat': idGouvernorat,
        'id_tbgarde': idTbgarde,
        'id_pharmacien': idPharmacien,
        'type': type,
        'date_expiration': (dateExpiration == null || dateExpiration.isEmpty) ? null : dateExpiration,
        'grossistes': grossistes ?? [],
      };

      final response = await _api.post('medicament/addDemande', data: payload);
      _isSubmitting = false;
      notifyListeners();

      if (response.data != null && response.data['error'] != true) {
        await fetchDemandes();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error adding demande: $e');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Update Demande (Accepter / Disponible) ───
  Future<bool> updateDemande({
    required int id,
    required dynamic users,
    required String produit,
    dynamic idGrossiste,
  }) async {
    _updatingId = id;
    notifyListeners();

    try {
      final user = StorageService.getUser();
      final idPharmacien = user?.id;

      final payload = {
        'id': id,
        'users': users,
        'id_pharmacien': idPharmacien,
        'produit': produit,
        'id_grossiste': idGrossiste,
      };

      final response = await _api.post('medicament/updateDemande', data: payload);
      _updatingId = null;
      notifyListeners();

      if (response.data != null && response.data['error'] != true) {
        await fetchDemandes();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating demande: $e');
      _updatingId = null;
      notifyListeners();
      return false;
    }
  }
}
