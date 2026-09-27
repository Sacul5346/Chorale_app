import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'repetition_model.dart';
import 'activite.dart' show libelleMois, nomsMois;
import 'anniversaires.dart';
import 'membres_du_mois_screen.dart';
import 'parametres.dart';
import 'parametres_screen.dart';
import 'presence_screen.dart';
import 'profile_screen.dart';
import 'statistiques_screen.dart';
import 'theme.dart';
import 'versets.dart';

class RepetitionsScreen extends StatelessWidget {
  final String role;
  const RepetitionsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final gestion = role == 'chef' || role == 'responsable';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Répétitions'),
        actions: [
          if (role == 'chef')
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Générer les répétitions du mois',
              onPressed: () => _showGenerateDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Membres du mois',
            onPressed: () =>
                _ouvrir(context, MembresDuMoisScreen(peutGerer: gestion)),
          ),
          PopupMenuButton<String>(
            tooltip: 'Menu',
            onSelected: (choix) {
              switch (choix) {
                case 'profil':
                  _ouvrir(context, const ProfileScreen());
                case 'activite':
                  _ouvrir(context, const MonActiviteScreen());
                case 'anniversaires':
                  _ouvrir(context, const AnniversairesScreen());
                case 'stats':
                  _ouvrir(context, const StatistiquesScreen());
                case 'parametres':
                  _ouvrir(context, const ParametresScreen());
                case 'deconnexion':
                  FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (_) => [
              _entreeMenu('profil', Icons.person_outline, 'Mon profil'),
              _entreeMenu('activite', Icons.timeline, 'Mon activité'),
              _entreeMenu(
                'anniversaires',
                Icons.cake_outlined,
                'Anniversaires',
              ),
              if (gestion) ...[
                const PopupMenuDivider(),
                _entreeMenu('stats', Icons.bar_chart, 'Statistiques'),
                _entreeMenu(
                  'parametres',
                  Icons.settings_outlined,
                  'Paramètres de la chorale',
                ),
              ],
              const PopupMenuDivider(),
              _entreeMenu('deconnexion', Icons.logout, 'Se déconnecter'),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('repetitions')
            .orderBy('date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucune répétition pour le moment',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final repetitions = snapshot.data!.docs
              .map((doc) => Repetition.fromFirestore(doc))
              .toList();

          // À venir : aujourd'hui compris, de la plus proche à la plus
          // lointaine. Passées : de la plus récente à la plus ancienne.
          final aujourdhui = dateSansHeure(DateTime.now());
          final aVenir = repetitions
              .where((r) => !r.date.isBefore(aujourdhui))
              .toList();
          final passees = repetitions
              .where((r) => r.date.isBefore(aujourdhui))
              .toList()
              .reversed
              .toList();
          final prochaine = aVenir
              .where((r) => r.statut != 'annulé')
              .firstOrNull;

          // Réponses du membre connecté, affichées sur chaque carte.
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('presences')
                .where(
                  'userId',
                  isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                )
                .snapshots(),
            builder: (context, presSnap) {
              final reponses = <String, String>{
                for (final d in presSnap.data?.docs ?? const [])
                  if (d.data()['repetitionId'] case final String id)
                    id: intentionDe(d.data()),
              };

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const _BandeauAnniversaires(),
                  _CarteVerset(verset: versetDuJour(DateTime.now())),
                  const SizedBox(height: 16),
                  if (prochaine != null) ...[
                    _CarteProchaine(
                      rep: prochaine,
                      reponse: reponses[prochaine.id] ?? '',
                      onOuvrir: () => _ouvrirRepetition(context, prochaine),
                    ),
                    const SizedBox(height: 20),
                  ],
                  if (aVenir.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        'Aucune répétition prévue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  // Les autres répétitions à venir, groupées par mois.
                  for (final mois in _parMois(
                    aVenir.where((r) => r != prochaine).toList(),
                  ).entries) ...[
                    _titreSection(mois.key),
                    for (final rep in mois.value)
                      _repetitionCard(context, rep, reponses[rep.id] ?? ''),
                  ],
                  if (passees.isNotEmpty)
                    Theme(
                      // Retire les traits de séparation de l'ExpansionTile.
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                        title: _titreSection(
                          'RÉPÉTITIONS PASSÉES (${passees.length})',
                        ),
                        children: [
                          for (final rep in passees)
                            Opacity(
                              opacity: 0.7,
                              child: _repetitionCard(
                                context,
                                rep,
                                reponses[rep.id] ?? '',
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: role == 'chef'
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Répétition'),
              onPressed: () => _showCreateDialog(context),
            )
          : null,
    );
  }

  static void _ouvrir(BuildContext context, Widget ecran) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => ecran));

  static PopupMenuItem<String> _entreeMenu(
    String valeur,
    IconData icone,
    String texte,
  ) => PopupMenuItem(
    value: valeur,
    child: Row(
      children: [
        Icon(icone, size: 20, color: CouleursChorale.aubergine),
        const SizedBox(width: 12),
        Text(texte),
      ],
    ),
  );

  void _ouvrirRepetition(BuildContext context, Repetition rep) => _ouvrir(
    context,
    PresenceScreen(
      repetitionId: rep.id,
      repetitionTitre: rep.titre,
      role: role,
      chansons: rep.chansons,
      raison: rep.raison,
    ),
  );

  /// « OCTOBRE 2026 » → répétitions de ce mois (ordre conservé).
  static Map<String, List<Repetition>> _parMois(List<Repetition> reps) {
    final groupes = <String, List<Repetition>>{};
    for (final r in reps) {
      groupes.putIfAbsent(libelleMois(r.date).toUpperCase(), () => []).add(r);
    }
    return groupes;
  }

  static Widget _titreSection(String texte) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
    child: Text(
      texte,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 1.2,
        color: CouleursChorale.aubergineClair,
      ),
    ),
  );

  Widget _repetitionCard(BuildContext context, Repetition rep, String reponse) {
    final annulee = rep.statut == 'annulé';
    final passee = rep.date.isBefore(dateSansHeure(DateTime.now()));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _ouvrirRepetition(context, rep),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BlocDate(date: rep.date, annulee: annulee),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rep.titre,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        decoration: annulee ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    infosRepetition(rep),
                    if (rep.raison.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          rep.raison,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CouleursChorale.aubergineClair,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    if (annulee)
                      _Etiquette(
                        texte: rep.causeAnnulation.isEmpty
                            ? 'Annulée'
                            : 'Annulée : ${rep.causeAnnulation}',
                        couleur: Colors.red,
                      )
                    else if (!passee)
                      _Etiquette(
                        texte: _libelleReponse(reponse),
                        couleur: _couleurReponse(reponse),
                      ),
                  ],
                ),
              ),
              if (role == 'chef')
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  onSelected: (choix) => choix == 'modifier'
                      ? _showEditDialog(context, rep)
                      : _showDeleteOptions(context, rep),
                  itemBuilder: (_) => [
                    _entreeMenu('modifier', Icons.edit_outlined, 'Modifier'),
                    _entreeMenu(
                      'supprimer',
                      Icons.delete_outline,
                      'Annuler / supprimer',
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _libelleReponse(String reponse) => switch (reponse) {
    'present' => 'Vous venez',
    'retard' => 'Vous serez en retard',
    'absent' => 'Vous serez absent',
    _ => 'Pas encore répondu',
  };

  static Color _couleurReponse(String reponse) => switch (reponse) {
    'present' => Colors.green,
    'retard' => Colors.orange,
    'absent' => Colors.red,
    _ => Colors.grey,
  };

  /// Ajoute au champ « chansons » des titres choisis dans la liste des
  /// chansons : les titres exacts permettent d'ouvrir les paroles depuis
  /// la répétition.
  static Future<void> _choisirChansons(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final songs = await FirebaseFirestore.instance.collection('songs').get();
    final titres =
        songs.docs
            .map((d) => d.data()['title'])
            .whereType<String>()
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (!context.mounted) return;

    final dejaLa = controller.text
        .split('\n')
        .map((l) => l.trim().toLowerCase())
        .toSet();
    final choisis = <String>{};

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Chansons à répéter'),
          content: SizedBox(
            width: double.maxFinite,
            child: titres.isEmpty
                ? const Text('Aucune chanson dans la liste.')
                : ListView(
                    shrinkWrap: true,
                    children: titres.map((titre) {
                      final present = dejaLa.contains(titre.toLowerCase());
                      return CheckboxListTile(
                        dense: true,
                        title: Text(titre),
                        subtitle: present ? const Text('Déjà ajoutée') : null,
                        value: present || choisis.contains(titre),
                        onChanged: present
                            ? null
                            : (v) => setState(
                                () => v == true
                                    ? choisis.add(titre)
                                    : choisis.remove(titre),
                              ),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Ajouter'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || choisis.isEmpty) return;
    final texte = controller.text.trimRight();
    controller.text = [
      if (texte.isNotEmpty) texte,
      ...titres.where(choisis.contains),
    ].join('\n');
  }

  /// Répétitions du planning hebdomadaire ([creneaux], voir Paramètres de
  /// la chorale) entre [debut] et la fin de son mois. Dates à minuit (voir
  /// [dateSansHeure]). Les créneaux « à confirmer » sont proposés décochés.
  @visibleForTesting
  static List<Map<String, dynamic>> repetitionsDuMois(
    DateTime debut, [
    List<Creneau> creneaux = const [],
  ]) {
    final planning = creneaux.isEmpty
        ? ParametresChorale.defaut.creneaux
        : creneaux;
    final repetitions = <Map<String, dynamic>>[];
    final finDuMois = DateTime(debut.year, debut.month + 1, 1);

    for (
      var current = dateSansHeure(debut);
      current.isBefore(finDuMois);
      current = DateTime(current.year, current.month, current.day + 1)
    ) {
      for (final c in planning.where((c) => c.jour == current.weekday)) {
        repetitions.add({
          'date': current,
          'heure': c.heure,
          'lieu': c.lieu,
          'jour': c.nomJour,
          'confirmed': !c.aConfirmer,
          'aConfirmer': c.aConfirmer,
        });
      }
    }
    return repetitions;
  }

  Future<void> _showGenerateDialog(BuildContext context) async {
    final now = DateTime.now();
    final planning = (await ParametresChorale.charger()).creneaux;
    if (!context.mounted) return;
    // Ce mois-ci : d'aujourd'hui à la fin du mois. Mois prochain : en entier.
    var moisProchain = false;
    var repetitionsToCreate = repetitionsDuMois(now, planning);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Générer les répétitions du mois'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Ce mois-ci')),
                    ButtonSegment(value: true, label: Text('Mois prochain')),
                  ],
                  selected: {moisProchain},
                  onSelectionChanged: (choix) {
                    setState(() {
                      moisProchain = choix.first;
                      repetitionsToCreate = repetitionsDuMois(
                        moisProchain
                            ? DateTime(now.year, now.month + 1, 1)
                            : now,
                        planning,
                      );
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cochez les répétitions à créer. Le planning se règle dans '
                  'Paramètres de la chorale (⚙️).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: repetitionsToCreate.length,
                    itemBuilder: (context, index) {
                      final rep = repetitionsToCreate[index];
                      final date = rep['date'] as DateTime;
                      final aConfirmer = rep['aConfirmer'] as bool;
                      final confirmed = rep['confirmed'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: aConfirmer
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: aConfirmer ? Colors.orange : Colors.green,
                            width: 0.5,
                          ),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          value: confirmed,
                          activeColor: aConfirmer
                              ? Colors.orange
                              : Colors.green,
                          onChanged: (val) {
                            setState(() {
                              repetitionsToCreate[index]['confirmed'] = val!;
                            });
                          },
                          title: Text(
                            '${rep['jour']} ${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: aConfirmer
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${rep['heure']} · ${rep['lieu']}',
                                  style: const TextStyle(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (aConfirmer) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'À confirmer',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursChorale.aubergine,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final confirmed = repetitionsToCreate
                    .where((r) => r['confirmed'] == true)
                    .toList();

                if (confirmed.isEmpty) {
                  Navigator.pop(context);
                  return;
                }

                int created = 0;
                for (var rep in confirmed) {
                  final date = rep['date'] as DateTime;

                  // Vérifier s'il existe déjà une répétition ce jour-là.
                  // On cherche sur toute la journée : les anciennes
                  // répétitions créées à la main ont une heure.
                  final existing = await FirebaseFirestore.instance
                      .collection('repetitions')
                      .where(
                        'date',
                        isGreaterThanOrEqualTo: Timestamp.fromDate(date),
                      )
                      .where(
                        'date',
                        isLessThan: Timestamp.fromDate(
                          DateTime(date.year, date.month, date.day + 1),
                        ),
                      )
                      .limit(1)
                      .get();

                  if (existing.docs.isEmpty) {
                    await FirebaseFirestore.instance.collection('repetitions').add({
                      'titre':
                          'Répétition du ${rep['jour']} ${date.day}/${date.month}',
                      'date': Timestamp.fromDate(date),
                      'heure': rep['heure'],
                      'lieu': rep['lieu'],
                      'raison': '',
                      'chansons': '',
                      'causeAnnulation': '',
                      'chefId': FirebaseAuth.instance.currentUser!.uid,
                      'statut': 'actif',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    created++;
                  }
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$created répétition(s) créée(s) avec succès !',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              child: const Text('Générer'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // CRÉATION
  // ----------------------------------------------------------
  void _showCreateDialog(BuildContext context) {
    final titreController = TextEditingController();
    final heureController = TextEditingController();
    final lieuController = TextEditingController();
    final raisonController = TextEditingController();
    final chansonsController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nouvelle répétition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titreController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heureController,
                  decoration: const InputDecoration(
                    labelText: 'Heure (ex: 18h00)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lieuController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: raisonController,
                  decoration: const InputDecoration(
                    labelText: 'Raison (ex: Préparation concert)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chansonsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Chansons à répéter (une par ligne)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.library_music),
                    label: const Text('Choisir dans la liste'),
                    onPressed: () =>
                        _choisirChansons(context, chansonsController),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursChorale.aubergine,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (titreController.text.isEmpty) return;
                await FirebaseFirestore.instance.collection('repetitions').add({
                  'titre': titreController.text.trim(),
                  'date': Timestamp.fromDate(dateSansHeure(selectedDate)),
                  'heure': heureController.text.trim(),
                  'lieu': lieuController.text.trim(),
                  'raison': raisonController.text.trim(),
                  'chansons': chansonsController.text.trim(),
                  'causeAnnulation': '',
                  'chefId': FirebaseAuth.instance.currentUser!.uid,
                  'statut': 'actif',
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // MODIFICATION
  // ----------------------------------------------------------
  void _showEditDialog(BuildContext context, Repetition rep) {
    final titreController = TextEditingController(text: rep.titre);
    final heureController = TextEditingController(text: rep.heure);
    final lieuController = TextEditingController(text: rep.lieu);
    final raisonController = TextEditingController(text: rep.raison);
    final chansonsController = TextEditingController(text: rep.chansons);
    DateTime selectedDate = rep.date;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Modifier la répétition'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titreController,
                  decoration: const InputDecoration(
                    labelText: 'Titre',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today),
                  title: Text(
                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                  ),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heureController,
                  decoration: const InputDecoration(
                    labelText: 'Heure (ex: 18h00)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lieuController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: raisonController,
                  decoration: const InputDecoration(
                    labelText: 'Raison',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: chansonsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Chansons à répéter (une par ligne)',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.library_music),
                    label: const Text('Choisir dans la liste'),
                    onPressed: () =>
                        _choisirChansons(context, chansonsController),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: CouleursChorale.aubergine,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('repetitions')
                    .doc(rep.id)
                    .update({
                      'titre': titreController.text.trim(),
                      'date': Timestamp.fromDate(dateSansHeure(selectedDate)),
                      'heure': heureController.text.trim(),
                      'lieu': lieuController.text.trim(),
                      'raison': raisonController.text.trim(),
                      'chansons': chansonsController.text.trim(),
                    });
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // SUPPRESSION — choix entre annuler ou supprimer définitivement
  // ----------------------------------------------------------
  void _showDeleteOptions(BuildContext context, Repetition rep) {
    // Le contexte du dialogue est fermé par pop() : on ouvre le suivant
    // avec celui de l'écran.
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Que veux-tu faire ?'),
        content: const Text(
          'Tu peux annuler cette répétition (elle reste visible avec un motif) '
          'ou la supprimer définitivement (elle disparaît complètement).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fermer'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(dialogContext);
              _showCancelDialog(context, rep);
            },
            child: const Text('Annuler la répétition'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _showDeleteConfirm(context, rep);
            },
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, Repetition rep) {
    final causeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motif de l\'annulation'),
        content: TextField(
          controller: causeController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Pourquoi cette répétition est annulée ?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (causeController.text.trim().isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('repetitions')
                  .doc(rep.id)
                  .update({
                    'statut': 'annulé',
                    'causeAnnulation': causeController.text.trim(),
                  });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );
  }

  /// Supprime la répétition avec ses présences, ses conversations d'excuse
  /// et leurs messages. Firestore n'efface pas les sous-collections tout
  /// seul, et un lot (WriteBatch) est limité à 500 opérations.
  static Future<void> _supprimerRepetition(String repetitionId) async {
    final db = FirebaseFirestore.instance;
    final aSupprimer = <DocumentReference>[];

    final presences = await db
        .collection('presences')
        .where('repetitionId', isEqualTo: repetitionId)
        .get();
    aSupprimer.addAll(presences.docs.map((d) => d.reference));

    final conversations = await db
        .collection('conversations')
        .where('repetitionId', isEqualTo: repetitionId)
        .get();
    for (final conversation in conversations.docs) {
      final messages = await conversation.reference
          .collection('messages')
          .get();
      aSupprimer.addAll(messages.docs.map((d) => d.reference));
      aSupprimer.add(conversation.reference);
    }

    // La répétition en dernier : si une étape échoue, elle reste visible
    // et on peut relancer la suppression.
    aSupprimer.add(db.collection('repetitions').doc(repetitionId));

    for (var i = 0; i < aSupprimer.length; i += 450) {
      final batch = db.batch();
      for (final ref in aSupprimer.skip(i).take(450)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  void _showDeleteConfirm(BuildContext context, Repetition rep) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suppression définitive'),
        content: Text(
          'Voulez-vous vraiment supprimer "${rep.titre}" ? '
          'Cette action est irréversible et effacera aussi les présences '
          'et les messages d\'excuse liés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await _supprimerRepetition(rep.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

/// Heure et lieu d'une répétition, avec icônes.
Widget infosRepetition(Repetition rep, {Color? couleur}) {
  final style = TextStyle(fontSize: 13, color: couleur ?? Colors.black54);
  Widget info(IconData icone, String texte) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icone, size: 15, color: style.color),
      const SizedBox(width: 4),
      Text(texte, style: style),
    ],
  );
  return Wrap(
    spacing: 12,
    runSpacing: 2,
    children: [
      if (rep.heure.isNotEmpty) info(Icons.schedule, rep.heure),
      if (rep.lieu.isNotEmpty) info(Icons.place_outlined, rep.lieu),
    ],
  );
}

/// Bloc date « JEU / 2 / OCT » à gauche des cartes de répétition.
class _BlocDate extends StatelessWidget {
  final DateTime date;
  final bool annulee;
  const _BlocDate({required this.date, this.annulee = false});

  static const _jours = ['LUN', 'MAR', 'MER', 'JEU', 'VEN', 'SAM', 'DIM'];

  @override
  Widget build(BuildContext context) {
    final aujourdhui = dateSansHeure(DateTime.now()) == dateSansHeure(date);
    final fond = annulee
        ? Colors.grey.shade200
        : aujourdhui
        ? CouleursChorale.or
        : CouleursChorale.lavande;
    final texte = annulee
        ? Colors.grey
        : aujourdhui
        ? CouleursChorale.aubergineFonce
        : CouleursChorale.aubergine;
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _jours[date.weekday - 1],
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: texte,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: texte,
              height: 1.1,
            ),
          ),
          Text(
            libelleMois(date).substring(0, 3).toUpperCase(),
            style: TextStyle(fontSize: 10, color: texte),
          ),
        ],
      ),
    );
  }
}

class _Etiquette extends StatelessWidget {
  final String texte;
  final Color couleur;
  const _Etiquette({required this.texte, required this.couleur});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texte,
        style: TextStyle(
          fontSize: 12,
          color: couleur,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// La prochaine répétition, mise en avant, avec réponse en un geste.
class _CarteProchaine extends StatelessWidget {
  final Repetition rep;
  final String reponse;
  final VoidCallback onOuvrir;

  const _CarteProchaine({
    required this.rep,
    required this.reponse,
    required this.onOuvrir,
  });

  static const _jours = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche',
  ];

  String get _quand {
    final jours = dateSansHeure(
      rep.date,
    ).difference(dateSansHeure(DateTime.now())).inDays;
    return switch (jours) {
      0 => 'Aujourd’hui',
      1 => 'Demain',
      _ => 'Dans $jours jours',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [CouleursChorale.aubergine, CouleursChorale.aubergineFonce],
          ),
        ),
        child: InkWell(
          onTap: onOuvrir,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PROCHAINE RÉPÉTITION',
                      style: TextStyle(
                        color: CouleursChorale.or,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: CouleursChorale.or,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _quand,
                        style: const TextStyle(
                          color: CouleursChorale.aubergineFonce,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_jours[rep.date.weekday - 1]} ${rep.date.day} '
                  '${nomsMois[rep.date.month - 1]}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                infosRepetition(rep, couleur: Colors.white70),
                if (rep.raison.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    rep.raison,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Votre réponse',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _BoutonReponse(
                      'present',
                      'Je viens',
                      Icons.check,
                      reponse,
                      rep.id,
                    ),
                    const SizedBox(width: 8),
                    _BoutonReponse(
                      'retard',
                      'En retard',
                      Icons.schedule,
                      reponse,
                      rep.id,
                    ),
                    const SizedBox(width: 8),
                    _BoutonReponse(
                      'absent',
                      'Absent',
                      Icons.close,
                      reponse,
                      rep.id,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BoutonReponse extends StatelessWidget {
  final String valeur;
  final String texte;
  final IconData icone;
  final String reponseActuelle;
  final String repetitionId;

  const _BoutonReponse(
    this.valeur,
    this.texte,
    this.icone,
    this.reponseActuelle,
    this.repetitionId,
  );

  @override
  Widget build(BuildContext context) {
    final choisi = reponseActuelle == valeur;
    final couleur = choisi ? CouleursChorale.aubergineFonce : Colors.white;
    return Expanded(
      child: Material(
        color: choisi
            ? CouleursChorale.or
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: choisi
              ? null
              : () => enregistrerIntention(repetitionId, valeur).catchError((
                  _,
                ) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Réponse non enregistrée : réessayez.'),
                      ),
                    );
                  }
                }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Icon(icone, size: 20, color: couleur),
                const SizedBox(height: 2),
                Text(
                  texte,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: couleur,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Verset du jour, en haut de l'écran des répétitions.
class _CarteVerset extends StatelessWidget {
  final Verset verset;
  const _CarteVerset({required this.verset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CouleursChorale.or.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book, size: 18, color: CouleursChorale.or),
              SizedBox(width: 8),
              Text(
                'VERSET DU JOUR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: CouleursChorale.aubergineClair,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '« ${verset.texte} »',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              fontStyle: FontStyle.italic,
              color: Color(0xFF2B2233),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              verset.reference,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: CouleursChorale.aubergine,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// « 🎂 Joyeux anniversaire à … » le jour J (rien les autres jours).
class _BandeauAnniversaires extends StatefulWidget {
  const _BandeauAnniversaires();

  @override
  State<_BandeauAnniversaires> createState() => _BandeauAnniversairesState();
}

class _BandeauAnniversairesState extends State<_BandeauAnniversaires> {
  // Créé une seule fois : la liste se reconstruit souvent.
  final _flux = ecouterAnniversaires();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Anniversaire>>(
      stream: _flux,
      builder: (context, snap) {
        final aujourdhui = anniversairesDuJour(
          snap.data ?? const [],
          DateTime.now(),
        );
        if (aujourdhui.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: CouleursChorale.or.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AnniversairesScreen()),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Text('🎂', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Joyeux anniversaire à '
                        '${aujourdhui.map((a) => a.nom).join(' et ')} !',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: CouleursChorale.aubergineFonce,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
