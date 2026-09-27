import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/rappels.dart';
import 'package:chorale_app/repetition_model.dart';

Repetition rep(String id, DateTime date, {String statut = 'actif'}) =>
    Repetition(
      id: id,
      titre: 'Répétition $id',
      date: date,
      heure: '18h00',
      lieu: 'Église',
      chefId: 'chef',
      statut: statut,
      chansons: '',
      raison: '',
      causeAnnulation: statut == 'annulé' ? 'Pluie' : '',
    );

void main() {
  test('identifiants stables et distincts', () {
    expect(idRappel('abc'), idRappel('abc'));
    expect(idRappel('abc'), isNot(idRappel('abd')));
    expect(idAnnulation('abc'), isNot(idRappel('abc')));
    expect(idAnnulation('abc'), lessThan(1 << 31));
  });

  group('rappelsAProgrammer', () {
    // Samedi 26/09/2026 à 10h, heure de Madagascar (07h UTC).
    final maintenant = DateTime.utc(2026, 9, 26, 7);

    test('la veille à 18h, heure de Madagascar', () {
      final rappels =
          rappelsAProgrammer([rep('a', DateTime(2026, 10, 1))], maintenant);
      expect(rappels, hasLength(1));
      final r = rappels.single;
      expect(r.quand.toUtc(), DateTime.utc(2026, 9, 30, 15)); // 18h EAT
      expect(r.corps, contains('Demain à 18h00 — Église'));
    });

    test('ignore les annulées et les rappels déjà passés', () {
      final rappels = rappelsAProgrammer([
        rep('annulee', DateTime(2026, 10, 3), statut: 'annulé'),
        rep('aujourdhui', DateTime(2026, 9, 26)), // rappel hier
        rep('demain', DateTime(2026, 9, 27)), // rappel ce soir : gardé
      ], maintenant);
      expect(rappels.map((r) => r.id), [idRappel('demain')]);
    });
  });

  test('annulations à signaler : à venir et pas encore signalées', () {
    final maintenant = DateTime(2026, 9, 26, 10);
    final reps = [
      rep('passee', DateTime(2026, 9, 20), statut: 'annulé'),
      rep('deja', DateTime(2026, 10, 1), statut: 'annulé'),
      rep('nouvelle', DateTime(2026, 10, 2), statut: 'annulé'),
      rep('active', DateTime(2026, 10, 3)),
    ];
    expect(
      annulationsASignaler(reps, {'deja'}, maintenant).map((r) => r.id),
      ['nouvelle'],
    );
  });

  test('heure du rappel réglable', () {
    final r = rappelsAProgrammer(
      [rep('a', DateTime(2026, 10, 1))],
      DateTime.utc(2026, 9, 26, 7),
      heure: 7,
    ).single;
    expect(r.quand.toUtc(), DateTime.utc(2026, 9, 30, 4)); // 7h EAT
  });
}
