import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'activite.dart';
import 'parametres.dart';
import 'repetition_model.dart';
import 'theme.dart';

// ----------------------------------------------------------
// Chargement des données d'un mois
// ----------------------------------------------------------

/// Répétitions passées (aujourd'hui compris) et non annulées du [mois].
Future<List<RepetitionPassee>> _repetitionsDuMois(DateTime mois) async {
  final debut = DateTime(mois.year, mois.month, 1);
  final finMois = DateTime(mois.year, mois.month + 1, 1);
  final demain = dateSansHeure(DateTime.now()).add(const Duration(days: 1));
  final fin = finMois.isBefore(demain) ? finMois : demain;
  if (!debut.isBefore(fin)) return [];
  final snap = await FirebaseFirestore.instance
      .collection('repetitions')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(debut))
      .where('date', isLessThan: Timestamp.fromDate(fin))
      .get();
  final reps = [
    for (final d in snap.docs)
      if (d.data()['statut'] != 'annulé')
        () {
          final r = Repetition.fromFirestore(d);
          return RepetitionPassee(r.id, r.date, r.titre);
        }(),
  ]..sort((a, b) => a.date.compareTo(b.date));
  return reps;
}

Map<String, dynamic> _avecDates(Map<String, dynamic> p) => {
  ...p,
  if (p['intentionAt'] is Timestamp)
    'intentionAt': (p['intentionAt'] as Timestamp).toDate(),
};

/// Présences de ces répétitions. Avec [userId] : seulement celles de ce
/// membre (un membre n'a le droit de lire que les siennes).
Future<List<Map<String, dynamic>>> _presences(
  List<String> repIds, {
  String? userId,
}) async {
  final db = FirebaseFirestore.instance.collection('presences');
  if (userId != null) {
    final snap = await db.where('userId', isEqualTo: userId).get();
    final ids = repIds.toSet();
    return [
      for (final d in snap.docs)
        if (ids.contains(d.data()['repetitionId'])) _avecDates(d.data()),
    ];
  }
  final resultat = <Map<String, dynamic>>[];
  for (var i = 0; i < repIds.length; i += 30) {
    final snap = await db
        .where('repetitionId', whereIn: repIds.skip(i).take(30).toList())
        .get();
    resultat.addAll(snap.docs.map((d) => _avecDates(d.data())));
  }
  return resultat;
}

String _nom(Map<String, dynamic> data) {
  final n = data['Nom'];
  return n is String && n.trim().isNotEmpty ? n.trim() : 'Sans nom';
}

const _libellesStatut = {
  'present_heure': 'À l’heure',
  'present_retard': 'En retard',
  'present_retard_excuse': 'Retard excusé',
  'present_retard_sans_excuse': 'Retard sans excuse',
  'absent_excuse': 'Absent (excusé)',
  'absent_sans_excuse': 'Absent sans excuse',
};

Color _couleurStatut(String statut) {
  if (statut == 'present_heure') return Colors.green;
  if (statut.startsWith('present')) return Colors.orange;
  if (statut == 'absent_excuse') return Colors.red.shade300;
  if (statut == 'absent_sans_excuse') return Colors.red.shade800;
  return Colors.grey;
}

/// Sélecteur « ‹ septembre 2026 › ».
class _SelecteurMois extends StatelessWidget {
  final DateTime mois;
  final ValueChanged<DateTime> onChange;
  const _SelecteurMois({required this.mois, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final maintenant = DateTime.now();
    final estMoisCourant =
        mois.year == maintenant.year && mois.month == maintenant.month;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChange(DateTime(mois.year, mois.month - 1)),
        ),
        SizedBox(
          width: 170,
          child: Text(
            libelleMois(mois),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: estMoisCourant
              ? null
              : () => onChange(DateTime(mois.year, mois.month + 1)),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------
// Mon activité (historique d'un membre)
// ----------------------------------------------------------
class MonActiviteScreen extends StatefulWidget {
  /// Membre affiché : soi-même par défaut (le chef et le responsable
  /// peuvent ouvrir l'historique de n'importe quel membre).
  final String? userId;
  final String? nom;

  const MonActiviteScreen({super.key, this.userId, this.nom});

  @override
  State<MonActiviteScreen> createState() => _MonActiviteScreenState();
}

class _MonActiviteScreenState extends State<MonActiviteScreen> {
  DateTime _mois = DateTime(DateTime.now().year, DateTime.now().month);
  late Future<ActiviteMembre> _activite = _charger();

  String get _uid => widget.userId ?? FirebaseAuth.instance.currentUser!.uid;

  Future<ActiviteMembre> _charger() async {
    final reps = await _repetitionsDuMois(_mois);
    final presences = await _presences(
      reps.map((r) => r.id).toList(),
      userId: _uid,
    );
    final parametres = await ParametresChorale.charger();
    return calculerActivite(
      repetitions: reps,
      membreIds: [_uid],
      presences: presences,
      bareme: parametres.bareme,
    )[_uid]!;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nom == null ? 'Mon activité' : widget.nom!),
      ),
      body: Column(
        children: [
          _SelecteurMois(
            mois: _mois,
            onChange: (m) => setState(() {
              _mois = m;
              _activite = _charger();
            }),
          ),
          Expanded(
            child: FutureBuilder<ActiviteMembre>(
              future: _activite,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Center(
                    child: Text('Impossible de charger l’activité.'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final a = snap.data!;
                if (a.lignes.isEmpty) {
                  return const Center(
                    child: Text(
                      'Aucune répétition passée ce mois-ci.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    _resume(a),
                    const SizedBox(height: 16),
                    ...a.lignes.reversed.map(_ligne),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _resume(ActiviteMembre a) {
    Widget stat(String valeur, String libelle) => Expanded(
      child: Column(
        children: [
          Text(
            valeur,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            libelle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CouleursChorale.aubergine, CouleursChorale.aubergineFonce],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: CouleursChorale.or, size: 30),
          Text(
            '${a.points} point${a.points.abs() > 1 ? 's' : ''}',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: CouleursChorale.or,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              stat('${a.presences}/${a.lignes.length}', 'présences'),
              stat('${a.aLHeure}', 'à l’heure'),
              stat('${a.reponsesALavance}', 'réponses\nà l’avance'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ligne(LigneActivite l) {
    final d = l.repetition.date;
    final couleur = _couleurStatut(l.statut);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: couleur.withValues(alpha: 0.15),
          child: Text(
            '${d.day}',
            style: TextStyle(color: couleur, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(l.repetition.titre),
        subtitle: Text(
          '${_libellesStatut[l.statut] ?? 'Présence non marquée'}'
          '${l.reponduALavance ? ' · a répondu à l’avance' : ''}',
        ),
        trailing: Text(
          l.points > 0 ? '+${l.points}' : '${l.points}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: l.points > 0
                ? Colors.green
                : l.points < 0
                ? Colors.red
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Membres du mois (gagnants publiés, visibles par tous)
// ----------------------------------------------------------
class MembresDuMoisScreen extends StatelessWidget {
  /// Chef et responsable : accès au classement et à la publication.
  final bool peutGerer;

  const MembresDuMoisScreen({super.key, this.peutGerer = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membres du mois')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('recompenses')
            .orderBy('mois', descending: true)
            .limit(12)
            .snapshots(),
        builder: (context, snap) {
          final docs = snap.data?.docs ?? const [];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.timeline),
                      label: const Text('Mon activité'),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonActiviteScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (peutGerer) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.leaderboard),
                        label: const Text('Classement'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClassementScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              if (!snap.hasData && !snap.hasError)
                const Center(child: CircularProgressIndicator())
              else if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Text(
                    'Aucun membre du mois publié pour le moment.\n'
                    'Les gagnants sont annoncés à la fin de chaque mois.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              else
                ...docs.map((d) => _CarteRecompense(d.data())),
            ],
          );
        },
      ),
    );
  }
}

class _CarteRecompense extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CarteRecompense(this.data);

  @override
  Widget build(BuildContext context) {
    List<Map> liste(String cle) =>
        data[cle] is List ? (data[cle] as List).whereType<Map>().toList() : [];
    Widget gagnant(String titre, IconData icone, List<Map> noms) => Expanded(
      child: Column(
        children: [
          Icon(icone, color: CouleursChorale.aubergineClair),
          Text(titre, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          if (noms.isEmpty)
            const Text('—')
          else
            ...noms.map(
              (g) => Text(
                '${g['nom']}\n${g['points']} pts',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.emoji_events, color: CouleursChorale.or),
                const SizedBox(width: 8),
                Text(
                  (data['libelle'] as String? ?? '').toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: CouleursChorale.aubergine,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                gagnant('Choriste', Icons.woman, liste('femmes')),
                gagnant('Choriste', Icons.man, liste('hommes')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Classement du mois et publication (chef, responsable)
// ----------------------------------------------------------
class _Classement {
  final Map<String, ActiviteMembre> activite;
  final Map<String, String> nomDe;
  final Map<String, String?> genreDe;
  final int nbRepetitions;

  _Classement(this.activite, this.nomDe, this.genreDe, this.nbRepetitions);

  List<ActiviteMembre> du(String genre) => [
    for (final e in activite.entries)
      if (genreDe[e.key] == genre) e.value,
  ]..sort(comparerActivite);

  List<String> get sansGenre => [
    for (final e in genreDe.entries)
      if (e.value == null) nomDe[e.key]!,
  ];
}

class ClassementScreen extends StatefulWidget {
  const ClassementScreen({super.key});

  @override
  State<ClassementScreen> createState() => _ClassementScreenState();
}

class _ClassementScreenState extends State<ClassementScreen> {
  // Début de mois : on regarde plutôt le mois qui vient de se terminer.
  DateTime _mois = DateTime.now().day <= 7
      ? DateTime(DateTime.now().year, DateTime.now().month - 1)
      : DateTime(DateTime.now().year, DateTime.now().month);
  late Future<_Classement> _classement = _charger();
  bool _publication = false;

  Future<_Classement> _charger() async {
    final reps = await _repetitionsDuMois(_mois);
    final presences = await _presences(reps.map((r) => r.id).toList());
    final parametres = await ParametresChorale.charger();
    final users = await FirebaseFirestore.instance.collection('users').get();
    final nomDe = <String, String>{};
    final genreDe = <String, String?>{};
    for (final u in users.docs) {
      final data = u.data();
      // Le chef ne concourt pas ; les comptes désactivés non plus.
      if (data['actif'] == false || data['role'] == 'chef') continue;
      nomDe[u.id] = _nom(data);
      final g = data['genre'];
      genreDe[u.id] = g == 'homme' || g == 'femme' ? g as String : null;
    }
    return _Classement(
      calculerActivite(
        repetitions: reps,
        membreIds: nomDe.keys,
        presences: presences,
        bareme: parametres.bareme,
      ),
      nomDe,
      genreDe,
      reps.length,
    );
  }

  Future<void> _publier(_Classement c) async {
    List<Map<String, dynamic>> liste(String genre) => [
      for (final a in gagnants(c.du(genre)))
        {'uid': a.userId, 'nom': c.nomDe[a.userId], 'points': a.points},
    ];
    final femmes = liste('femme');
    final hommes = liste('homme');
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Publier les membres de ${libelleMois(_mois)} ?'),
        content: Text(
          '👩 ${femmes.isEmpty ? 'personne' : femmes.map((g) => g['nom']).join(', ')}\n'
          '👨 ${hommes.isEmpty ? 'personne' : hommes.map((g) => g['nom']).join(', ')}\n\n'
          'Tous les membres verront les gagnants. Vous pourrez republier '
          'si besoin (le résultat sera remplacé).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _publication = true);
    try {
      await FirebaseFirestore.instance
          .collection('recompenses')
          .doc(cleMois(_mois))
          .set({
            'mois': cleMois(_mois),
            'libelle': libelleMois(_mois),
            'femmes': femmes,
            'hommes': hommes,
            'publieLe': FieldValue.serverTimestamp(),
            'publiePar': FirebaseAuth.instance.currentUser!.uid,
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Membres du mois publiés 🏆'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Publication impossible : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _publication = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Classement du mois'),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: CouleursChorale.or,
            tabs: [
              Tab(icon: Icon(Icons.woman), text: 'Femmes'),
              Tab(icon: Icon(Icons.man), text: 'Hommes'),
            ],
          ),
        ),
        body: Column(
          children: [
            _SelecteurMois(
              mois: _mois,
              onChange: (m) => setState(() {
                _mois = m;
                _classement = _charger();
              }),
            ),
            Expanded(
              child: FutureBuilder<_Classement>(
                future: _classement,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(
                      child: Text('Impossible de calculer le classement.'),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final c = snap.data!;
                  if (c.nbRepetitions == 0) {
                    return const Center(
                      child: Text(
                        'Aucune répétition passée ce mois-ci.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      if (c.sansGenre.isNotEmpty)
                        Container(
                          width: double.infinity,
                          color: Colors.orange.shade50,
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            '⚠️ Genre non renseigné (hors classement) : '
                            '${c.sansGenre.join(', ')}. À compléter dans '
                            'l’onglet Membres.',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      Expanded(
                        child: TabBarView(
                          children: [_liste(c, 'femme'), _liste(c, 'homme')],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CouleursChorale.or,
                              foregroundColor: CouleursChorale.aubergineFonce,
                              minimumSize: const Size.fromHeight(50),
                            ),
                            onPressed: _publication ? null : () => _publier(c),
                            icon: const Icon(Icons.emoji_events),
                            label: Text(
                              'Publier les membres de ${libelleMois(_mois)}',
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liste(_Classement c, String genre) {
    final liste = c.du(genre);
    final premiers = gagnants(liste).map((a) => a.userId).toSet();
    if (liste.isEmpty) {
      return const Center(
        child: Text(
          'Personne dans cette catégorie.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final a = liste[i];
        final gagne = premiers.contains(a.userId);
        return Card(
          color: gagne ? CouleursChorale.or.withValues(alpha: 0.12) : null,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: gagne
                  ? CouleursChorale.or
                  : CouleursChorale.lavande,
              child: gagne
                  ? const Icon(Icons.emoji_events, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: CouleursChorale.aubergine,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            title: Text(c.nomDe[a.userId]!),
            subtitle: Text(
              '${a.presences}/${a.lignes.length} présences · '
              '${a.aLHeure} à l’heure · ${a.reponsesALavance} réponses à l’avance',
            ),
            trailing: Text(
              '${a.points} pts',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MonActiviteScreen(userId: a.userId, nom: c.nomDe[a.userId]),
              ),
            ),
          ),
        );
      },
    );
  }
}
