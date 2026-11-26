import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/messagerie.dart';

void main() {
  final maintenant = DateTime(2026, 11, 26, 15, 30); // un jeudi

  group('libelleJour', () {
    test('aujourd’hui, hier, jour de la semaine', () {
      expect(libelleJour(DateTime(2026, 11, 26, 8), maintenant), 'Aujourd’hui');
      expect(libelleJour(DateTime(2026, 11, 25, 23, 59), maintenant), 'Hier');
      expect(libelleJour(DateTime(2026, 11, 23), maintenant), 'Lundi');
    });

    test('date au-delà d’une semaine, année si différente', () {
      expect(libelleJour(DateTime(2026, 11, 19), maintenant), '19 nov.');
      expect(libelleJour(DateTime(2025, 8, 3), maintenant), '3 août 2025');
    });
  });

  test('heure et date courte', () {
    expect(heure(DateTime(2026, 1, 1, 9, 5)), '09:05');
    expect(dateCourte(DateTime(2026, 11, 26, 7, 2), maintenant), '07:02');
    expect(dateCourte(DateTime(2026, 11, 25, 7, 2), maintenant), 'Hier');
  });

  test('nouveauJour', () {
    expect(nouveauJour(null, maintenant), isTrue);
    expect(
      nouveauJour(DateTime(2026, 11, 26, 1), DateTime(2026, 11, 26, 23)),
      isFalse,
    );
    expect(
      nouveauJour(DateTime(2026, 11, 25, 23), DateTime(2026, 11, 26, 0, 1)),
      isTrue,
    );
  });

  group('statutExcuseAcceptee', () {
    test('absence annoncée ou sans réponse : absent avec excuse', () {
      expect(
        statutExcuseAcceptee(intention: 'absent', statutConstate: ''),
        'absent_excuse',
      );
      expect(
        statutExcuseAcceptee(intention: '', statutConstate: ''),
        'absent_excuse',
      );
    });

    test('retard annoncé : rien, le scan s’en charge', () {
      expect(
        statutExcuseAcceptee(intention: 'retard', statutConstate: ''),
        isNull,
      );
    });

    test('présence déjà constatée : jamais écrasée', () {
      expect(
        statutExcuseAcceptee(
          intention: 'absent',
          statutConstate: 'present_heure',
        ),
        isNull,
      );
    });
  });

  test('libellé de la direction', () {
    expect(libelleDirection('chef'), 'Chef de chorale');
    expect(libelleDirection(null), 'Chef de chorale'); // anciens messages
    expect(libelleDirection('suppleant'), 'Suppléant du chef');
  });

  group('grouperParRepetition', () {
    // (conversation, répétition)
    String rep((String, String) c) => c.$2;
    final reps = {
      'samedi': InfoRepetition(
        'Répétition du Samedi 28/11',
        DateTime(2026, 11, 28),
      ),
      'jeudi': InfoRepetition(
        'Répétition du Jeudi 19/11',
        DateTime(2026, 11, 19),
      ),
      'vieille': const InfoRepetition.supprimee(),
      'autre': const InfoRepetition.supprimee(),
    };

    test('par répétition, la plus récente d’abord ; supprimées à la fin', () {
      final g = grouperParRepetition(
        [
          ('Hugo 1', 'jeudi'),
          ('Lucas', 'vieille'),
          ('Hugo 2', 'samedi'),
          ('sayonah', 'samedi'),
          ('Lucas 2', 'autre'),
        ],
        rep,
        reps,
      );
      expect(g.map((e) => e.repetitionId), ['samedi', 'jeudi', null]);
      expect(g[0].conversations.map((c) => c.$1), ['Hugo 2', 'sayonah']);
      expect(g.last.supprimees, isTrue);
      expect(g.last.conversations.map((c) => c.$1), ['Lucas', 'Lucas 2']);
    });

    test('répétition pas encore chargée : après les datées', () {
      final g = grouperParRepetition(
        [('A', 'inconnue'), ('B', 'jeudi')],
        rep,
        reps,
      );
      expect(g.map((e) => e.repetitionId), ['jeudi', 'inconnue']);
      expect(g.last.info, isNull);
    });

    test('aucune conversation', () {
      expect(grouperParRepetition(<(String, String)>[], rep, reps), isEmpty);
    });
  });

  test('titre de groupe', () {
    expect(
      titreGroupe(DateTime(2026, 11, 28), maintenant),
      'Samedi 28 novembre',
    );
    expect(
      titreGroupe(DateTime(2025, 1, 4), maintenant),
      'Samedi 4 janvier 2025',
    );
  });
}
