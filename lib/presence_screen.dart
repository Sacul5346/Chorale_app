import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'conversation_screen.dart';

class PresenceScreen extends StatelessWidget {
  final String repetitionId;
  final String repetitionTitre;
  final String role;
  final String chansons;
  final String raison;

  const PresenceScreen({
    super.key,
    required this.repetitionId,
    required this.repetitionTitre,
    required this.role,
    this.chansons = '',
    this.raison = '',
  });

  @override
  Widget build(BuildContext context) {
    final canManage = role == 'responsable' || role == 'chef';
    final canEdit = role == 'responsable'; // seul le responsable peut modifier

    return Scaffold(
      appBar: AppBar(
        title: Text(repetitionTitre),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined),
            onPressed: () {
              final currentUid = FirebaseAuth.instance.currentUser!.uid;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ConversationScreen(
                    repetitionId: repetitionId,
                    repetitionTitre: repetitionTitre,
                    membreId: currentUid,
                    membreNom: 'Moi',
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Bloc infos répétition (raison + chansons) visible par tous
          if (raison.isNotEmpty || chansons.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.deepPurple.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (raison.isNotEmpty) ...[
                    const Text(
                      'Motif de la répétition',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(raison),
                    const SizedBox(height: 12),
                  ],
                  if (chansons.isNotEmpty) ...[
                    const Text(
                      '🎵 Chansons à répéter',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    ...chansons.split('\n').where((c) => c.trim().isNotEmpty).map(
                          (chanson) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text('• ${chanson.trim()}'),
                          ),
                        ),
                  ],
                ],
              ),
            ),

          // Bloc présence du membre lui-même (visible par tous)
          _MyPresenceCard(repetitionId: repetitionId),

          const Divider(height: 1),

          // Tableau des présences (visible par responsable et chef)
          if (canManage)
            Expanded(
              child: _AllPresencesTable(
                repetitionId: repetitionId,
                canEdit: canEdit,
              ),
            )
          else
            const Expanded(
              child: Center(
                child: Text(
                  'Seul le responsable peut voir les présences de tous.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------
// Présence : deux informations séparées dans chaque document
//  - `intention` : ce que le membre annonce (present | absent | retard)
//  - `statut`    : ce que le responsable constate (present_heure, ...)
// ----------------------------------------------------------
const _intentions = ['present', 'absent', 'retard'];

/// Intention annoncée par le membre. Les anciens documents la stockaient
/// dans `statut` : on la relit à cet endroit si besoin.
String _intentionOf(Map<String, dynamic> data) {
  final intention = data['intention'];
  if (intention is String) return intention;
  final ancien = data['statut'];
  return _intentions.contains(ancien) ? ancien as String : '';
}

/// Présence constatée par le responsable (vide si pas encore marquée).
String _statutOf(Map<String, dynamic> data) {
  final statut = data['statut'];
  return statut is String && !_intentions.contains(statut) ? statut : '';
}

String _intentionLabel(String intention) {
  switch (intention) {
    case 'present':
      return 'Je viens ✅';
    case 'absent':
      return 'Je ne viens pas ❌';
    case 'retard':
      return 'Je serai en retard ⏳';
    default:
      return 'Pas encore répondu';
  }
}

String _statusLabel(String statut) {
  switch (statut) {
    case 'present_heure':
      return 'Présent à l\'heure ✅';
    case 'present_retard':
      return 'Présent en retard ⏳';
    case 'present_retard_excuse':
      return 'Présent en retard (excuse) ⏳📝';
    case 'present_retard_sans_excuse':
      return 'Présent en retard (sans excuse) ⏳❌';
    case 'absent_excuse':
      return 'Absent avec excuse 📝';
    case 'absent_sans_excuse':
      return 'Absent sans excuse ❌';
    default:
      return 'Pas encore marqué';
  }
}

Color _statusColor(String statut) {
  switch (statut) {
    case 'present_heure':
      return Colors.green;
    case 'present_retard':
    case 'present_retard_excuse':
      return Colors.orange;
    case 'present_retard_sans_excuse':
      return Colors.orange.shade900;
    case 'absent_excuse':
      return Colors.red;
    case 'absent_sans_excuse':
      return Colors.red.shade900;
    default:
      return Colors.grey;
  }
}

// ----------------------------------------------------------
// Carte "Ma présence" — pour le membre connecté
// ----------------------------------------------------------
class _MyPresenceCard extends StatelessWidget {
  final String repetitionId;
  const _MyPresenceCard({required this.repetitionId});

  /// Le membre n'écrit que son intention : il ne touche jamais au `statut`
  /// validé par le responsable.
  Future<void> _setIntention(String intention) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final query = await FirebaseFirestore.instance
        .collection('presences')
        .where('repetitionId', isEqualTo: repetitionId)
        .where('userId', isEqualTo: uid)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('presences').add({
        'userId': uid,
        'repetitionId': repetitionId,
        'intention': intention,
        'intentionAt': FieldValue.serverTimestamp(),
      });
    } else {
      final doc = query.docs.first;
      await doc.reference.update({
        'intention': intention,
        'intentionAt': FieldValue.serverTimestamp(),
        // Ancien format : l'intention était rangée dans `statut`.
        if (_intentions.contains(doc.data()['statut']))
          'statut': FieldValue.delete(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('presences')
          .where('repetitionId', isEqualTo: repetitionId)
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        var intention = '';
        var statut = '';
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final data = snapshot.data!.docs.first.data();
          intention = _intentionOf(data);
          statut = _statutOf(data);
        }

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.deepPurple.shade50,
          child: Column(
            children: [
              Text(
                'Ma réponse : ${_intentionLabel(intention)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (statut.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Constaté par le responsable : ${_statusLabel(statut)}',
                  style: TextStyle(
                    color: _statusColor(statut),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatusButton(
                    label: 'Je viens',
                    color: Colors.green,
                    icon: Icons.check_circle,
                    selected: intention == 'present',
                    onTap: () => _setIntention('present'),
                  ),
                  _StatusButton(
                    label: 'Absent',
                    color: Colors.red,
                    icon: Icons.cancel,
                    selected: intention == 'absent',
                    onTap: () => _setIntention('absent'),
                  ),
                  _StatusButton(
                    label: 'En retard',
                    color: Colors.orange,
                    icon: Icons.access_time,
                    selected: intention == 'retard',
                    onTap: () => _setIntention('retard'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _StatusButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : color,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------
// Tableau de toutes les présences — pour responsable / chef
// ----------------------------------------------------------
class _AllPresencesTable extends StatefulWidget {
  final String repetitionId;
  final bool canEdit;
  const _AllPresencesTable({
    required this.repetitionId,
    required this.canEdit,
  });

  @override
  State<_AllPresencesTable> createState() => _AllPresencesTableState();
}

class _AllPresencesTableState extends State<_AllPresencesTable> {
  // Chargé une seule fois : sinon tous les utilisateurs (photos comprises)
  // seraient retéléchargés à chaque changement de présence.
  late final Future<QuerySnapshot<Map<String, dynamic>>> _usersFuture =
      FirebaseFirestore.instance.collection('users').get();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('presences')
          .where('repetitionId', isEqualTo: widget.repetitionId)
          .snapshots(),
      builder: (context, presenceSnapshot) {
        if (!presenceSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final presencesByUser = <String, Map<String, dynamic>>{};
        for (var doc in presenceSnapshot.data!.docs) {
          final data = doc.data();
          final userId = data['userId'];
          if (userId is String) presencesByUser[userId] = data;
        }

        return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
          future: _usersFuture,
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            // Les comptes désactivés n'apparaissent que s'ils ont déjà
            // une présence enregistrée pour cette répétition.
            final users = userSnapshot.data!.docs
                .where((u) =>
                    u.data()['actif'] != false ||
                    presencesByUser.containsKey(u.id))
                .toList();

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final presence = presencesByUser[user.id] ?? const {};
                final statut = _statutOf(presence);
                final intention = _intentionOf(presence);
                final nomBrut = user.data()['Nom'];
                final nom = nomBrut is String && nomBrut.trim().isNotEmpty
                    ? nomBrut.trim()
                    : 'Sans nom';

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // En-tête membre
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _statusColor(statut),
                              child: Text(
                                nom[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nom,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  if (statut.isNotEmpty)
                                    Text(
                                      _statusLabel(statut),
                                      style: TextStyle(
                                        color: _statusColor(statut),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else
                                    const Text(
                                      'Pas encore marqué',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  Text(
                                    'Réponse du membre : '
                                    '${_intentionLabel(intention)}',
                                    style: const TextStyle(
                                        color: Colors.black54, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Boutons d'action (responsable uniquement)
                        if (widget.canEdit) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              // Bouton PRÉSENT
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.green, width: 1),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '✅ Présent',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SubButton(
                                            label: 'À l\'heure',
                                            selected: statut ==
                                                'present_heure',
                                            color: Colors.green,
                                            onTap: () => _updateStatus(
                                                user.id, 'present_heure'),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: _SubButton(
                                            label: 'En retard',
                                            selected:
                                                statut.startsWith('present_retard'),
                                            color: Colors.orange,
                                            onTap: () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('En retard : excuse ?'),
                                                  content: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      const Text(
                                                        'Retard avec excuse ou sans excuse :',
                                                      ),
                                                      const SizedBox(height: 16),
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: _SubButton(
                                                              label: 'Avec excuse',
                                                              selected: statut ==
                                                                  'present_retard_excuse',
                                                              color: Colors.orange,
                                                              onTap: () {
                                                                Navigator.pop(context);
                                                                _updateStatus(
                                                                  user.id,
                                                                  'present_retard_excuse',
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: _SubButton(
                                                              label: 'Sans excuse',
                                                              selected: statut ==
                                                                  'present_retard_sans_excuse',
                                                              color: Colors.orange.shade900,
                                                              onTap: () {
                                                                Navigator.pop(context);
                                                                _updateStatus(
                                                                  user.id,
                                                                  'present_retard_sans_excuse',
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Bouton ABSENT
                              Expanded(
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.red, width: 1),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '❌ Absent',
                                          style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SubButton(
                                            label: 'Avec exc.',
                                            selected: statut ==
                                                'absent_excuse',
                                            color: Colors.red,
                                            onTap: () => _updateStatus(
                                                user.id, 'absent_excuse'),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: _SubButton(
                                            label: 'Sans exc.',
                                            selected: statut ==
                                                'absent_sans_excuse',
                                            color: Colors.red.shade900,
                                            onTap: () => _updateStatus(
                                                user.id,
                                                'absent_sans_excuse'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _updateStatus(String userId, String statut) async {
    final query = await FirebaseFirestore.instance
        .collection('presences')
        .where('repetitionId', isEqualTo: widget.repetitionId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    final currentUser = FirebaseAuth.instance.currentUser!.uid;

    if (query.docs.isEmpty) {
      await FirebaseFirestore.instance.collection('presences').add({
        'userId': userId,
        'repetitionId': widget.repetitionId,
        'statut': statut,
        'valideePar': currentUser,
        'confirmedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = query.docs.first.data();
      await query.docs.first.reference.update({
        'statut': statut,
        'valideePar': currentUser,
        'confirmedAt': FieldValue.serverTimestamp(),
        // Ancien format : on garde l'intention du membre avant de l'écraser.
        if (data['intention'] == null && _intentionOf(data).isNotEmpty)
          'intention': _intentionOf(data),
      });
    }
  }

}

// Bouton sous-choix
class _SubButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _SubButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color, width: 1),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
