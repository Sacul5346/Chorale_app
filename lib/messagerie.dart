/// Messagerie des excuses : logique pure (dates, réponses rapides, excuse
/// acceptée), sans Firestore, pour pouvoir la tester.
///
/// Une conversation = une répétition + un membre (`{repetitionId}_{membreId}`).
/// Champs de la conversation :
///  - `unreadByResponsable` : non lue par la direction (chef / suppléant) —
///    nom historique conservé pour les données existantes ;
///  - `unreadByMembre` : réponse de la direction pas encore lue par le membre.
/// Champs d'un message : `texte`, `senderId`, `senderNom`, `senderRole`
/// (`chef` | `suppleant` | `membre`), `sentAt`, `lu`, et `supprime` quand son
/// auteur l'a supprimé (le texte est alors vidé).
library;

import 'activite.dart' show nomsMois;

const _mois = [
  'janv.',
  'févr.',
  'mars',
  'avr.',
  'mai',
  'juin',
  'juil.',
  'août',
  'sept.',
  'oct.',
  'nov.',
  'déc.',
];
const _jours = [
  'lundi',
  'mardi',
  'mercredi',
  'jeudi',
  'vendredi',
  'samedi',
  'dimanche',
];

DateTime _jour(DateTime d) => DateTime(d.year, d.month, d.day);

/// Séparateur de jour : « Aujourd'hui », « Hier », « mardi » (cette
/// semaine), « 23 nov. », ou « 23 nov. 2025 » pour une autre année.
String libelleJour(DateTime date, DateTime maintenant) {
  final ecart = _jour(maintenant).difference(_jour(date)).inDays;
  if (ecart == 0) return 'Aujourd’hui';
  if (ecart == 1) return 'Hier';
  if (ecart > 1 && ecart < 7) {
    final j = _jours[date.weekday - 1];
    return '${j[0].toUpperCase()}${j.substring(1)}';
  }
  final base = '${date.day} ${_mois[date.month - 1]}';
  return date.year == maintenant.year ? base : '$base ${date.year}';
}

/// Heure d'un message : « 14:05 ».
String heure(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Date courte dans les listes : l'heure aujourd'hui, sinon le jour.
String dateCourte(DateTime d, DateTime maintenant) =>
    _jour(d) == _jour(maintenant) ? heure(d) : libelleJour(d, maintenant);

/// Faut-il un séparateur de jour avant ce message ?
bool nouveauJour(DateTime? precedent, DateTime courant) =>
    precedent == null || _jour(precedent) != _jour(courant);

/// Titre affiché quand la répétition d'une conversation n'existe plus.
const repetitionSupprimee = 'Répétition supprimée';

/// Texte affiché à la place d'un message supprimé.
const messageSupprime = 'Message supprimé';

/// Réponses rapides proposées à la direction.
const reponsesRapides = [
  'Bien reçu, merci 🙏',
  'Merci de prévenir plus tôt la prochaine fois.',
  'Peux-tu préciser la raison ?',
];

/// Message envoyé quand la direction accepte l'excuse.
const messageExcuseAcceptee = 'Excuse acceptée 🙏';

/// Présence à enregistrer quand la direction accepte l'excuse, selon ce que
/// le membre a annoncé et ce qui est déjà constaté. Null : ne rien changer
/// (présence déjà constatée, ou retard annoncé : le scan à l'arrivée le
/// comptera « en retard avec excuse »).
String? statutExcuseAcceptee({
  required String intention,
  required String statutConstate,
}) {
  if (statutConstate.isNotEmpty) return null;
  if (intention == 'retard') return null;
  return 'absent_excuse';
}

/// Libellé de l'auteur d'un message de la direction.
String libelleDirection(Object? role) =>
    role == 'suppleant' ? 'Suppléant du chef' : 'Chef de chorale';

// ---------------------------------------------------------------------------
// Liste de la direction : conversations regroupées par répétition
// ---------------------------------------------------------------------------

/// Ce que l'on sait d'une répétition : chargée (date, titre), supprimée
/// depuis, ou pas encore chargée (absente de la table).
class InfoRepetition {
  final String titre;
  final DateTime? date;
  final bool supprimee;
  const InfoRepetition(this.titre, this.date) : supprimee = false;
  const InfoRepetition.supprimee() : titre = '', date = null, supprimee = true;
}

/// Groupe de conversations d'une même répétition ; [repetitionId] est null
/// pour le groupe final des répétitions supprimées.
class GroupeExcuses<T> {
  final String? repetitionId;
  final InfoRepetition? info;
  final List<T> conversations;
  const GroupeExcuses(this.repetitionId, this.info, this.conversations);
  bool get supprimees => repetitionId == null;
}

/// Regroupe par répétition, en gardant l'ordre reçu dans chaque groupe
/// (le plus récent d'abord). Groupes : répétitions datées, de la plus
/// récente à la plus ancienne ; puis celles pas encore chargées ; enfin les
/// répétitions supprimées, réunies en un seul groupe.
List<GroupeExcuses<T>> grouperParRepetition<T>(
  List<T> conversations,
  String Function(T) repetitionDe,
  Map<String, InfoRepetition> repetitions,
) {
  final parRep = <String, List<T>>{};
  final supprimees = <T>[];
  for (final c in conversations) {
    final id = repetitionDe(c);
    if (repetitions[id]?.supprimee ?? false) {
      supprimees.add(c);
    } else {
      parRep.putIfAbsent(id, () => []).add(c);
    }
  }
  final groupes = [
    for (final e in parRep.entries)
      GroupeExcuses<T>(e.key, repetitions[e.key], e.value),
  ];
  groupes.sort((a, b) {
    final da = a.info?.date, db = b.info?.date;
    if (da == null && db == null) return 0;
    if (da == null) return 1;
    if (db == null) return -1;
    return db.compareTo(da);
  });
  return [
    ...groupes,
    if (supprimees.isNotEmpty) GroupeExcuses<T>(null, null, supprimees),
  ];
}

const _joursLong = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// En-tête de groupe : « Samedi 28 novembre » (+ l'année si ce n'est pas
/// celle en cours).
String titreGroupe(DateTime date, DateTime maintenant) {
  final base =
      '${_joursLong[date.weekday - 1]} ${date.day} ${nomsMois[date.month - 1]}';
  return date.year == maintenant.year ? base : '$base ${date.year}';
}
