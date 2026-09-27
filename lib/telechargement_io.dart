import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Téléchargement des playbacks dans l'espace **privé** de l'app sur le
/// téléphone : invisibles pour la Galerie, la Musique ou les Fichiers, et
/// lisibles uniquement par l'app Chorale. Supprimés avec l'app, par le
/// membre, ou automatiquement si son compte est désactivé.

const bool telechargementPossible = true;

Future<Directory> _dossier() async =>
    Directory('${(await getApplicationDocumentsDirectory()).path}/playbacks');

Future<File> _fichier(String idDrive) async {
  final dossier = await _dossier();
  await dossier.create(recursive: true);
  return File('${dossier.path}/$idDrive.audio');
}

/// Efface tous les playbacks téléchargés (compte désactivé ou introuvable).
Future<void> supprimerTout() async {
  final dossier = await _dossier();
  if (await dossier.exists()) await dossier.delete(recursive: true);
}

/// Chemin du playback s'il est déjà sur le téléphone, sinon `null`.
Future<String?> cheminLocal(String idDrive) async {
  final fichier = await _fichier(idDrive);
  return await fichier.exists() ? fichier.path : null;
}

/// Télécharge [url] et renvoie le chemin du fichier.
/// [progression] reçoit une valeur entre 0 et 1 (ou `null` si la taille
/// est inconnue). [annule] est consulté pendant le téléchargement.
Future<String> telecharger(
  String url,
  String idDrive, {
  required void Function(double? progression) progression,
  required bool Function() annule,
}) async {
  final fichier = await _fichier(idDrive);
  // Fichier provisoire : un téléchargement interrompu ne doit jamais
  // passer pour un playback complet.
  final provisoire = File('${fichier.path}.part');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final requete = await client.getUrl(
      Uri.parse(url),
    ); // suit les redirections
    final reponse = await requete.close();
    if (reponse.statusCode != 200) {
      throw const TelechargementException(
        'Fichier introuvable. Vérifiez que le playback est partagé à '
        '« Tous les utilisateurs disposant du lien ».',
      );
    }
    // Drive renvoie une page web (et non le son) si le fichier est privé
    // ou trop volumineux.
    if (reponse.headers.contentType?.mimeType == 'text/html') {
      throw const TelechargementException(
        'Google Drive refuse le téléchargement : le fichier n’est pas '
        'partagé publiquement, ou il est trop volumineux.',
      );
    }

    final total = reponse.contentLength;
    var recu = 0;
    final sortie = provisoire.openWrite();
    try {
      await for (final morceau in reponse) {
        if (annule()) throw const TelechargementAnnule();
        sortie.add(morceau);
        recu += morceau.length;
        progression(total > 0 ? recu / total : null);
      }
    } finally {
      await sortie.close();
    }
    await provisoire.rename(fichier.path);
    return fichier.path;
  } on SocketException {
    throw const TelechargementException('Pas de connexion internet.');
  } on HttpException {
    throw const TelechargementException(
      'Le téléchargement a été interrompu. Réessayez.',
    );
  } finally {
    client.close(force: true);
    if (await provisoire.exists()) await provisoire.delete();
  }
}

Future<void> supprimer(String idDrive) async {
  final fichier = await _fichier(idDrive);
  if (await fichier.exists()) await fichier.delete();
}

class TelechargementException implements Exception {
  final String message;
  const TelechargementException(this.message);
}

class TelechargementAnnule implements Exception {
  const TelechargementAnnule();
}
