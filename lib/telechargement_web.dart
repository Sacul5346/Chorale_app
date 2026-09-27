/// Version navigateur : impossible d'enregistrer des fichiers, le playback
/// est lu directement depuis Google Drive (voir playback.dart).
library;

const bool telechargementPossible = false;

Future<String?> cheminLocal(String idDrive) async => null;

Future<String> telecharger(
  String url,
  String idDrive, {
  required void Function(double? progression) progression,
  required bool Function() annule,
}) => throw UnsupportedError('Téléchargement impossible dans le navigateur');

Future<void> supprimer(String idDrive) async {}

Future<void> supprimerTout() async {}

class TelechargementException implements Exception {
  final String message;
  const TelechargementException(this.message);
}

class TelechargementAnnule implements Exception {
  const TelechargementAnnule();
}
