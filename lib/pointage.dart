/// Pointage des présences par scan du badge (QR code) : logique pure,
/// sans Firestore ni caméra, pour pouvoir la tester.
///
/// Le badge porte `KTKFA:MEMBRE:<uid>` (voir badge.dart). Au scan, le
/// membre est marqué présent à l'heure, ou en retard (avec ou sans excuse)
/// selon l'heure de début de la répétition et la tolérance réglée dans les
/// paramètres. En fin de pointage, le chef peut marquer absents ceux qui
/// n'ont pas été scannés.
library;

import 'badge.dart' show contenuQrMembre;

/// Tolérance de retard par défaut, en minutes.
const toleranceRetardParDefaut = 15;

/// Choix proposés dans les paramètres.
const choixToleranceRetard = [0, 5, 10, 15, 20, 30, 45, 60];

final _prefixeQr = contenuQrMembre('');
final _uidValide = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Identifiant du membre lu sur un badge, ou null si ce n'est pas un badge
/// K.T.K.F.A.
String? membreDepuisQr(String? brut) {
  if (brut == null) return null;
  final texte = brut.trim();
  if (!texte.startsWith(_prefixeQr)) return null;
  final uid = texte.substring(_prefixeQr.length);
  return _uidValide.hasMatch(uid) ? uid : null;
}

/// Heure saisie en texte libre : « 18h00 », « 18h », « 14H30 », « 18:30 »,
/// « 9 h 15 »… Null si illisible (« à confirmer », vide…).
({int heure, int minute})? lireHeure(String texte) {
  final m = RegExp(
    r'(\d{1,2})\s*(?:h|H|:)\s*(\d{2})?',
  ).firstMatch(texte.trim());
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = m.group(2) == null ? 0 : int.parse(m.group(2)!);
  if (h > 23 || min > 59) return null;
  return (heure: h, minute: min);
}

/// Début de la répétition (date à minuit + heure texte), ou null.
DateTime? debutRepetition(DateTime date, String heure) {
  final h = lireHeure(heure);
  if (h == null) return null;
  return DateTime(date.year, date.month, date.day, h.heure, h.minute);
}

/// Le membre avait prévenu : réponse « En retard » / « Absent » dans l'app,
/// ou excuse envoyée pour cette répétition.
bool aPrevenu(String intention, {required bool excuseEnvoyee}) =>
    excuseEnvoyee || intention == 'retard' || intention == 'absent';

/// Statut constaté au moment du scan.
///
/// Sans heure de début lisible, le membre est marqué à l'heure : le chef
/// corrige à la main si besoin.
String statutAuScan({
  required DateTime? debut,
  required DateTime scan,
  required int toleranceMinutes,
  required String intention,
  required bool excuseEnvoyee,
}) {
  if (debut == null ||
      !scan.isAfter(debut.add(Duration(minutes: toleranceMinutes)))) {
    return 'present_heure';
  }
  return aPrevenu(intention, excuseEnvoyee: excuseEnvoyee)
      ? 'present_retard_excuse'
      : 'present_retard_sans_excuse';
}

/// Statut d'un membre non scanné, quand le chef clôture le pointage.
String statutAbsent({required String intention, required bool excuseEnvoyee}) =>
    aPrevenu(intention, excuseEnvoyee: excuseEnvoyee)
    ? 'absent_excuse'
    : 'absent_sans_excuse';

/// Vrai si le statut constaté est une présence (à l'heure ou en retard).
bool estPresent(String statut) => statut.startsWith('present_');

// ---------------------------------------------------------------------------
// Lecture d'un document `presences`
//  - `intention` : ce que le membre annonce (present | absent | retard)
//  - `statut`    : ce que le chef constate (present_heure, ...)
// ---------------------------------------------------------------------------
const intentionsMembre = ['present', 'absent', 'retard'];

/// Intention annoncée par le membre. Les anciens documents (app 1.0.0) la
/// stockaient dans `statut` : on la relit à cet endroit si besoin.
String intentionDe(Map<String, dynamic> data) {
  final intention = data['intention'];
  if (intention is String) return intention;
  final ancien = data['statut'];
  return intentionsMembre.contains(ancien) ? ancien as String : '';
}

/// Présence constatée par le chef (vide si pas encore marquée).
String statutConstateDe(Map<String, dynamic> data) {
  final statut = data['statut'];
  return statut is String && !intentionsMembre.contains(statut) ? statut : '';
}
