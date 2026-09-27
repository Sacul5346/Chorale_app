/// Points d'activité et classement des membres du mois (sans Firestore,
/// pour être testable). Le barème vient des Paramètres de la chorale.
library;

import 'parametres.dart';

const _intentions = ['present', 'absent', 'retard'];

class RepetitionPassee {
  final String id;
  final DateTime date;
  final String titre;
  const RepetitionPassee(this.id, this.date, this.titre);
}

/// Une répétition dans l'historique d'un membre.
class LigneActivite {
  final RepetitionPassee repetition;

  /// Présence constatée par le responsable ('' si non marquée).
  final String statut;
  final bool reponduALavance;
  final int points;

  const LigneActivite(
    this.repetition,
    this.statut,
    this.reponduALavance,
    this.points,
  );
}

class ActiviteMembre {
  final String userId;
  final List<LigneActivite> lignes;

  const ActiviteMembre(this.userId, this.lignes);

  int get points => lignes.fold(0, (t, l) => t + l.points);
  int get aLHeure => lignes.where((l) => l.statut == 'present_heure').length;
  int get presences =>
      lignes.where((l) => l.statut.startsWith('present')).length;
  int get absencesSansExcuse =>
      lignes.where((l) => l.statut == 'absent_sans_excuse').length;
  int get reponsesALavance => lignes.where((l) => l.reponduALavance).length;
}

/// Points d'une présence : statut constaté + bonus « répondu à l'avance ».
int pointsPresence(
  String statut,
  bool reponduALavance,
  Map<String, int> bareme,
) {
  // `present_retard` : ancien statut sans précision → retard excusé.
  final cle = statut == 'present_retard' ? 'present_retard_excuse' : statut;
  return (bareme[cle] ?? 0) +
      (reponduALavance ? bareme['reponse_a_lavance'] ?? 0 : 0);
}

/// Le membre a-t-il donné sa réponse dans l'app avant la fin du jour de la
/// répétition ? [intentionAt] absent (anciennes fiches) : on l'accepte.
bool aReponduALavance(Map<String, dynamic> presence, DateTime dateRepetition) {
  final intention =
      presence['intention'] ??
      (_intentions.contains(presence['statut']) ? presence['statut'] : null);
  if (intention is! String || !_intentions.contains(intention)) return false;
  final quand = presence['intentionAt'];
  if (quand is! DateTime) return true;
  final finDuJour = DateTime(
    dateRepetition.year,
    dateRepetition.month,
    dateRepetition.day + 1,
  );
  return quand.isBefore(finDuJour);
}

/// Activité de chaque membre sur les [repetitions] données.
/// [presences] : documents `presences`, avec `intentionAt` converti en
/// DateTime (voir l'appelant).
Map<String, ActiviteMembre> calculerActivite({
  required List<RepetitionPassee> repetitions,
  required Iterable<String> membreIds,
  required Iterable<Map<String, dynamic>> presences,
  Map<String, int> bareme = baremeParDefaut,
}) {
  final presenceDe = <String, Map<String, dynamic>>{};
  for (final p in presences) {
    presenceDe['${p['repetitionId']}|${p['userId']}'] = p;
  }
  return {
    for (final membre in membreIds)
      membre: ActiviteMembre(membre, [
        for (final rep in repetitions)
          () {
            final p = presenceDe['${rep.id}|$membre'] ?? const {};
            final brut = p['statut'];
            final statut = brut is String && !_intentions.contains(brut)
                ? brut
                : '';
            final avance = aReponduALavance(p, rep.date);
            return LigneActivite(
              rep,
              statut,
              avance,
              pointsPresence(statut, avance, bareme),
            );
          }(),
      ]),
  };
}

/// Classement : plus de points, puis plus de présences à l'heure, puis moins
/// d'absences sans excuse.
int comparerActivite(ActiviteMembre a, ActiviteMembre b) {
  var c = b.points.compareTo(a.points);
  if (c != 0) return c;
  c = b.aLHeure.compareTo(a.aLHeure);
  if (c != 0) return c;
  return a.absencesSansExcuse.compareTo(b.absencesSansExcuse);
}

/// Gagnant(s) d'une liste : les premiers du classement, ex æquo compris.
/// Personne si le meilleur n'a aucun point.
List<ActiviteMembre> gagnants(Iterable<ActiviteMembre> activites) {
  final tries = activites.toList()..sort(comparerActivite);
  if (tries.isEmpty || tries.first.points <= 0) return [];
  return tries.where((a) => comparerActivite(a, tries.first) == 0).toList();
}

/// Genre proposé d'après la voix (le responsable peut le corriger).
String? genreSelonVoix(Object? voix) => switch (voix) {
  'soprano' || 'alto' => 'femme',
  'tenor' || 'basse' => 'homme',
  _ => null,
};

/// Identifiant de mois, ex. « 2026-09 ».
String cleMois(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';

const nomsMois = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

String libelleMois(DateTime d) => '${nomsMois[d.month - 1]} ${d.year}';
