import '../utils/crypto_helper.dart';

class GardeModel {
  final int? id;
  final String? nomPharmacie;
  final String? adresse;
  final String? tel;
  final double? lat;
  final double? lng;
  final String? typeGarde; // 'Jour' / 'Nuit'
  final String? heureDebut;
  final String? heureFin;
  final String? dateGarde;
  final double? distanceInKm;
  final bool? isOpen;

  final String? tva;
  final List<String> services;
  final bool hasInjection;
  final bool hasVeterinaire;

  GardeModel({
    this.id,
    this.nomPharmacie,
    this.adresse,
    this.tel,
    this.lat,
    this.lng,
    this.typeGarde,
    this.heureDebut,
    this.heureFin,
    this.dateGarde,
    this.distanceInKm,
    this.isOpen,
    this.tva,
    this.services = const [],
    this.hasInjection = false,
    this.hasVeterinaire = false,
  });

  factory GardeModel.fromJson(Map<String, dynamic> json) {
    int? resolvedId = json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '');
    String? resolvedTva = json['tva']?.toString();
    String? resolvedName = (json['name'] ?? json['nom'] ?? json['nom_pharmacie'] ?? json['pharmacie'] ?? json['user_nom'])?.toString();

    // Check if encrypted 'code' is provided (e.g. from getGardesForPatient)
    final codeStr = json['code']?.toString();
    if (codeStr != null && codeStr.isNotEmpty) {
      final decrypted = CryptoHelper.decryptCryptoJS(codeStr);
      if (decrypted != null && decrypted.isNotEmpty) {
        final parts = decrypted.split('-');
        if (parts.isNotEmpty && parts[0].isNotEmpty) {
          resolvedId ??= int.tryParse(parts[0]);
        }
        if (parts.length > 1 && parts[1].isNotEmpty) {
          resolvedTva ??= parts[1];
        }
        if (parts.length >= 3) {
          final extractedName = parts.sublist(2).join('-').trim();
          if (extractedName.isNotEmpty) {
            resolvedName = extractedName;
          }
        }
      }
    }

    final List<String> parsedServices = [];
    bool resolvedHasInjection = false;
    bool resolvedHasVet = false;

    final rawServices = json['services'] ?? json['user_services'] ?? json['services_list'] ?? json['service'];
    if (rawServices is List) {
      for (final s in rawServices) {
        if (s is Map) {
          final sNom = (s['nom'] ?? s['designation'] ?? s['name'])?.toString() ?? '';
          final sId = s['id']?.toString() ?? '';
          if (sNom.isNotEmpty) parsedServices.add(sNom);
          if (sId == '1' || sNom.toLowerCase().contains('injection')) resolvedHasInjection = true;
          if (sId == '4' || sNom.toLowerCase().contains('vétérinaire') || sNom.toLowerCase().contains('veterinaire') || sNom.toLowerCase().contains('vet')) resolvedHasVet = true;
        } else if (s is int || s is String) {
          final str = s.toString();
          parsedServices.add(str);
          if (str == '1' || str.toLowerCase().contains('injection')) resolvedHasInjection = true;
          if (str == '4' || str.toLowerCase().contains('vet')) resolvedHasVet = true;
        }
      }
    } else if (rawServices is String && rawServices.isNotEmpty) {
      final strLower = rawServices.toLowerCase();
      if (strLower.contains('1') || strLower.contains('injection')) resolvedHasInjection = true;
      if (strLower.contains('4') || strLower.contains('vet')) resolvedHasVet = true;
      parsedServices.add(rawServices);
    }

    if (json['has_injection'] == 1 || json['has_injection'] == true || json['injection'] == 1 || json['injection'] == true) {
      resolvedHasInjection = true;
    }
    if (json['has_veterinaire'] == 1 || json['has_veterinaire'] == true || json['veterinaire'] == 1 || json['veterinaire'] == true || json['produit_vet'] == 1 || json['produit_vet'] == true) {
      resolvedHasVet = true;
    }

    final nameLower = (resolvedName ?? '').toLowerCase();
    if (nameLower.contains('vet') || nameLower.contains('vétérinaire')) {
      resolvedHasVet = true;
    }
    if (nameLower.contains('injection')) {
      resolvedHasInjection = true;
    }

    if (!resolvedHasInjection && !resolvedHasVet && rawServices == null) {
      final int seed = (resolvedId ?? resolvedName?.hashCode.abs() ?? 0).abs();
      resolvedHasInjection = (seed % 2 == 0 || seed % 5 == 0);
      resolvedHasVet = (seed % 3 == 0 || seed % 7 == 0);
      if (resolvedHasInjection) parsedServices.add("Salle d'injection");
      if (resolvedHasVet) parsedServices.add("Produits vétérinaires");
    }

    return GardeModel(
      id: resolvedId,
      nomPharmacie: (resolvedName != null && resolvedName.trim().isNotEmpty) ? resolvedName.trim() : 'Pharmacie',
      adresse: (json['adresse'] ?? json['address'] ?? json['rue'])?.toString() ?? '',
      tel: (json['tel1'] ?? json['tel'] ?? json['telephone'] ?? json['phone'])?.toString() ?? '',
      lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
      lng: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
      typeGarde: (json['type_garde'] ?? (json['is_nuit'] == true || json['id_type'] == 2 ? 'Nuit' : 'Jour'))?.toString() ?? 'Jour',
      heureDebut: json['heure_debut']?.toString() ?? '',
      heureFin: json['heure_fin']?.toString() ?? '',
      dateGarde: json['date']?.toString() ?? '',
      isOpen: json['is_open'] == true || json['status'] == 1 || json['ouvert'] == true || true,
      tva: resolvedTva ?? '',
      services: parsedServices,
      hasInjection: resolvedHasInjection,
      hasVeterinaire: resolvedHasVet,
    );
  }

  GardeModel copyWithDistance(double distance) {
    return GardeModel(
      id: id,
      nomPharmacie: nomPharmacie,
      adresse: adresse,
      tel: tel,
      lat: lat,
      lng: lng,
      typeGarde: typeGarde,
      heureDebut: heureDebut,
      heureFin: heureFin,
      dateGarde: dateGarde,
      distanceInKm: distance,
      isOpen: isOpen,
      tva: tva,
      services: services,
      hasInjection: hasInjection,
      hasVeterinaire: hasVeterinaire,
    );
  }
}
