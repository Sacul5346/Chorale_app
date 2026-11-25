import 'package:cloud_firestore/cloud_firestore.dart';

/// Rôles de la chorale.
///
/// - `chef` : pouvoir absolu (seul à gérer les comptes et les suppléances).
/// - `lyrics_manager` : gère les paroles et les playbacks.
/// - `membre` : choriste (rôle par défaut).
///
/// L'ancien rôle `responsable` n'existe plus : un compte qui le porte encore
/// est traité comme un simple membre.
///
/// Pendant une absence, le chef désigne un **suppléant** : un membre qui
/// reçoit tous les pouvoirs de gestion (répétitions, présences, excuses,
/// chansons, paramètres…) sauf la gestion des comptes, jusqu'à une date de
/// fin. Le champ [champSuppleance] de sa fiche `users` porte cette date ;
/// les règles Firestore appliquent la même condition.
const champSuppleance = 'suppleantJusquau';

/// Rôle reconnu par l'app : `chef`, `lyrics_manager` ou `membre`.
String roleNormalise(Object? role) =>
    role == 'chef' || role == 'lyrics_manager' ? role as String : 'membre';

/// Fin de la suppléance inscrite sur la fiche (même expirée), ou null.
DateTime? finSuppleance(Map<String, dynamic> fiche) {
  final fin = fiche[champSuppleance];
  return fin is Timestamp ? fin.toDate() : null;
}

/// Vrai si la fiche est celle d'un suppléant dont la période court encore.
bool estSuppleant(Map<String, dynamic> fiche, DateTime maintenant) {
  if (fiche['actif'] == false || roleNormalise(fiche['role']) == 'chef') {
    return false;
  }
  final fin = finSuppleance(fiche);
  return fin != null && maintenant.isBefore(fin);
}

/// Fin de suppléance pour un dernier jour choisi : le lendemain à minuit,
/// pour que le suppléant garde ses pouvoirs toute la journée choisie.
DateTime finPourDernierJour(DateTime dernierJour) =>
    DateTime(dernierJour.year, dernierJour.month, dernierJour.day + 1);
