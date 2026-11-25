import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/roles.dart';

void main() {
  final maintenant = DateTime(2026, 11, 25, 10);
  Timestamp ts(DateTime d) => Timestamp.fromDate(d);

  group('roleNormalise', () {
    test('garde chef et lyrics_manager', () {
      expect(roleNormalise('chef'), 'chef');
      expect(roleNormalise('lyrics_manager'), 'lyrics_manager');
    });

    test(
      "l'ancien responsable, un rôle inconnu ou absent deviennent membre",
      () {
        expect(roleNormalise('responsable'), 'membre');
        expect(roleNormalise('admin'), 'membre');
        expect(roleNormalise(null), 'membre');
        expect(roleNormalise(42), 'membre');
      },
    );
  });

  group('estSuppleant', () {
    test('vrai avant la date de fin', () {
      final fiche = {
        'role': 'membre',
        champSuppleance: ts(DateTime(2026, 11, 30)),
      };
      expect(estSuppleant(fiche, maintenant), isTrue);
    });

    test('faux une fois la date de fin passée', () {
      final fiche = {
        'role': 'membre',
        champSuppleance: ts(DateTime(2026, 11, 25, 9)),
      };
      expect(estSuppleant(fiche, maintenant), isFalse);
    });

    test('faux sans date de suppléance', () {
      expect(estSuppleant({'role': 'membre'}, maintenant), isFalse);
      expect(
        estSuppleant({'role': 'membre', champSuppleance: 'demain'}, maintenant),
        isFalse,
      );
    });

    test('faux pour un compte désactivé', () {
      final fiche = {
        'role': 'membre',
        'actif': false,
        champSuppleance: ts(DateTime(2026, 12, 1)),
      };
      expect(estSuppleant(fiche, maintenant), isFalse);
    });

    test('un ancien responsable peut être suppléant', () {
      final fiche = {
        'role': 'responsable',
        champSuppleance: ts(DateTime(2026, 12, 1)),
      };
      expect(estSuppleant(fiche, maintenant), isTrue);
    });

    test("le chef n'est jamais « suppléant »", () {
      final fiche = {
        'role': 'chef',
        champSuppleance: ts(DateTime(2026, 12, 1)),
      };
      expect(estSuppleant(fiche, maintenant), isFalse);
    });
  });

  test('finPourDernierJour : pouvoirs toute la journée choisie', () {
    final fin = finPourDernierJour(DateTime(2026, 11, 30, 15, 42));
    expect(fin, DateTime(2026, 12, 1));
    expect(
      estSuppleant({champSuppleance: ts(fin)}, DateTime(2026, 11, 30, 23, 59)),
      isTrue,
    );
    expect(
      estSuppleant({champSuppleance: ts(fin)}, DateTime(2026, 12, 1)),
      isFalse,
    );
  });

  test('finPourDernierJour passe au mois suivant', () {
    expect(finPourDernierJour(DateTime(2026, 12, 31)), DateTime(2027, 1, 1));
  });
}
