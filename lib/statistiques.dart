/// Calcul des statistiques de présence (sans Firestore, pour être testable).
///
/// Seule la présence **constatée par le responsable** (`statut`) compte ;
/// l'intention annoncée par le membre n'entre pas dans les statistiques.
library;

class StatPresence {
  int aLHeure = 0;
  int retardsExcuses = 0;
  int retardsSansExcuse = 0;
  int absencesExcusees = 0;
  int absencesSansExcuse = 0;

  /// Répétitions passées où le responsable n'a rien marqué.
  int nonMarquees = 0;

  int get retards => retardsExcuses + retardsSansExcuse;
  int get presences => aLHeure + retards;
  int get absences => absencesExcusees + absencesSansExcuse;
  int get marquees => presences + absences;

  /// Part des répétitions marquées où la personne était là (retards compris).
  /// `null` si rien n'a encore été marqué.
  double? get taux => marquees == 0 ? null : presences / marquees;

  void ajouter(String statut) {
    switch (statut) {
      case 'present_heure':
        aLHeure++;
      // `present_retard` : ancien statut, sans précision sur l'excuse.
      case 'present_retard':
      case 'present_retard_excuse':
        retardsExcuses++;
      case 'present_retard_sans_excuse':
        retardsSansExcuse++;
      case 'absent_excuse':
        absencesExcusees++;
      case 'absent_sans_excuse':
        absencesSansExcuse++;
      default:
        nonMarquees++;
    }
  }

  void cumuler(StatPresence autre) {
    aLHeure += autre.aLHeure;
    retardsExcuses += autre.retardsExcuses;
    retardsSansExcuse += autre.retardsSansExcuse;
    absencesExcusees += autre.absencesExcusees;
    absencesSansExcuse += autre.absencesSansExcuse;
    nonMarquees += autre.nonMarquees;
  }
}

/// Statistiques par membre.
///
/// [repetitionIds] : répétitions de la période (passées, non annulées).
/// [membreIds] : membres à compter.
/// [presences] : documents `presences` (champs `userId`, `repetitionId`, `statut`).
Map<String, StatPresence> statsParMembre({
  required Iterable<String> repetitionIds,
  required Iterable<String> membreIds,
  required Iterable<Map<String, dynamic>> presences,
}) {
  final statutDe = <String, String>{};
  for (final p in presences) {
    final statut = p['statut'];
    if (statut is String) {
      statutDe['${p['repetitionId']}|${p['userId']}'] = statut;
    }
  }

  return {
    for (final membre in membreIds)
      membre: () {
        final stat = StatPresence();
        for (final rep in repetitionIds) {
          stat.ajouter(statutDe['$rep|$membre'] ?? '');
        }
        return stat;
      }(),
  };
}

/// Cumule les statistiques des membres par voix.
Map<String, StatPresence> statsParVoix(
  Map<String, StatPresence> parMembre,
  Map<String, String> voixDe,
) {
  final resultat = <String, StatPresence>{};
  parMembre.forEach((membre, stat) {
    final voix = voixDe[membre] ?? 'non_definie';
    resultat.putIfAbsent(voix, StatPresence.new).cumuler(stat);
  });
  return resultat;
}
