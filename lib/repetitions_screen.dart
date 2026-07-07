import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'repetition_model.dart';
import 'presence_screen.dart';
import 'profile_screen.dart';
class RepetitionsScreen extends StatelessWidget {
  final String role;
  const RepetitionsScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Répétitions'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          if (role == 'chef')
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Générer les répétitions du mois',
              onPressed: () => _showGenerateDialog(context),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
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
                  Text('Aucune répétition pour le moment',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          final repetitions = snapshot.data!.docs
              .map((doc) => Repetition.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: repetitions.length,
            itemBuilder: (context, index) {
              final rep = repetitions[index];
              final isAnnulee = rep.statut == 'annulé';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PresenceScreen(
                          repetitionId: rep.id,
                          repetitionTitre: rep.titre,
                          role: role,
                          chansons: rep.chansons,
                          raison: rep.raison,
                        ),
                      ),
                    );
                  },
                  leading: CircleAvatar(
                    backgroundColor:
                        isAnnulee ? Colors.grey : Colors.deepPurple,
                    child: const Icon(Icons.music_note, color: Colors.white),
                  ),
                  title: Text(rep.titre,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${rep.date.day}/${rep.date.month}/${rep.date.year} à ${rep.heure}\n${rep.lieu}'
                    '${rep.raison.isNotEmpty ? '\nMotif : ${rep.raison}' : ''}'
                    '${isAnnulee && rep.causeAnnulation.isNotEmpty ? '\nAnnulée : ${rep.causeAnnulation}' : ''}',
                  ),
                  isThreeLine: true,
                  trailing: role == 'chef'
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAnnulee)
                              const Chip(
                                label: Text('Annulé',
                                    style: TextStyle(color: Colors.white)),
                                backgroundColor: Colors.red,
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _showEditDialog(context, rep),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () =>
                                  _showDeleteOptions(context, rep),
                            ),
                          ],
                        )
                      : (isAnnulee
                          ? const Chip(
                              label: Text('Annulé',
                                  style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.red,
                            )
                          : null),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: role == 'chef'
          ? FloatingActionButton(
              backgroundColor: Colors.deepPurple,
              child: const Icon(Icons.add, color: Colors.white),
              onPressed: () => _showCreateDialog(context),
            )
          : null,
    );
  }

  void _showGenerateDialog(BuildContext context) {
    final now = DateTime.now();
    final endOfMonth = DateTime(now.year, now.month + 1, now.day);

    // Générer toutes les dates
    List<Map<String, dynamic>> repetitionsToCreate = [];

    DateTime current = now;
    while (current.isBefore(endOfMonth)) {
      // Jeudi = 4, Samedi = 6, Dimanche = 7
      if (current.weekday == DateTime.thursday) {
        repetitionsToCreate.add({
          'date': current,
          'heure': '18h00',
          'jour': 'Jeudi',
          'confirmed': true,
          'isDimanche': false,
        });
      } else if (current.weekday == DateTime.saturday) {
        repetitionsToCreate.add({
          'date': current,
          'heure': '14h00',
          'jour': 'Samedi',
          'confirmed': true,
          'isDimanche': false,
        });
      } else if (current.weekday == DateTime.sunday) {
        repetitionsToCreate.add({
          'date': current,
          'heure': '14h00',
          'jour': 'Dimanche',
          'confirmed': false, // nécessite confirmation
          'isDimanche': true,
        });
      }
      current = current.add(const Duration(days: 1));
    }

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
                const Text(
                  'Cochez les répétitions à créer. Les dimanches nécessitent une confirmation.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: repetitionsToCreate.length,
                    itemBuilder: (context, index) {
                      final rep = repetitionsToCreate[index];
                      final date = rep['date'] as DateTime;
                      final isDimanche = rep['isDimanche'] as bool;
                      final confirmed = rep['confirmed'] as bool;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: isDimanche
                              ? Colors.orange.shade50
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDimanche ? Colors.orange : Colors.green,
                            width: 0.5,
                          ),
                        ),
                        child: CheckboxListTile(
                          dense: true,
                          value: confirmed,
                          activeColor:
                              isDimanche ? Colors.orange : Colors.green,
                          onChanged: (val) {
                            setState(() {
                              repetitionsToCreate[index]['confirmed'] = val!;
                            });
                          },
                          title: Text(
                            '${rep['jour']} ${date.day}/${date.month}/${date.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: isDimanche
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Text(
                                rep['heure'],
                                style: const TextStyle(fontSize: 11),
                              ),
                              if (isDimanche) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'À confirmer',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10),
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
                backgroundColor: Colors.deepPurple,
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

                  // Vérifier si la répétition existe déjà
                  final existing = await FirebaseFirestore.instance
                      .collection('repetitions')
                      .where(
                        'date',
                        isEqualTo: Timestamp.fromDate(
                          DateTime(date.year, date.month, date.day),
                        ),
                      )
                      .get();

                  if (existing.docs.isEmpty) {
                    await FirebaseFirestore.instance
                        .collection('repetitions')
                        .add({
                      'titre':
                          'Répétition du ${rep['jour']} ${date.day}/${date.month}',
                      'date': Timestamp.fromDate(
                          DateTime(date.year, date.month, date.day)),
                      'heure': rep['heure'],
                      'lieu': 'Salle de répétition',
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
                          '$created répétition(s) créée(s) avec succès !'),
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (titreController.text.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('repetitions')
                    .add({
                  'titre': titreController.text.trim(),
                  'date': Timestamp.fromDate(selectedDate),
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
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('repetitions')
                    .doc(rep.id)
                    .update({
                  'titre': titreController.text.trim(),
                  'date': Timestamp.fromDate(selectedDate),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Que veux-tu faire ?'),
        content: const Text(
          'Tu peux annuler cette répétition (elle reste visible avec un motif) '
          'ou la supprimer définitivement (elle disparaît complètement).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
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
              Navigator.pop(context);
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

  void _showDeleteConfirm(BuildContext context, Repetition rep) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suppression définitive'),
        content: Text(
          'Voulez-vous vraiment supprimer "${rep.titre}" ? '
          'Cette action est irréversible et effacera aussi les présences liées.',
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
              await FirebaseFirestore.instance
                  .collection('repetitions')
                  .doc(rep.id)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
