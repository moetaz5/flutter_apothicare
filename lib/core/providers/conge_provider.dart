import 'package:flutter/material.dart';
import '../network/api_client.dart';
import '../storage/storage_service.dart';

class CongeItem {
  final int id;
  final int? idUser;
  final String dateDebut;
  final String dateFin;
  final String? description;
  final int? typeConge;
  final String? numCnopt;
  final int status; // 0: En attente, 1: Accepté, 2: Refusé
  final String? image;
  final DateTime? createdAt;

  CongeItem({
    required this.id,
    this.idUser,
    required this.dateDebut,
    required this.dateFin,
    this.description,
    this.typeConge,
    this.numCnopt,
    this.status = 0,
    this.image,
    this.createdAt,
  });

  factory CongeItem.fromJson(Map<dynamic, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['createdAt'] != null) {
        parsedDate = DateTime.parse(json['createdAt'].toString());
      }
    } catch (_) {}

    return CongeItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      idUser: json['id_user'] is int ? json['id_user'] : int.tryParse(json['id_user']?.toString() ?? ''),
      dateDebut: (json['date_debut'] ?? json['dateDebut'] ?? '').toString().split('T')[0],
      dateFin: (json['date_fin'] ?? json['dateFin'] ?? '').toString().split('T')[0],
      description: json['description']?.toString(),
      typeConge: json['type_conge'] is int ? json['type_conge'] : int.tryParse(json['type_conge']?.toString() ?? '1') ?? 1,
      numCnopt: json['num_cnopt']?.toString(),
      status: json['status'] is int ? json['status'] : int.tryParse(json['status']?.toString() ?? '0') ?? 0,
      image: json['image']?.toString(),
      createdAt: parsedDate,
    );
  }

  String get typeLabel {
    switch (typeConge) {
      case 1:
        return 'Congé Annuel';
      case 2:
        return 'Congé Maladie';
      case 3:
        return 'Congé Maternité';
      case 4:
        return 'Congé Sans Solde';
      default:
        return 'Congé Payé';
    }
  }

  String get statusLabel {
    switch (status) {
      case 1:
        return 'Accepté';
      case 2:
        return 'Refusé';
      default:
        return 'En attente';
    }
  }

  Color get statusColor {
    switch (status) {
      case 1:
        return const Color(0xFF22C55E); // Green
      case 2:
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFFF59E0B); // Amber
    }
  }
}

class CongeProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<CongeItem> _conges = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CongeItem> get conges => _conges;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchConges({bool forceRefresh = false}) async {
    if (_conges.isNotEmpty && !forceRefresh) {
      _refreshInBackground();
      return;
    }

    if (_conges.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _api.post(
        'conge/allConge',
        data: {},
        useCache: !forceRefresh,
        cacheDuration: const Duration(minutes: 2),
      );

      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['conges'] is List) {
          rawList = map['conges'] as List;
        } else if (map['entities'] is List) {
          rawList = map['entities'] as List;
        }
      }

      if (rawList != null) {
        final currentUserId = StorageService.getUser()?.id;
        _conges = rawList
            .whereType<Map>()
            .map((e) => CongeItem.fromJson(e))
            .where((item) => currentUserId == null || item.idUser == null || item.idUser == currentUserId)
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetchConges: $e');
      if (_conges.isEmpty) {
        _errorMessage = 'Erreur lors du chargement des congés.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshInBackground() async {
    try {
      final response = await _api.post('conge/allConge', data: {});
      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['conges'] is List) {
          rawList = map['conges'] as List;
        } else if (map['entities'] is List) {
          rawList = map['entities'] as List;
        }
      }
      if (rawList != null) {
        final currentUserId = StorageService.getUser()?.id;
        _conges = rawList
            .whereType<Map>()
            .map((e) => CongeItem.fromJson(e))
            .where((item) => currentUserId == null || item.idUser == null || item.idUser == currentUserId)
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> addConge({
    required String dateDebut,
    required String dateFin,
    required String description,
    required int typeConge,
    String? numCnopt,
    String? image,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userId = StorageService.getUser()?.id;
      final payload = {
        'id_user': userId,
        'date_debut': dateDebut,
        'date_fin': dateFin,
        'description': description,
        'type_conge': typeConge,
        if (numCnopt != null && numCnopt.isNotEmpty) 'num_cnopt': numCnopt,
        if (image != null) 'image': image,
      };

      final response = await _api.post('conge/addConge', data: payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchConges(forceRefresh: true);
        return true;
      }
    } catch (e) {
      debugPrint('Error addConge: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteConge(int id) async {
    try {
      final response = await _api.delete('conge/deleteConge/$id');
      if (response.statusCode == 200) {
        _conges.removeWhere((item) => item.id == id);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint('Error deleteConge: $e');
    }
    return false;
  }
}
