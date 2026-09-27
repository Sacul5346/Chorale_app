import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/statistiques.dart';

void main() {
  final presences = [
    {'repetitionId': 'r1', 'userId': 'ana', 'statut': 'present_heure'},
    {'repetitionId': 'r2', 'userId': 'ana', 'statut': 'present_retard_sans_excuse'},
    {'repetitionId': 'r3', 'userId': 'ana', 'statut': 'absent_excuse'},
    {'repetitionId': 'r1', 'userId': 'bob', 'statut': 'absent_sans_excuse'},
    // Ancien format : intention du membre rangée dans `statut` → non marquée.
    {'repetitionId': 'r2', 'userId': 'bob', 'statut': 'present'},
    // Répétition hors période : ignorée.
    {'repetitionId': 'autre', 'userId': 'bob', 'statut': 'present_heure'},
  ];

  final parMembre = statsParMembre(
    repetitionIds: ['r1', 'r2', 'r3'],
    membreIds: ['ana', 'bob', 'cleo'],
    presences: presences,
  );

  test('compte chaque répétition de la période pour chaque membre', () {
    final ana = parMembre['ana']!;
    expect(ana.aLHeure, 1);
    expect(ana.retardsSansExcuse, 1);
    expect(ana.absencesExcusees, 1);
    expect(ana.taux, closeTo(2 / 3, 1e-9));

    final bob = parMembre['bob']!;
    expect(bob.absencesSansExcuse, 1);
    expect(bob.nonMarquees, 2);
    expect(bob.taux, 0);
  });

  test('taux inconnu si rien n\'est marqué', () {
    expect(parMembre['cleo']!.nonMarquees, 3);
    expect(parMembre['cleo']!.taux, isNull);
  });

  test('cumul par voix', () {
    final parVoix = statsParVoix(parMembre, {'ana': 'alto', 'bob': 'alto'});
    expect(parVoix['alto']!.presences, 2);
    expect(parVoix['alto']!.absences, 2);
    expect(parVoix['non_definie']!.nonMarquees, 3); // cleo, sans voix
  });
}
