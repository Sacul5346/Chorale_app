import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/badge.dart';

void main() {
  test('QR code : identifiant du membre, sans donnée personnelle', () {
    expect(contenuQrMembre('abc123'), 'KTKFA:MEMBRE:abc123');
  });

  group('libelleBadge', () {
    test('voix en clair', () {
      expect(libelleBadge(role: 'membre', voix: 'soprano'), 'Soprano');
      expect(libelleBadge(role: 'membre', voix: 'tenor'), 'Ténor');
      expect(libelleBadge(role: 'lyrics_manager', voix: 'basse'), 'Basse');
    });

    test('le chef est « Chef de chorale », quelle que soit sa voix', () {
      expect(libelleBadge(role: 'chef', voix: 'alto'), 'Chef de chorale');
    });

    test('voix absente ou inconnue : rien', () {
      expect(libelleBadge(role: 'membre', voix: null), '');
      expect(libelleBadge(role: 'membre', voix: 'baryton'), '');
    });
  });

  test('couleur par voix, or pour le chef', () {
    expect(couleurVoix(role: 'membre', voix: 'soprano'), 0xFFD6457A);
    expect(couleurVoix(role: 'membre', voix: 'tenor'), 0xFF2F7FD1);
    expect(couleurVoix(role: 'chef', voix: 'tenor'), 0xFFC9A227);
    expect(couleurVoix(role: 'membre', voix: null), 0xFF8C77A8);
  });

  test('decouperNom : nom d’abord, puis les prénoms', () {
    expect(decouperNom('RAKOTO Jean Paul'), (
      nom: 'RAKOTO',
      prenoms: 'Jean Paul',
    ));
    expect(decouperNom('  Rasoa   Hanitra '), (
      nom: 'Rasoa',
      prenoms: 'Hanitra',
    ));
    expect(decouperNom('Lova'), (nom: 'Lova', prenoms: ''));
  });

  test('photo : décodée si valide, initiales sinon', () {
    expect(
      BadgeMembre.depuisFiche('u', {'Nom': 'A B', 'photoBase64': 'AAEC'}).photo,
      [0, 1, 2],
    );
    final abimee = BadgeMembre.depuisFiche('u', {
      'Nom': 'Rakoto Jean',
      'photoBase64': '%%pas du base64%%',
    });
    expect(abimee.photo, isNull);
    expect(abimee.initiales, 'RJ');
  });

  test('BadgeMembre.depuisFiche : nom nettoyé, « Sans nom » si vide', () {
    final b = BadgeMembre.depuisFiche('u1', {
      'Nom': '  Rakoto Jean  ',
      'role': 'membre',
      'voix': 'alto',
    });
    expect(b.nom, 'Rakoto Jean');
    expect(b.libelle, 'Alto');
    expect(BadgeMembre.depuisFiche('u2', {'Nom': ' '}).nom, 'Sans nom');
  });

  test('PDF : 8 badges par page A4, logo intégré une seule fois', () async {
    final logo = File(RessourcesBadge.chemins.logo).readAsBytesSync();
    final ressources = RessourcesBadge(
      logo: logo,
      policeNormale: File(RessourcesBadge.chemins.normale).readAsBytesSync(),
      policeGrasse: File(RessourcesBadge.chemins.grasse).readAsBytesSync(),
    );
    final membres = [
      for (var i = 0; i < 9; i++)
        BadgeMembre(uid: 'u$i', nom: 'Membre $i', libelle: 'Soprano'),
    ];
    final pdf = await genererBadges(membres, ressources);
    final texte = latin1.decode(pdf);

    expect(texte.startsWith('%PDF'), isTrue);
    // 9 badges -> 2 pages.
    expect(RegExp(r'/Type\s*/Page\b').allMatches(texte).length, 2);
    // Le logo (77 Ko) n'est pas recopié dans chaque badge, et les polices
    // n'embarquent que les caractères utilisés.
    expect(pdf.length, lessThan(logo.length * 2));

    final sortie = Platform.environment['BADGE_PDF'];
    if (sortie != null) File(sortie).writeAsBytesSync(pdf);
  });
}
