import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/association_playbacks.dart' show idDossierDrive;
import 'package:chorale_app/parametres.dart';

void main() {
  const lien =
      'https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOp?usp=sharing';

  group('dossier des playbacks', () {
    test('vide par défaut (anciens paramètres)', () {
      expect(ParametresChorale.depuisMap(null).dossierPlaybacks, '');
      expect(ParametresChorale.depuisMap({}).dossierPlaybacks, '');
      expect(
        ParametresChorale.depuisMap({'dossierPlaybacks': 42}).dossierPlaybacks,
        '',
      );
    });

    test('enregistré puis relu à l’identique', () {
      final p = ParametresChorale.defaut.copie(dossierPlaybacks: lien);
      final relu = ParametresChorale.depuisMap(p.versMap());
      expect(relu.dossierPlaybacks, lien);
      // Les autres réglages ne bougent pas.
      expect(relu.heureRappel, ParametresChorale.defaut.heureRappel);
    });

    test('espaces autour du lien retirés', () {
      expect(
        ParametresChorale.depuisMap({
          'dossierPlaybacks': '  $lien \n',
        }).dossierPlaybacks,
        lien,
      );
    });

    test('lien de dossier reconnu, lien de fichier refusé', () {
      expect(idDossierDrive(lien), '1AbCdEfGhIjKlMnOp');
      expect(
        idDossierDrive('https://drive.google.com/file/d/1XyZabcdefghij/view'),
        isNull,
      );
    });
  });
}
