import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/paroles.dart';

void main() {
  test('strophes séparées par une ligne vide, numérotées', () {
    expect(decouperParoles('A\nB\n\nC\nD\n\n\nE'), const [
      Strophe('A\nB', numero: 1),
      Strophe('C\nD', numero: 2),
      Strophe('E', numero: 3),
    ]);
  });

  test('refrain reconnu, seul sur sa ligne ou avec « : »', () {
    expect(decouperParoles('Fiverenany\nHaleloia\nAmen'), const [
      Strophe('Haleloia\nAmen', refrain: true),
    ]);
    expect(decouperParoles('Refrain : Gloire à Dieu'), const [
      Strophe('Gloire à Dieu', refrain: true),
    ]);
    expect(decouperParoles('FIV.\nHaleloia'), const [
      Strophe('Haleloia', refrain: true),
    ]);
    expect(decouperParoles('Réf. - Alléluia'), const [
      Strophe('Alléluia', refrain: true),
    ]);
  });

  test('le refrain ne compte pas dans la numérotation des couplets', () {
    final s = decouperParoles('Un\n\nFiv.\nHaleloia\n\nDeux\n\nFiv.');
    expect(s, const [
      Strophe('Un', numero: 1),
      Strophe('Haleloia', refrain: true),
      Strophe('Deux', numero: 2),
      Strophe('', refrain: true),
    ]);
    expect(s.last.repriseRefrain, isTrue);
  });

  test('numéros écrits à la main repris et retirés du texte', () {
    expect(
      decouperParoles('1. Ry Tompo\n\n2) Ny fitiavanao\n\nAndininy 4\nFarany'),
      const [
        Strophe('Ry Tompo', numero: 1),
        Strophe('Ny fitiavanao', numero: 2),
        Strophe('Farany', numero: 4),
      ],
    );
  });

  test('un mot qui commence comme une étiquette n’est pas un refrain', () {
    expect(decouperParoles('Fivavahana sy hira'), const [
      Strophe('Fivavahana sy hira', numero: 1),
    ]);
    expect(decouperParoles('Reformez les rangs'), const [
      Strophe('Reformez les rangs', numero: 1),
    ]);
  });

  test('paroles vides ou retours Windows', () {
    expect(decouperParoles(''), isEmpty);
    expect(decouperParoles('  \n\n '), isEmpty);
    expect(decouperParoles('A\r\n\r\nB'), const [
      Strophe('A', numero: 1),
      Strophe('B', numero: 2),
    ]);
  });
}
