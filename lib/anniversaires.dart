import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'activite.dart' show nomsMois;
import 'repetition_model.dart' show dateSansHeure;
import 'theme.dart';

/// Anniversaires des membres. Collection séparée `anniversaires/{uid}`
/// (nom, jour, mois, actif) : les membres peuvent la lire sans accéder aux
/// fiches complètes (`users`). Pas d'année de naissance, par discrétion.

class Anniversaire {
  final String uid;
  final String nom;
  final int jour;
  final int mois;

  const Anniversaire(this.uid, this.nom, this.jour, this.mois);

  static Anniversaire? depuisDoc(String uid, Map<String, dynamic> d) {
    final jour = d['jour'], mois = d['mois'];
    if (d['actif'] == false || jour is! int || mois is! int) return null;
    if (mois < 1 || mois > 12 || jour < 1 || jour > 31) return null;
    final nom = d['nom'] is String && (d['nom'] as String).trim().isNotEmpty
        ? (d['nom'] as String).trim()
        : 'Un membre';
    return Anniversaire(uid, nom, jour, mois);
  }

  String get libelle => '$jour ${nomsMois[mois - 1]}';
}

/// Prochaine date de l'anniversaire à partir d'[aujourdhui] (compris).
/// Un 29 février est fêté le 28 février les années non bissextiles.
DateTime prochaineDate(Anniversaire a, DateTime aujourdhui) {
  DateTime dans(int annee) {
    final bissextile = (annee % 4 == 0 && annee % 100 != 0) || annee % 400 == 0;
    final jour = a.mois == 2 && a.jour == 29 && !bissextile ? 28 : a.jour;
    return DateTime(annee, a.mois, jour);
  }

  final jourJ = dateSansHeure(aujourdhui);
  final cetteAnnee = dans(jourJ.year);
  return cetteAnnee.isBefore(jourJ) ? dans(jourJ.year + 1) : cetteAnnee;
}

/// Anniversaires triés du plus proche au plus lointain.
List<(Anniversaire, DateTime)> anniversairesAVenir(
  Iterable<Anniversaire> liste,
  DateTime aujourdhui,
) {
  return [for (final a in liste) (a, prochaineDate(a, aujourdhui))]
    ..sort((x, y) => x.$2.compareTo(y.$2));
}

List<Anniversaire> anniversairesDuJour(
  Iterable<Anniversaire> liste,
  DateTime aujourdhui,
) => anniversairesAVenir(
  liste,
  aujourdhui,
).where((e) => e.$2 == dateSansHeure(aujourdhui)).map((e) => e.$1).toList();

CollectionReference<Map<String, dynamic>> get _collection =>
    FirebaseFirestore.instance.collection('anniversaires');

Stream<List<Anniversaire>> ecouterAnniversaires() =>
    _collection.snapshots().map(
      (s) => [for (final d in s.docs) ?Anniversaire.depuisDoc(d.id, d.data())],
    );

Future<({int jour, int mois})?> lireAnniversaire(String uid) async {
  final d = (await _collection.doc(uid).get()).data();
  if (d == null || d['jour'] is! int || d['mois'] is! int) return null;
  return (jour: d['jour'] as int, mois: d['mois'] as int);
}

/// Enregistre (ou efface, si [jour] est null) l'anniversaire d'un membre.
Future<void> enregistrerAnniversaire(
  String uid,
  String nom,
  int? jour,
  int? mois,
) async {
  if (jour == null || mois == null) {
    await _collection.doc(uid).delete();
  } else {
    await _collection.doc(uid).set({
      'nom': nom,
      'jour': jour,
      'mois': mois,
      'actif': true,
    });
  }
}

/// Compte désactivé / réactivé : son anniversaire disparaît / réapparaît.
Future<void> activerAnniversaire(String uid, bool actif) async {
  try {
    await _collection.doc(uid).update({'actif': actif});
  } on FirebaseException catch (e) {
    if (e.code != 'not-found') rethrow; // pas d'anniversaire renseigné
  }
}

/// Champ « Anniversaire (jour et mois) » pour les formulaires.
class ChampAnniversaire extends StatelessWidget {
  final int? jour;
  final int? mois;
  final void Function(int? jour, int? mois) onChange;

  const ChampAnniversaire({
    super.key,
    required this.jour,
    required this.mois,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final renseigne = jour != null && mois != null;
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Anniversaire (jour et mois)',
        prefixIcon: Icon(Icons.cake_outlined),
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _choisir(context),
              child: Text(
                renseigne
                    ? '$jour ${nomsMois[mois! - 1]}'
                    : 'Non renseigné — toucher pour choisir',
                style: TextStyle(color: renseigne ? null : Colors.grey),
              ),
            ),
          ),
          if (renseigne)
            IconButton(
              tooltip: 'Effacer',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () => onChange(null, null),
            ),
        ],
      ),
    );
  }

  /// Choix du jour et du mois seulement (l'année n'est pas demandée).
  Future<void> _choisir(BuildContext context) async {
    var j = jour ?? 1;
    var m = mois ?? DateTime.now().month;
    final choix = await showDialog<(int, int)>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) {
          final max = joursDansMois(m);
          if (j > max) j = max;
          return AlertDialog(
            title: const Text('Date d’anniversaire'),
            content: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('jour-$m'),
                    initialValue: j,
                    decoration: const InputDecoration(labelText: 'Jour'),
                    items: [
                      for (var d = 1; d <= max; d++)
                        DropdownMenuItem(value: d, child: Text('$d')),
                    ],
                    onChanged: (v) => setDialog(() => j = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: m,
                    decoration: const InputDecoration(labelText: 'Mois'),
                    items: [
                      for (var n = 1; n <= 12; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text(nomsMois[n - 1]),
                        ),
                    ],
                    onChanged: (v) => setDialog(() => m = v!),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, (j, m)),
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
    if (choix != null) onChange(choix.$1, choix.$2);
  }
}

/// Nombre de jours possibles pour un anniversaire (29 en février).
int joursDansMois(int mois) => switch (mois) {
  2 => 29,
  4 || 6 || 9 || 11 => 30,
  _ => 31,
};

/// Liste des prochains anniversaires (menu ⋮ > Anniversaires).
class AnniversairesScreen extends StatelessWidget {
  const AnniversairesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Anniversaires')),
      body: StreamBuilder<List<Anniversaire>>(
        stream: ecouterAnniversaires(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(
              child: Text('Impossible de charger les anniversaires.'),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final aujourdhui = dateSansHeure(DateTime.now());
          final liste = anniversairesAVenir(snap.data!, aujourdhui);
          if (liste.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Aucun anniversaire renseigné.\nChacun peut ajouter le sien '
                  'dans « Mon profil ».',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liste.length,
            itemBuilder: (context, i) {
              final (a, date) = liste[i];
              final jours = date.difference(aujourdhui).inDays;
              final cestAujourdhui = jours == 0;
              return Card(
                color: cestAujourdhui
                    ? CouleursChorale.or.withValues(alpha: 0.15)
                    : null,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: cestAujourdhui
                        ? CouleursChorale.or
                        : CouleursChorale.lavande,
                    child: Icon(
                      Icons.cake,
                      color: cestAujourdhui
                          ? Colors.white
                          : CouleursChorale.aubergine,
                    ),
                  ),
                  title: Text(a.nom),
                  subtitle: Text(a.libelle),
                  trailing: Text(
                    switch (jours) {
                      0 => "Aujourd'hui 🎉",
                      1 => 'Demain',
                      _ => 'Dans $jours j',
                    },
                    style: TextStyle(
                      fontWeight: cestAujourdhui
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: cestAujourdhui
                          ? CouleursChorale.aubergine
                          : Colors.grey,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
