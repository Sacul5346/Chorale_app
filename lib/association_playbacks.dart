import 'dart:convert';

import 'package:http/http.dart' as http;

/// Association automatique des playbacks : on lit la liste des fichiers
/// audio d'un dossier Google Drive partagé, et on relie chaque fichier à la
/// chanson qui porte le même nom.
///
/// La lecture du dossier passe par l'API Google Drive avec une clé API,
/// fournie à la compilation : --dart-define=DRIVE_API_KEY=... (voir
/// .github/workflows/build-apk.yml). Elle n'est jamais écrite dans le code.
const cleApiDrive = String.fromEnvironment('DRIVE_API_KEY');

/// Identifiant d'un dossier Drive à partir de son lien de partage
/// (https://drive.google.com/drive/folders/ID?usp=sharing).
String? idDossierDrive(String lien) {
  final match =
      RegExp(r'/folders/([\w-]{10,})').firstMatch(lien.trim()) ??
      RegExp(
        r'drive\.google\.com/.*[?&]id=([\w-]{10,})',
      ).firstMatch(lien.trim());
  return match?.group(1);
}

/// Lien de partage d'un fichier, au format accepté par l'éditeur de paroles.
String lienFichierDrive(String idFichier) =>
    'https://drive.google.com/file/d/$idFichier/view';

const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'ì': 'i',
  'î': 'i',
  'ï': 'i',
  'ó': 'o',
  'ò': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ç': 'c',
  'ñ': 'n',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// Nom « comparable » : minuscules, sans accents, sans extension, sans
/// numéro de piste au début (« 01 - »), ponctuation remplacée par des espaces.
///   « 03 - Ry Tompo ô !.mp3 » (fichier) et « Ry Tompo o » donnent
///   « ry tompo o ».
/// [fichier] : retire aussi l'extension (seulement pour les noms de fichiers,
/// un titre comme « Salamo 23 v.12 » doit rester entier).
String normaliserNom(String nom, {bool fichier = false}) {
  var texte = nom.trim().toLowerCase();
  if (fichier) texte = texte.replaceFirst(RegExp(r'\.[a-z0-9]{2,4}$'), '');
  texte = texte.split('').map((c) => _accents[c] ?? c).join();
  texte = texte.replaceFirst(RegExp(r'^\d{1,3}\s*[-._)]\s*'), '');
  texte = texte.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
  return texte.trim();
}

class FichierDrive {
  final String id;
  final String nom;
  const FichierDrive(this.id, this.nom);
}

class ChansonExistante {
  final String id;
  final String titre;
  final String playbackActuel;
  const ChansonExistante(this.id, this.titre, [this.playbackActuel = '']);
}

class Correspondance {
  final ChansonExistante chanson;
  final FichierDrive fichier;
  const Correspondance(this.chanson, this.fichier);

  /// La chanson a déjà un autre playback (il serait remplacé).
  bool get remplace => chanson.playbackActuel.isNotEmpty && !dejaRelie;

  /// La chanson est déjà reliée à ce fichier : rien à faire.
  bool get dejaRelie => chanson.playbackActuel.contains(fichier.id);
}

class ResultatAssociation {
  final List<Correspondance> correspondances;

  /// Fichiers sans chanson du même nom (à renommer dans Drive).
  final List<FichierDrive> fichiersSansChanson;

  /// Noms partagés par plusieurs fichiers ou plusieurs chansons :
  /// impossible de choisir automatiquement.
  final List<String> ambigus;

  const ResultatAssociation(
    this.correspondances,
    this.fichiersSansChanson,
    this.ambigus,
  );
}

ResultatAssociation associer(
  List<ChansonExistante> chansons,
  List<FichierDrive> fichiers,
) {
  final chansonsParNom = <String, List<ChansonExistante>>{};
  for (final c in chansons) {
    chansonsParNom.putIfAbsent(normaliserNom(c.titre), () => []).add(c);
  }
  final fichiersParNom = <String, List<FichierDrive>>{};
  for (final f in fichiers) {
    fichiersParNom
        .putIfAbsent(normaliserNom(f.nom, fichier: true), () => [])
        .add(f);
  }

  final correspondances = <Correspondance>[];
  final sansChanson = <FichierDrive>[];
  final ambigus = <String>[];
  fichiersParNom.forEach((nom, fichiersDuNom) {
    final chansonsDuNom = chansonsParNom[nom];
    if (nom.isEmpty || chansonsDuNom == null) {
      sansChanson.addAll(fichiersDuNom);
    } else if (fichiersDuNom.length > 1 || chansonsDuNom.length > 1) {
      ambigus.add(fichiersDuNom.first.nom);
    } else {
      correspondances.add(
        Correspondance(chansonsDuNom.single, fichiersDuNom.single),
      );
    }
  });

  correspondances.sort(
    (a, b) =>
        a.chanson.titre.toLowerCase().compareTo(b.chanson.titre.toLowerCase()),
  );
  sansChanson.sort(
    (a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()),
  );
  ambigus.sort();
  return ResultatAssociation(correspondances, sansChanson, ambigus);
}

bool _estAudio(String mimeType, String nom) =>
    mimeType.startsWith('audio/') ||
    RegExp(
      r'\.(mp3|m4a|aac|wav|ogg|opus|flac|wma|amr)$',
      caseSensitive: false,
    ).hasMatch(nom);

class DriveException implements Exception {
  final String message;
  const DriveException(this.message);
}

/// Fichiers audio d'un dossier Drive public (sous-dossiers non compris).
Future<List<FichierDrive>> fichiersAudioDuDossier(String idDossier) async {
  if (cleApiDrive.isEmpty) {
    throw const DriveException(
      'La clé d’accès Google Drive n’est pas configurée dans cette version '
      'de l’app.',
    );
  }
  final fichiers = <FichierDrive>[];
  String? pageSuivante;
  do {
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': "'$idDossier' in parents and trashed = false",
      'fields': 'nextPageToken, files(id, name, mimeType)',
      'pageSize': '1000',
      'key': cleApiDrive,
      'pageToken': ?pageSuivante,
    });
    final http.Response reponse;
    try {
      reponse = await http.get(uri).timeout(const Duration(seconds: 30));
    } catch (_) {
      throw const DriveException('Pas de connexion internet.');
    }
    if (reponse.statusCode != 200) {
      throw DriveException(switch (reponse.statusCode) {
        404 => 'Dossier introuvable. Vérifiez le lien.',
        403
            when reponse.body.contains('accessNotConfigured') ||
                reponse.body.contains('SERVICE_DISABLED') =>
          'L’API Google Drive n’est pas activée pour ce projet.',
        400 || 403 =>
          'Accès refusé par Google Drive : vérifiez que le dossier '
              'est partagé à « Tous les utilisateurs disposant du lien ».',
        _ => 'Erreur Google Drive (${reponse.statusCode}). Réessayez.',
      });
    }
    final json = jsonDecode(reponse.body) as Map<String, dynamic>;
    for (final f in (json['files'] as List? ?? const [])) {
      final m = f as Map<String, dynamic>;
      final nom = m['name'] as String? ?? '';
      if (_estAudio(m['mimeType'] as String? ?? '', nom)) {
        fichiers.add(FichierDrive(m['id'] as String, nom));
      }
    }
    pageSuivante = json['nextPageToken'] as String?;
  } while (pageSuivante != null);
  return fichiers;
}
