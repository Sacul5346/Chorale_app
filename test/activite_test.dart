import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/activite.dart';

void main() {
  final r1 = RepetitionPassee('r1', DateTime(2026, 9, 3), 'Jeudi 3');
  final r2 = RepetitionPassee('r2', DateTime(2026, 9, 5), 'Samedi 5');
  final r3 = RepetitionPassee('r3', DateTime(2026, 9, 10), 'Jeudi 10');

  final presences = [
    // Ana : à l'heure ×2 (dont 1 réponse à l'avance), retard excusé → 3+1+3+2 = 9
    {'repetitionId': 'r1', 'userId': 'ana', 'statut': 'present_heure',
     'intention': 'present', 'intentionAt': DateTime(2026, 9, 2)},
    {'repetitionId': 'r2', 'userId': 'ana', 'statut': 'present_heure'},
    {'repetitionId': 'r3', 'userId': 'ana', 'statut': 'present_retard_excuse'},
    // Bob : à l'heure ×3 → 9, mais aucune réponse à l'avance
    {'repetitionId': 'r1', 'userId': 'bob', 'statut': 'present_heure'},
    {'repetitionId': 'r2', 'userId': 'bob', 'statut': 'present_heure'},
    {'repetitionId': 'r3', 'userId': 'bob', 'statut': 'present_heure'},
    // Cléo : réponse donnée APRÈS la répétition (pas de bonus), absente sans excuse
    {'repetitionId': 'r1', 'userId': 'cleo', 'statut': 'absent_sans_excuse',
     'intention': 'absent', 'intentionAt': DateTime(2026, 9, 6)},
    // Dan : ancien format (intention rangée dans statut) → non marqué + bonus
    {'repetitionId': 'r2', 'userId': 'dan', 'statut': 'present'},
  ];

  final activite = calculerActivite(
    repetitions: [r1, r2, r3],
    membreIds: ['ana', 'bob', 'cleo', 'dan', 'eve'],
    presences: presences,
  );

  test('points par membre', () {
    expect(activite['ana']!.points, 9);
    expect(activite['bob']!.points, 9);
    expect(activite['cleo']!.points, -1);
    expect(activite['dan']!.points, 1); // bonus seul
    expect(activite['eve']!.points, 0);
    expect(activite['ana']!.reponsesALavance, 1);
  });

  test('départage : à égalité de points, plus de présences à l’heure', () {
    final g = gagnants([activite['ana']!, activite['bob']!]);
    expect(g.map((a) => a.userId), ['bob']);
  });

  test('ex æquo parfaits : tous gagnants ; personne sans point', () {
    final memes = calculerActivite(
      repetitions: [r1],
      membreIds: ['x', 'y'],
      presences: [
        {'repetitionId': 'r1', 'userId': 'x', 'statut': 'present_heure'},
        {'repetitionId': 'r1', 'userId': 'y', 'statut': 'present_heure'},
      ],
    );
    expect(gagnants(memes.values).map((a) => a.userId).toSet(), {'x', 'y'});
    expect(gagnants([activite['eve']!, activite['cleo']!]), isEmpty);
  });

  test('barème personnalisé', () {
    expect(
      pointsPresence('present_heure', true,
          {'present_heure': 5, 'reponse_a_lavance': 2}),
      7,
    );
    expect(pointsPresence('present_retard', false, {'present_retard_excuse': 2}), 2);
  });

  test('genre proposé selon la voix, et mois', () {
    expect(genreSelonVoix('alto'), 'femme');
    expect(genreSelonVoix('basse'), 'homme');
    expect(genreSelonVoix(null), isNull);
    expect(cleMois(DateTime(2026, 9, 27)), '2026-09');
    expect(libelleMois(DateTime(2026, 8, 1)), 'août 2026');
  });
}
