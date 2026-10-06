import 'package:flutter/material.dart';
import '../network/api_client.dart';

class ProcedureItem {
  final int id;
  final String nom;
  final String? description;
  final String? image;
  final String? document;

  ProcedureItem({
    required this.id,
    required this.nom,
    this.description,
    this.image,
    this.document,
  });

  factory ProcedureItem.fromJson(Map<dynamic, dynamic> json) {
    return ProcedureItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nom: json['nom']?.toString() ?? 'Procédure',
      description: json['description']?.toString(),
      image: json['image']?.toString(),
      document: json['document']?.toString(),
    );
  }
}

class ProcedureProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();

  List<ProcedureItem> _procedures = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ProcedureItem> get procedures => _procedures;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchProcedures({bool forceRefresh = false}) async {
    if (_procedures.isNotEmpty && !forceRefresh) {
      _refreshInBackground();
      return;
    }

    if (_procedures.isEmpty) {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await _api.post(
        'procedure/allProcedure',
        data: {},
        useCache: !forceRefresh,
        cacheDuration: const Duration(minutes: 5),
      );

      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['procedures'] is List) {
          rawList = map['procedures'] as List;
        } else if (map['entities'] is List) {
          rawList = map['entities'] as List;
        }
      }

      if (rawList != null) {
        _procedures = rawList
            .whereType<Map>()
            .map((e) => ProcedureItem.fromJson(e))
            .toList();
      }
    } catch (e) {
      debugPrint('Error fetchProcedures: $e');
      if (_procedures.isEmpty) {
        _errorMessage = 'Erreur lors du chargement des procédures.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshInBackground() async {
    try {
      final response = await _api.post('procedure/allProcedure', data: {});
      List<dynamic>? rawList;
      if (response.data is List) {
        rawList = response.data as List;
      } else if (response.data is Map) {
        final map = response.data as Map;
        if (map['data'] is List) {
          rawList = map['data'] as List;
        } else if (map['procedures'] is List) {
          rawList = map['procedures'] as List;
        } else if (map['entities'] is List) {
          rawList = map['entities'] as List;
        }
      }
      if (rawList != null) {
        _procedures = rawList
            .whereType<Map>()
            .map((e) => ProcedureItem.fromJson(e))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }
}
