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
    return GardeModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      nomPharmacie: (json['name'] ?? json['nom'] ?? json['nom_pharmacie'] ?? json['pharmacie'] ?? json['user_nom'])?.toString() ?? 'Pharmacie de Garde',
      adresse: (json['adresse'] ?? json['address'] ?? json['rue'])?.toString() ?? '',
      tel: (json['tel1'] ?? json['tel'] ?? json['telephone'] ?? json['phone'])?.toString() ?? '',
      lat: json['lat'] != null ? double.tryParse(json['lat'].toString()) : null,
      lng: json['lng'] != null ? double.tryParse(json['lng'].toString()) : null,
      typeGarde: (json['type_garde'] ?? (json['is_nuit'] == true || json['id_type'] == 2 ? 'Nuit' : 'Jour'))?.toString() ?? 'Jour',
      heureDebut: json['heure_debut']?.toString() ?? '',
      heureFin: json['heure_fin']?.toString() ?? '',
      dateGarde: json['date']?.toString() ?? '',
      isOpen: json['is_open'] == true || json['status'] == 1 || json['ouvert'] == true || true,
      tva: json['tva']?.toString() ?? '',
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
