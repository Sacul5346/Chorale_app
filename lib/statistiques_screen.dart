import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'repetition_model.dart';
import 'statistiques.dart';

/// Statistiques de présence par voix et par membre (chef et responsable).
class StatistiquesScreen extends StatefulWidget {
  const StatistiquesScreen({super.key});

  @override
  State<StatistiquesScreen> createState() => _StatistiquesScreenState();
}

enum _Periode { mois, troisMois, annee }

class _Donnees {
  final int nbRepetitions;
  final Map<String, StatPresence> parMembre;
  final Map<String, StatPresence> parVoix;
  final Map<String, String> nomDe;
  final Map<String, String> voixDe;

  _Donnees({
    required this.nbRepetitions,
    required this.parMembre,
    required this.parVoix,
    required this.nomDe,
    required this.voixDe,
  });
}

const _voixLabels = {
  'soprano': 'Soprano',
  'alto': 'Alto',
  'tenor': 'Ténor',
  'basse': 'Basse',
  'non_definie': 'Voix non définie',
};

class _StatistiquesScreenState extends State<StatistiquesScreen> {
  _Periode _periode = _Periode.mois;
  late Future<_Donnees> _donnees = _charger(_periode);

  static DateTime _debut(_Periode periode) {
    final now = DateTime.now();
    return switch (periode) {
      _Periode.mois => DateTime(now.year, now.month, 1),
      _Periode.troisMois => DateTime(now.year, now.month - 2, 1),
      _Periode.annee => DateTime(now.year, 1, 1),
    };
  }

  static Future<_Donnees> _charger(_Periode periode) async {
    final db = FirebaseFirestore.instance;
    // Répétitions passées de la période (aujourd'hui compris), non annulées.
    final fin = dateSansHeure(DateTime.now()).add(const Duration(days: 1));
    final reps = await db
        .collection('repetitions')
        .where(
          'date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(_debut(periode)),
        )
        .where('date', isLessThan: Timestamp.fromDate(fin))
        .get();
    final repIds = reps.docs
        .where((d) => d.data()['statut'] != 'annulé')
        .map((d) => d.id)
        .toList();

    // Firestore limite `whereIn` à 30 valeurs : on découpe.
    final presences = <Map<String, dynamic>>[];
    for (var i = 0; i < repIds.length; i += 30) {
      final lot = await db
          .collection('presences')
          .where('repetitionId', whereIn: repIds.skip(i).take(30).toList())
          .get();
      presences.addAll(lot.docs.map((d) => d.data()));
    }

    // Membres comptés : comptes actifs, sauf le chef.
    final users = await db.collection('users').get();
    final nomDe = <String, String>{};
    final voixDe = <String, String>{};
    for (final u in users.docs) {
      final data = u.data();
      if (data['actif'] == false || data['role'] == 'chef') continue;
      final nom = data['Nom'];
      nomDe[u.id] = nom is String && nom.trim().isNotEmpty
          ? nom.trim()
          : 'Sans nom';
      final voix = data['voix'];
      voixDe[u.id] = _voixLabels.containsKey(voix)
          ? voix as String
          : 'non_definie';
    }

    final parMembre = statsParMembre(
      repetitionIds: repIds,
      membreIds: nomDe.keys,
      presences: presences,
    );
    return _Donnees(
      nbRepetitions: repIds.length,
      parMembre: parMembre,
      parVoix: statsParVoix(parMembre, voixDe),
      nomDe: nomDe,
      voixDe: voixDe,
    );
  }

  static String _pourcent(double? taux) =>
      taux == null ? '—' : '${(taux * 100).round()} %';

  static Color _couleur(double? taux) {
    if (taux == null) return Colors.grey;
    if (taux >= 0.8) return Colors.green;
    if (taux >= 0.6) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiques de présence')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<_Periode>(
              segments: const [
                ButtonSegment(value: _Periode.mois, label: Text('Ce mois')),
                ButtonSegment(value: _Periode.troisMois, label: Text('3 mois')),
                ButtonSegment(value: _Periode.annee, label: Text('Année')),
              ],
              selected: {_periode},
              onSelectionChanged: (choix) => setState(() {
                _periode = choix.first;
                _donnees = _charger(_periode);
              }),
            ),
          ),
          Expanded(
            child: FutureBuilder<_Donnees>(
              future: _donnees,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Impossible de charger les statistiques.\n'
                      'Vérifiez votre connexion internet.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final d = snapshot.data!;
                if (d.nbRepetitions == 0) {
                  return const Center(
                    child: Text(
                      'Aucune répétition passée sur cette période.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return _contenu(d);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenu(_Donnees d) {
    // Les membres les moins présents d'abord : ce sont eux à suivre.
    final membres = d.parMembre.keys.toList()
      ..sort((a, b) {
        final ta = d.parMembre[a]!.taux ?? 2;
        final tb = d.parMembre[b]!.taux ?? 2;
        final c = ta.compareTo(tb);
        return c != 0 ? c : d.nomDe[a]!.compareTo(d.nomDe[b]!);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        Text(
          '${d.nbRepetitions} répétition(s) passée(s) sur la période. '
          'Seules les présences marquées par le responsable comptent.',
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        const SizedBox(height: 12),
        const Text(
          'Par voix',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _voixLabels.keys
              .where(d.parVoix.containsKey)
              .map((voix) => _carteVoix(_voixLabels[voix]!, d.parVoix[voix]!))
              .toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Par membre (les moins présents en premier)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        ...membres.map(
          (id) => _ligneMembre(
            d.nomDe[id]!,
            _voixLabels[d.voixDe[id]]!,
            d.parMembre[id]!,
          ),
        ),
      ],
    );
  }

  Widget _carteVoix(String voix, StatPresence s) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _couleur(s.taux).withValues(alpha: 0.08),
        border: Border.all(color: _couleur(s.taux)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(voix, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(
            _pourcent(s.taux),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _couleur(s.taux),
            ),
          ),
          Text(
            '${s.presences} présences · ${s.absences} absences',
            style: const TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _ligneMembre(String nom, String voix, StatPresence s) {
    final details = [
      if (s.aLHeure > 0) '${s.aLHeure} à l\'heure',
      if (s.retards > 0)
        '${s.retards} retard(s)'
            '${s.retardsSansExcuse > 0 ? ' dont ${s.retardsSansExcuse} sans excuse' : ''}',
      if (s.absencesExcusees > 0) '${s.absencesExcusees} absence(s) excusée(s)',
      if (s.absencesSansExcuse > 0)
        '${s.absencesSansExcuse} absence(s) sans excuse',
      if (s.nonMarquees > 0) '${s.nonMarquees} non marquée(s)',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _couleur(s.taux),
          child: Text(
            s.taux == null ? '—' : '${(s.taux! * 100).round()}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ),
        title: Text(nom),
        subtitle: Text('$voix\n${details.join(' · ')}'),
        isThreeLine: true,
      ),
    );
  }
}
