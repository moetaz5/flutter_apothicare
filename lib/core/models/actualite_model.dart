import 'dart:convert';

String sanitizeFrenchText(String? input) {
  if (input == null || input.isEmpty) return '';
  String text = input;

  // 0. Normalize Mathematical Bold / Italic / Sans-Serif / Unicode styling characters
  final runes = text.runes.toList();
  final buffer = StringBuffer();
  for (int i = 0; i < runes.length; i++) {
    final r = runes[i];
    // Math Bold capital letters A-Z: 0x1D400 - 0x1D419 -> 'A'..'Z'
    if (r >= 0x1D400 && r <= 0x1D419) {
      buffer.writeCharCode(0x41 + (r - 0x1D400));
    }
    // Math Bold small letters a-z: 0x1D41A - 0x1D433 -> 'a'..'z'
    else if (r >= 0x1D41A && r <= 0x1D433) {
      buffer.writeCharCode(0x61 + (r - 0x1D41A));
    }
    // Math Italic capital letters A-Z: 0x1D434 - 0x1D44D
    else if (r >= 0x1D434 && r <= 0x1D44D) {
      buffer.writeCharCode(0x41 + (r - 0x1D434));
    }
    // Math Italic small letters a-z: 0x1D44E - 0x1D467
    else if (r >= 0x1D44E && r <= 0x1D467) {
      buffer.writeCharCode(0x61 + (r - 0x1D44E));
    }
    // Math Bold Italic A-Z: 0x1D468 - 0x1D481
    else if (r >= 0x1D468 && r <= 0x1D481) {
      buffer.writeCharCode(0x41 + (r - 0x1D468));
    }
    // Math Bold Italic a-z: 0x1D482 - 0x1D49B
    else if (r >= 0x1D482 && r <= 0x1D49B) {
      buffer.writeCharCode(0x61 + (r - 0x1D482));
    }
    // Math Sans-Serif A-Z: 0x1D5A0 - 0x1D5B9
    else if (r >= 0x1D5A0 && r <= 0x1D5B9) {
      buffer.writeCharCode(0x41 + (r - 0x1D5A0));
    }
    // Math Sans-Serif a-z: 0x1D5BA - 0x1D5D3
    else if (r >= 0x1D5BA && r <= 0x1D5D3) {
      buffer.writeCharCode(0x61 + (r - 0x1D5BA));
    }
    // Math Sans-Serif Bold A-Z: 0x1D5D4 - 0x1D5ED
    else if (r >= 0x1D5D4 && r <= 0x1D5ED) {
      buffer.writeCharCode(0x41 + (r - 0x1D5D4));
    }
    // Math Sans-Serif Bold a-z: 0x1D5EE - 0x1D607
    else if (r >= 0x1D5EE && r <= 0x1D607) {
      buffer.writeCharCode(0x61 + (r - 0x1D5EE));
    }
    // Math Bold digits 0-9: 0x1D7CE - 0x1D7D7
    else if (r >= 0x1D7CE && r <= 0x1D7D7) {
      buffer.writeCharCode(0x30 + (r - 0x1D7CE));
    }
    // Math Sans-Serif Bold digits 0-9: 0x1D7EC - 0x1D7F5
    else if (r >= 0x1D7EC && r <= 0x1D7F5) {
      buffer.writeCharCode(0x30 + (r - 0x1D7EC));
    }
    // Fullwidth ASCII A-Z: 0xFF21 - 0xFF3A
    else if (r >= 0xFF21 && r <= 0xFF3A) {
      buffer.writeCharCode(0x41 + (r - 0xFF21));
    }
    // Fullwidth ASCII a-z: 0xFF41 - 0xFF5A
    else if (r >= 0xFF41 && r <= 0xFF5A) {
      buffer.writeCharCode(0x61 + (r - 0xFF41));
    }
    // Fullwidth digits 0-9: 0xFF10 - 0xFF19
    else if (r >= 0xFF10 && r <= 0xFF19) {
      buffer.writeCharCode(0x30 + (r - 0xFF10));
    } else {
      buffer.writeCharCode(r);
    }
  }
  text = buffer.toString();

  // Combine diacritics into precomposed characters
  text = text
      .replaceAll('e\u0300', 'è')
      .replaceAll('E\u0300', 'È')
      .replaceAll('a\u0300', 'à')
      .replaceAll('A\u0300', 'À')
      .replaceAll('u\u0300', 'ù')
      .replaceAll('U\u0300', 'Ù')
      .replaceAll('e\u0301', 'é')
      .replaceAll('E\u0301', 'É')
      .replaceAll('e\u0302', 'ê')
      .replaceAll('E\u0302', 'Ê')
      .replaceAll('a\u0302', 'â')
      .replaceAll('A\u0302', 'Â')
      .replaceAll('i\u0302', 'î')
      .replaceAll('I\u0302', 'Î')
      .replaceAll('o\u0302', 'ô')
      .replaceAll('O\u0302', 'Ô')
      .replaceAll('u\u0302', 'û')
      .replaceAll('U\u0302', 'Û')
      .replaceAll('e\u0308', 'ë')
      .replaceAll('E\u0308', 'Ë')
      .replaceAll('i\u0308', 'ï')
      .replaceAll('I\u0308', 'Ï')
      .replaceAll('u\u0308', 'ü')
      .replaceAll('U\u0308', 'Ü')
      .replaceAll('c\u0327', 'ç')
      .replaceAll('C\u0327', 'Ç')
      .replaceAll(RegExp(r'[\u0300-\u036F]'), '');

  // 1. Double encoded UTF-8 Mojibake detection & decode
  if (text.contains('Ã') ||
      text.contains('Â') ||
      text.contains('â€™') ||
      text.contains('â€“') ||
      text.contains('â€”') ||
      text.contains('â€¦') ||
      text.contains('ð')) {
    try {
      final bytes = latin1.encode(text);
      final decoded = utf8.decode(bytes);
      if (decoded.isNotEmpty && !decoded.contains('Ã')) {
        text = decoded;
      }
    } catch (_) {}
  }

  // 2. Common Latin1 -> UTF8 Mojibake mappings
  text = text
      .replaceAll('Ã©', 'é')
      .replaceAll('Ã¨', 'è')
      .replaceAll('Ãª', 'ê')
      .replaceAll('Ã«', 'ë')
      .replaceAll('Ã ', 'à')
      .replaceAll('Ã¢', 'â')
      .replaceAll('Ã®', 'î')
      .replaceAll('Ã¯', 'ï')
      .replaceAll('Ã´', 'ô')
      .replaceAll('Ã¹', 'ù')
      .replaceAll('Ã»', 'û')
      .replaceAll('Ã§', 'ç')
      .replaceAll('Ã‰', 'É')
      .replaceAll('Ãˆ', 'È')
      .replaceAll('Ã€', 'À')
      .replaceAll('Ã‡', 'Ç')
      .replaceAll('â€™', "'")
      .replaceAll('â€˜', "'")
      .replaceAll('â€“', "–")
      .replaceAll('â€”', "—")
      .replaceAll('â€¦', "…")
      .replaceAll('Â«', "«")
      .replaceAll('Â»', "»")
      .replaceAll('Â°', "°")
      .replaceAll('Â', '');

  // 3. HTML Entities
  text = text
      .replaceAll('&eacute;', 'é')
      .replaceAll('&Eacute;', 'É')
      .replaceAll('&egrave;', 'è')
      .replaceAll('&Egrave;', 'È')
      .replaceAll('&ecirc;', 'ê')
      .replaceAll('&Ecirc;', 'Ê')
      .replaceAll('&euml;', 'ë')
      .replaceAll('&agrave;', 'à')
      .replaceAll('&Agrave;', 'À')
      .replaceAll('&acirc;', 'â')
      .replaceAll('&ccedil;', 'ç')
      .replaceAll('&Ccedil;', 'Ç')
      .replaceAll('&icirc;', 'î')
      .replaceAll('&iuml;', 'ï')
      .replaceAll('&ocirc;', 'ô')
      .replaceAll('&ugrave;', 'ù')
      .replaceAll('&ucirc;', 'û')
      .replaceAll('&rsquo;', "'")
      .replaceAll('&lsquo;', "'")
      .replaceAll('&rdquo;', '"')
      .replaceAll('&ldquo;', '"')
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&hellip;', '…')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&#039;', "'");

  // 4. Handle replacement artifacts (\uFFFD / squares) intelligently for French text
  text = text
      .replaceAll(RegExp(r'(\d+)\s*[\uFFFD]\s*mes?', caseSensitive: false), r'${1}èmes')
      .replaceAll(RegExp(r'(\d+)\s*[\uFFFD]\s*me', caseSensitive: false), r'${1}ème')
      .replaceAll(RegExp(r'Journe[\uFFFD]es?', caseSensitive: false), 'Journées')
      .replaceAll(RegExp(r'Journe[\uFFFD]', caseSensitive: false), 'Journée')
      .replaceAll(RegExp(r'fe[\uFFFD]rie[\uFFFD]s?', caseSensitive: false), 'fériés')
      .replaceAll(RegExp(r'fe[\uFFFD]rie', caseSensitive: false), 'férié')
      .replaceAll(RegExp(r'me[\uFFFD]dicaments?', caseSensitive: false), 'médicaments')
      .replaceAll(RegExp(r'me[\uFFFD]dicament', caseSensitive: false), 'médicament')
      .replaceAll(RegExp(r'me[\uFFFD]decin', caseSensitive: false), 'médecin')
      .replaceAll(RegExp(r'me[\uFFFD]decine', caseSensitive: false), 'médecine')
      .replaceAll(RegExp(r'e[\uFFFD]ve[\uFFFD]nements?', caseSensitive: false), 'événements')
      .replaceAll(RegExp(r'e[\uFFFD]ve[\uFFFD]nement', caseSensitive: false), 'événement')
      .replaceAll(RegExp(r'ge[\uFFFD]ne[\uFFFD]ral', caseSensitive: false), 'général')
      .replaceAll(RegExp(r're[\uFFFD]gional', caseSensitive: false), 'régional')
      .replaceAll(RegExp(r're[\uFFFD]gion', caseSensitive: false), 'région')
      .replaceAll(RegExp(r'arre[\uFFFD]te[\uFFFD]', caseSensitive: false), 'arrêté')
      .replaceAll(RegExp(r'socie[\uFFFD]te[\uFFFD]', caseSensitive: false), 'société')
      .replaceAll(RegExp(r'pre[\uFFFD]sident', caseSensitive: false), 'président')
      .replaceAll(RegExp(r'de[\uFFFD]cision', caseSensitive: false), 'décision')
      .replaceAll(RegExp(r'de[\uFFFD]cret', caseSensitive: false), 'décret')
      .replaceAll(RegExp(r'conge[\uFFFD]s?', caseSensitive: false), 'congés')
      .replaceAll(RegExp(r'sante[\uFFFD]', caseSensitive: false), 'santé')
      .replaceAll(RegExp(r'cre[\uFFFD]ation', caseSensitive: false), 'création')
      .replaceAll(RegExp(r'activite[\uFFFD]s?', caseSensitive: false), 'activités')
      .replaceAll(RegExp(r'disponibilite[\uFFFD]', caseSensitive: false), 'disponibilité')
      .replaceAll(RegExp(r'se[\uFFFD]curite[\uFFFD]', caseSensitive: false), 'sécurité')
      .replaceAll(RegExp(r'comite[\uFFFD]', caseSensitive: false), 'comité')
      .replaceAll(RegExp(r'e[\uFFFD]lection', caseSensitive: false), 'élection')
      .replaceAll(RegExp(r'e[\uFFFD]tudiant', caseSensitive: false), 'étudiant')
      .replaceAll(RegExp(r'fe[\uFFFD]de[\uFFFD]ration', caseSensitive: false), 'fédération')
      .replaceAll(RegExp(r'(\w)[\uFFFD]e\b', caseSensitive: false), r'${1}ée')
      .replaceAll(RegExp(r'(\w)[\uFFFD]s\b', caseSensitive: false), r'${1}és')
      .replaceAll(RegExp(r'\b[\uFFFD]te\b', caseSensitive: false), 'été')
      .replaceAll(RegExp(r'\b[\uFFFD]tre\b', caseSensitive: false), 'être')
      .replaceAll(RegExp(r'\b[\uFFFD]', caseSensitive: false), 'É')
      .replaceAll(RegExp(r'[\uFFFD]\b', caseSensitive: false), 'é')
      .replaceAll('\uFFFD', 'é');

  return text.trim();
}

class ActualiteModel {
  final int? id;
  final String? titre;
  final String? description;
  final String? image;
  final String? video;
  final String? file;
  final int? idTheme;
  final String? themeNom;
  final String? createdAt;
  final String? source;
  final int? vues;
  final int etat;

  ActualiteModel({
    this.id,
    this.titre,
    this.description,
    this.image,
    this.video,
    this.file,
    this.idTheme,
    this.themeNom,
    this.createdAt,
    this.source,
    this.vues,
    this.etat = 1,
  });

  factory ActualiteModel.fromJson(Map<String, dynamic> json) {
    return ActualiteModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      titre: sanitizeFrenchText(json['titre']?.toString()),
      description: sanitizeFrenchText((json['description'] ?? json['contenu'] ?? json['detail'])?.toString()),
      image: json['image']?.toString(),
      video: json['video']?.toString(),
      file: json['file']?.toString(),
      idTheme: json['id_theme'] is int
          ? json['id_theme']
          : int.tryParse(json['id_theme']?.toString() ?? ''),
      themeNom: sanitizeFrenchText(
        json['theme'] != null && json['theme'] is Map
            ? json['theme']['nom']?.toString()
            : json['theme_nom']?.toString(),
      ),
      createdAt: (json['createdAt'] ?? json['date'])?.toString() ?? '',
      source: json['source']?.toString() ?? 'CNOPT',
      vues: json['vues'] is int ? json['vues'] : int.tryParse(json['vues']?.toString() ?? '0'),
      etat: json['etat'] is int ? json['etat'] : int.tryParse(json['etat']?.toString() ?? '1') ?? 1,
    );
  }
}

class ThemeModel {
  final int id;
  final String nom;

  ThemeModel({required this.id, required this.nom});

  factory ThemeModel.fromJson(Map<String, dynamic> json) {
    return ThemeModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      nom: sanitizeFrenchText(json['nom']?.toString()),
    );
  }
}

