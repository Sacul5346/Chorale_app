import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/anniversaires.dart';
import 'package:chorale_app/rappels.dart';
import 'package:chorale_app/versets.dart';

void main() {
  group('anniversaires', () {
    const hery = Anniversaire('hery', 'Hery', 3, 10);
    const noro = Anniversaire('noro', 'Noro', 27, 9);
    const fara = Anniversaire('fara', 'Fara', 29, 2);

    test('prochaine date : cette année, ou l’an prochain si passée', () {
      final aujourdhui = DateTime(2026, 9, 27, 15);
      expect(prochaineDate(hery, aujourdhui), DateTime(2026, 10, 3));
      expect(prochaineDate(noro, aujourdhui), DateTime(2026, 9, 27));
      expect(prochaineDate(const Anniversaire('x', 'X', 1, 1), aujourdhui),
          DateTime(2027, 1, 1));
    });

    test('29 février fêté le 28 les années non bissextiles', () {
      expect(prochaineDate(fara, DateTime(2027, 1, 10)), DateTime(2027, 2, 28));
      expect(prochaineDate(fara, DateTime(2028, 1, 10)), DateTime(2028, 2, 29));
    });

    test('du jour et à venir, triés', () {
      final aujourdhui = DateTime(2026, 9, 27);
      expect(anniversairesDuJour([hery, noro], aujourdhui).map((a) => a.nom),
          ['Noro']);
      expect(
        anniversairesAVenir([hery, fara, noro], aujourdhui).map((e) => e.$1.nom),
        ['Noro', 'Hery', 'Fara'],
      );
    });

    test('ignore les comptes désactivés et les dates invalides', () {
      expect(Anniversaire.depuisDoc('a', {'nom': 'A', 'jour': 3, 'mois': 10}),
          isNotNull);
      expect(
          Anniversaire.depuisDoc(
              'a', {'nom': 'A', 'jour': 3, 'mois': 10, 'actif': false}),
          isNull);
      expect(Anniversaire.depuisDoc('a', {'jour': 3, 'mois': 13}), isNull);
    });

    test('notifications : le jour J à 8h, message personnel pour soi', () {
      final maintenant = DateTime.utc(2026, 9, 27, 3); // 6h à Madagascar
      final notifs = anniversairesAProgrammer(
        [hery, noro],
        maintenant,
        monUid: 'hery',
      );
      expect(notifs, hasLength(2));
      final pourNoro = notifs.firstWhere((n) => n.id == idAnniversaire('noro'));
      expect(pourNoro.quand.toUtc(), DateTime.utc(2026, 9, 27, 5)); // 8h EAT
      expect(pourNoro.corps, contains('anniversaire de Noro'));
      final pourMoi = notifs.firstWhere((n) => n.id == idAnniversaire('hery'));
      expect(pourMoi.titre, contains('Joyeux anniversaire, Hery'));
    });
  });

  group('verset du jour', () {
    test('même verset toute la journée, différent le lendemain', () {
      expect(versetDuJour(DateTime(2026, 9, 27, 7)).reference,
          versetDuJour(DateTime(2026, 9, 27, 22)).reference);
      expect(versetDuJour(DateTime(2026, 9, 27)).reference,
          isNot(versetDuJour(DateTime(2026, 9, 28)).reference));
    });

    test('tous les versets passent en rotation', () {
      final refs = {
        for (var i = 0; i < versets.length; i++)
          versetDuJour(DateTime(2026, 1, 1 + i)).reference,
      };
      expect(refs, hasLength(versets.length));
    });

    test('notifications programmées chaque matin, pas dans le passé', () {
      // 10h à Madagascar : le verset de 6h aujourd'hui est déjà passé.
      final notifs = versetsAProgrammer(
        DateTime.utc(2026, 9, 27, 7),
        heure: 6,
        jours: 3,
      );
      expect(notifs.map((n) => n.quand.day), [28, 29, 30]);
      expect(notifs.first.quand.hour, 6);
      expect(notifs.map((n) => n.id).toSet(), hasLength(3));
    });
  });
}
