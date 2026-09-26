import 'package:flutter_test/flutter_test.dart';

import 'package:chorale_app/repetition_model.dart';
import 'package:chorale_app/repetitions_screen.dart';

void main() {
  test('dateSansHeure ramène la date à minuit', () {
    expect(dateSansHeure(DateTime(2026, 9, 26, 18, 30)), DateTime(2026, 9, 26));
  });

  group('repetitionsDuMois', () {
    test('s\'arrête à la fin du mois, pas 30 jours plus tard', () {
      // Samedi 26 septembre 2026 → sam. 26, dim. 27 (et pas d'octobre).
      final reps = RepetitionsScreen.repetitionsDuMois(
          DateTime(2026, 9, 26, 15, 42));
      final dates = reps.map((r) => r['date'] as DateTime).toList();

      expect(dates, [DateTime(2026, 9, 26), DateTime(2026, 9, 27)]);
      expect(reps.map((r) => r['jour']), ['Samedi', 'Dimanche']);
    });

    test('mois complet : jeudis, samedis et dimanches, à minuit', () {
      final reps = RepetitionsScreen.repetitionsDuMois(DateTime(2026, 10, 1));
      final dates = reps.map((r) => r['date'] as DateTime).toList();

      // Octobre 2026 : 5 jeudis, 5 samedis, 4 dimanches.
      expect(dates.length, 14);
      expect(dates.first, DateTime(2026, 10, 1)); // jeudi
      expect(dates.last, DateTime(2026, 10, 31)); // samedi
      expect(dates.every((d) => d.month == 10 && d.hour == 0), isTrue);
      // Les dimanches sont à confirmer.
      expect(
        reps
            .where((r) => r['jour'] == 'Dimanche')
            .every((r) => r['confirmed'] == false),
        isTrue,
      );
    });
  });
}
