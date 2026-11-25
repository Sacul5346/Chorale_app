import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/badge.dart';
import 'package:chorale_app/parametres.dart';
import 'package:chorale_app/pointage.dart';

void main() {
  group('membreDepuisQr', () {
    test('lit le badge produit par badge.dart', () {
      expect(membreDepuisQr(contenuQrMembre('Ab12_xY-9')), 'Ab12_xY-9');
      expect(membreDepuisQr('  KTKFA:MEMBRE:abc \n'), 'abc');
    });

    test('refuse tout autre code', () {
      expect(membreDepuisQr(null), isNull);
      expect(membreDepuisQr(''), isNull);
      expect(membreDepuisQr('https://exemple.com'), isNull);
      expect(membreDepuisQr('KTKFA:MEMBRE:'), isNull);
      expect(membreDepuisQr('KTKFA:MEMBRE:a/b'), isNull);
      expect(membreDepuisQr('ktkfa:membre:abc'), isNull);
    });
  });

  group('lireHeure', () {
    test('formats courants', () {
      expect(lireHeure('18h00'), (heure: 18, minute: 0));
      expect(lireHeure('14h'), (heure: 14, minute: 0));
      expect(lireHeure('14H30'), (heure: 14, minute: 30));
      expect(lireHeure('18:45'), (heure: 18, minute: 45));
      expect(lireHeure('9 h 15'), (heure: 9, minute: 15));
      expect(lireHeure('Vers 15h30'), (heure: 15, minute: 30));
    });

    test('illisible', () {
      expect(lireHeure(''), isNull);
      expect(lireHeure('à confirmer'), isNull);
      expect(lireHeure('18'), isNull);
      expect(lireHeure('25h00'), isNull);
    });
  });

  test('debutRepetition : date à minuit + heure texte', () {
    expect(
      debutRepetition(DateTime(2026, 11, 28), '14h30'),
      DateTime(2026, 11, 28, 14, 30),
    );
    expect(debutRepetition(DateTime(2026, 11, 28), 'à confirmer'), isNull);
  });

  group('statutAuScan', () {
    final debut = DateTime(2026, 11, 28, 14);
    String statut(
      DateTime scan, {
      String intention = 'present',
      bool excuse = false,
      DateTime? debutRep,
      bool sansDebut = false,
    }) => statutAuScan(
      debut: sansDebut ? null : (debutRep ?? debut),
      scan: scan,
      toleranceMinutes: 15,
      intention: intention,
      excuseEnvoyee: excuse,
    );

    test('à l’heure jusqu’à la fin de la tolérance incluse', () {
      expect(statut(DateTime(2026, 11, 28, 13, 40)), 'present_heure');
      expect(statut(DateTime(2026, 11, 28, 14, 15)), 'present_heure');
    });

    test('en retard sans excuse après la tolérance', () {
      expect(
        statut(DateTime(2026, 11, 28, 14, 15, 1)),
        'present_retard_sans_excuse',
      );
    });

    test('en retard avec excuse s’il avait prévenu', () {
      final tard = DateTime(2026, 11, 28, 14, 40);
      expect(statut(tard, intention: 'retard'), 'present_retard_excuse');
      expect(statut(tard, intention: 'absent'), 'present_retard_excuse');
      expect(statut(tard, excuse: true), 'present_retard_excuse');
    });

    test('heure inconnue : à l’heure (le chef corrige)', () {
      expect(
        statut(DateTime(2026, 11, 28, 20), sansDebut: true),
        'present_heure',
      );
    });

    test('tolérance nulle', () {
      expect(
        statutAuScan(
          debut: debut,
          scan: debut.add(const Duration(minutes: 1)),
          toleranceMinutes: 0,
          intention: '',
          excuseEnvoyee: false,
        ),
        'present_retard_sans_excuse',
      );
    });
  });

  test('statutAbsent : excusé s’il avait prévenu', () {
    expect(
      statutAbsent(intention: 'absent', excuseEnvoyee: false),
      'absent_excuse',
    );
    expect(statutAbsent(intention: '', excuseEnvoyee: true), 'absent_excuse');
    expect(
      statutAbsent(intention: 'present', excuseEnvoyee: false),
      'absent_sans_excuse',
    );
    expect(
      statutAbsent(intention: '', excuseEnvoyee: false),
      'absent_sans_excuse',
    );
  });

  test('lecture d’un document presences, ancien format compris', () {
    expect(intentionDe({'intention': 'retard'}), 'retard');
    expect(intentionDe({'statut': 'absent'}), 'absent'); // app 1.0.0
    expect(statutConstateDe({'statut': 'absent'}), '');
    expect(statutConstateDe({'statut': 'present_heure'}), 'present_heure');
    expect(estPresent('present_retard_excuse'), isTrue);
    expect(estPresent('absent_excuse'), isFalse);
    expect(estPresent(''), isFalse);
  });

  group('tolérance dans les paramètres', () {
    test('15 min par défaut, valeur enregistrée relue', () {
      expect(ParametresChorale.depuisMap(null).toleranceRetard, 15);
      expect(ParametresChorale.depuisMap({}).toleranceRetard, 15);
      final p = ParametresChorale.depuisMap({'toleranceRetard': 30});
      expect(p.toleranceRetard, 30);
      expect(ParametresChorale.depuisMap(p.versMap()).toleranceRetard, 30);
    });

    test('valeur hors liste ignorée', () {
      expect(
        ParametresChorale.depuisMap({'toleranceRetard': 7}).toleranceRetard,
        15,
      );
      expect(
        ParametresChorale.depuisMap({'toleranceRetard': '15'}).toleranceRetard,
        15,
      );
    });
  });
}
