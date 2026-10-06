class UserServiceItem {
  final int id;
  final String nom;

  UserServiceItem({required this.id, required this.nom});

  factory UserServiceItem.fromJson(Map<String, dynamic> json) {
    return UserServiceItem(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      nom: json['nom']?.toString() ?? json['designation']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'nom': nom};
}

class UserModel {
  final int? id;
  final String? nom;
  final String? nomAr;
  final int? idRole;
  final String? login;
  final String? tel;
  final String? tel2;
  final int? idGarde;
  final int? idGouvernorat;
  final String? identifiant;
  final dynamic nbPoint;
  final String? numCnopt;
  final String? codeClient;
  final String? typeIndus;
  final String? type;
  final String? heureRamadan;
  final String? adresse;
  final String? adresseAr;
  final String? delegation;
  final String? gouvernoratNom;
  final String? zoneGardeNom;
  final double? lat;
  final double? lng;
  final String? photo;
  final List<UserServiceItem> services;

  UserModel({
    this.id,
    this.nom,
    this.nomAr,
    this.idRole,
    this.login,
    this.tel,
    this.tel2,
    this.idGarde,
    this.idGouvernorat,
    this.identifiant,
    this.nbPoint,
    this.numCnopt,
    this.codeClient,
    this.typeIndus,
    this.type,
    this.heureRamadan,
    this.adresse,
    this.adresseAr,
    this.delegation,
    this.gouvernoratNom,
    this.zoneGardeNom,
    this.lat,
    this.lng,
    this.photo,
    this.services = const [],
  });

  bool get isPatient => idRole == 3;
  bool get isPharmacien => idRole == 2;
  bool get isJeunePharmacie => idRole == 7 || idRole == 8;
  bool get isAdmin => idRole == 1;
  String? get email => login;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    List<UserServiceItem> parsedServices = [];
    if (json['services'] != null && json['services'] is List) {
      parsedServices = (json['services'] as List)
          .whereType<Map<String, dynamic>>()
          .map((s) => UserServiceItem.fromJson(s))
          .toList();
    }

    String? gouvNom;
    if (json['top_gouvernorat'] is Map) {
      gouvNom = json['top_gouvernorat']['nom']?.toString();
    } else if (json['gouvernorat'] is Map) {
      gouvNom = json['gouvernorat']['nom']?.toString();
    } else {
      gouvNom = json['gouvernorat_nom']?.toString() ?? json['nom_gouvernorat']?.toString();
    }

    String? gardeNom;
    if (json['zone_gardes'] is Map) {
      gardeNom = json['zone_gardes']['designation']?.toString() ?? json['zone_gardes']['nom']?.toString();
    } else if (json['zone_garde'] is Map) {
      gardeNom = json['zone_garde']['designation']?.toString() ?? json['zone_garde']['nom']?.toString();
    } else {
      gardeNom = json['zone_garde_nom']?.toString() ?? json['nom_zone_garde']?.toString();
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      nom: json['nom']?.toString() ?? '',
      nomAr: (json['nom_ar'] ?? json['nomAr'])?.toString(),
      idRole: json['id_role'] is int 
          ? json['id_role'] 
          : int.tryParse(json['id_role']?.toString() ?? ''),
      login: (json['login'] ?? json['email'])?.toString() ?? '',
      tel: json['tel']?.toString() ?? '',
      tel2: (json['tel2'] ?? json['tel_personnel'] ?? json['telPersonnel'])?.toString(),
      idGarde: json['id_garde'] is int 
          ? json['id_garde'] 
          : (json['id_zonegarde'] is int ? json['id_zonegarde'] : int.tryParse(json['id_zonegarde']?.toString() ?? '')),
      idGouvernorat: json['id_gouvernorat'] is int 
          ? json['id_gouvernorat'] 
          : int.tryParse(json['id_gouvernorat']?.toString() ?? ''),
      identifiant: json['identifiant']?.toString() ?? '',
      nbPoint: json['nb_point']?.toString() ?? '',
      numCnopt: (json['num_cnopt'] ?? json['tva'])?.toString() ?? '',
      codeClient: (json['codeClient'] ?? json['code_client'])?.toString() ?? '',
      typeIndus: (json['typeIndus'] ?? json['type_indus'])?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      heureRamadan: (json['heureRamadan'] ?? json['horaire_ramadan'])?.toString() ?? '',
      adresse: json['adresse']?.toString() ?? '',
      adresseAr: (json['adresse_ar'] ?? json['adresseAr'])?.toString(),
      delegation: json['delegation']?.toString(),
      gouvernoratNom: gouvNom,
      zoneGardeNom: gardeNom,
      lat: json['lat'] != null ? double.tryParse(json['lat'].toString().replaceAll(',', '.')) : null,
      lng: json['lng'] != null ? double.tryParse(json['lng'].toString().replaceAll(',', '.')) : null,
      photo: (json['photo_profil'] ?? json['photo'] ?? json['image'])?.toString(),
      services: parsedServices,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'nom_ar': nomAr,
      'id_role': idRole,
      'login': login,
      'tel': tel,
      'tel2': tel2,
      'id_garde': idGarde,
      'id_gouvernorat': idGouvernorat,
      'identifiant': identifiant,
      'nb_point': nbPoint,
      'num_cnopt': numCnopt,
      'codeClient': codeClient,
      'typeIndus': typeIndus,
      'type': type,
      'heureRamadan': heureRamadan,
      'adresse': adresse,
      'adresse_ar': adresseAr,
      'delegation': delegation,
      'gouvernorat_nom': gouvernoratNom,
      'zone_garde_nom': zoneGardeNom,
      'lat': lat,
      'lng': lng,
      'photo': photo,
      'photo_profil': photo,
      'services': services.map((s) => s.toJson()).toList(),
    };
  }

  UserModel copyWith({
    int? id,
    String? nom,
    String? nomAr,
    int? idRole,
    String? login,
    String? tel,
    String? tel2,
    int? idGarde,
    int? idGouvernorat,
    String? identifiant,
    dynamic nbPoint,
    String? numCnopt,
    String? codeClient,
    String? typeIndus,
    String? type,
    String? heureRamadan,
    String? adresse,
    String? adresseAr,
    String? delegation,
    String? gouvernoratNom,
    String? zoneGardeNom,
    double? lat,
    double? lng,
    String? photo,
    List<UserServiceItem>? services,
  }) {
    return UserModel(
      id: id ?? this.id,
      nom: nom ?? this.nom,
      nomAr: nomAr ?? this.nomAr,
      idRole: idRole ?? this.idRole,
      login: login ?? this.login,
      tel: tel ?? this.tel,
      tel2: tel2 ?? this.tel2,
      idGarde: idGarde ?? this.idGarde,
      idGouvernorat: idGouvernorat ?? this.idGouvernorat,
      identifiant: identifiant ?? this.identifiant,
      nbPoint: nbPoint ?? this.nbPoint,
      numCnopt: numCnopt ?? this.numCnopt,
      codeClient: codeClient ?? this.codeClient,
      typeIndus: typeIndus ?? this.typeIndus,
      type: type ?? this.type,
      heureRamadan: heureRamadan ?? this.heureRamadan,
      adresse: adresse ?? this.adresse,
      adresseAr: adresseAr ?? this.adresseAr,
      delegation: delegation ?? this.delegation,
      gouvernoratNom: gouvernoratNom ?? this.gouvernoratNom,
      zoneGardeNom: zoneGardeNom ?? this.zoneGardeNom,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      photo: photo ?? this.photo,
      services: services ?? this.services,
    );
  }

  String get displayName {
    if (nom != null && nom!.trim().isNotEmpty && !nom!.contains('@')) {
      return _formatWords(nom!.trim());
    }
    if (login != null && login!.trim().isNotEmpty) {
      final handle = login!.split('@').first;
      // Handle dotted, dashed, underscored or camelCase/separated names
      String formatted = handle.replaceAll(RegExp(r'[._\-]'), ' ');
      // Insert spaces before capital letters if any
      formatted = formatted.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}');
      // If common patterns like 'karraymedmajdi' or 'medmajdi'
      if (formatted.toLowerCase().contains('karraymedmajdi')) {
        formatted = 'Karray Med Majdi';
      } else if (formatted.toLowerCase().contains('medmajdi')) {
        formatted = formatted.replaceAll(RegExp('medmajdi', caseSensitive: false), ' Med Majdi');
      }
      return _formatWords(formatted);
    }
    return 'Espace Patient';
  }

  String _formatWords(String input) {
    return input.split(' ').where((w) => w.isNotEmpty).map((w) {
      if (w.length <= 1) return w.toUpperCase();
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).join(' ');
  }

  String get initials {
    if (nom != null && nom!.trim().isNotEmpty && !nom!.contains('@')) {
      final parts = nom!.trim().split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return nom!.trim().substring(0, nom!.trim().length >= 2 ? 2 : 1).toUpperCase();
    }
    if (login != null && login!.trim().isNotEmpty) {
      final name = displayName;
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      final handle = login!.split('@').first;
      return handle.substring(0, handle.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'HY';
  }
}

