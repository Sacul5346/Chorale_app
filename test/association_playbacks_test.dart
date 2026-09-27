import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/association_playbacks.dart';

void main() {
  group('normaliserNom', () {
    test('fichiers : extension, numéro de piste, accents, ponctuation', () {
      expect(normaliserNom('03 - Ry Tompo ô !.mp3', fichier: true), 'ry tompo o');
      expect(normaliserNom('Fiderana_Anao.M4A', fichier: true), 'fiderana anao');
      expect(normaliserNom('12. Hira   Fisaorana.wav', fichier: true),
          'hira fisaorana');
    });

    test('titres : l’extension n’est pas retirée', () {
      expect(normaliserNom('Salamo 23 v.12'), 'salamo 23 v 12');
      expect(normaliserNom('Ry Tompo Ô'), 'ry tompo o');
    });

    test('un numéro sans séparateur est gardé (ex. numéro de cantique)', () {
      expect(normaliserNom('150 Ry Tompo.mp3', fichier: true), '150 ry tompo');
    });
  });

  test('idDossierDrive', () {
    expect(
      idDossierDrive(
          'https://drive.google.com/drive/folders/1AbCdEfGhIjKlMnOp?usp=sharing'),
      '1AbCdEfGhIjKlMnOp',
    );
    expect(
      idDossierDrive('https://drive.google.com/drive/u/0/folders/1AbCdEfGhIjKlMnOp'),
      '1AbCdEfGhIjKlMnOp',
    );
    expect(idDossierDrive('https://www.youtube.com/watch?v=abc'), isNull);
  });

  group('associer', () {
    final chansons = [
      const ChansonExistante('s1', 'Ry Tompo Ô'),
      const ChansonExistante('s2', 'Fiderana', 'https://drive.google.com/file/d/ancien/view'),
      const ChansonExistante('s3', 'Hira Fisaorana', 'https://drive.google.com/file/d/f3/view'),
      const ChansonExistante('s4', 'Doublon'),
      const ChansonExistante('s5', 'doublon !'),
      const ChansonExistante('s6', 'Sans fichier'),
    ];
    final fichiers = [
      const FichierDrive('f1', '01 - ry tompo o.mp3'),
      const FichierDrive('f2', 'Fiderana.m4a'),
      const FichierDrive('f3', 'Hira fisaorana.mp3'),
      const FichierDrive('f4', 'Doublon.mp3'),
      const FichierDrive('f5', 'Chanson inconnue.mp3'),
    ];
    final r = associer(chansons, fichiers);

    test('relie les fichiers aux chansons du même nom', () {
      final paires = {
        for (final c in r.correspondances) c.chanson.id: c.fichier.id,
      };
      expect(paires, {'s1': 'f1', 's2': 'f2', 's3': 'f3'});
    });

    test('signale remplacement et liens déjà en place', () {
      final parChanson = {for (final c in r.correspondances) c.chanson.id: c};
      expect(parChanson['s1']!.remplace, isFalse);
      expect(parChanson['s2']!.remplace, isTrue);
      expect(parChanson['s3']!.dejaRelie, isTrue);
      expect(parChanson['s3']!.remplace, isFalse);
    });

    test('fichiers sans chanson et noms ambigus', () {
      expect(r.fichiersSansChanson.map((f) => f.nom), ['Chanson inconnue.mp3']);
      expect(r.ambigus, ['Doublon.mp3']);
    });
  });
}
