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
    );
  }
}
