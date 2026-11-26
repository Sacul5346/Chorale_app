import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'conversation_screen.dart';
import 'messagerie.dart';
import 'theme.dart';

/// Excuses du membre connecté, les plus récentes d'abord ; une pastille
/// signale une réponse du chef pas encore lue.
class MesConversationsScreen extends StatefulWidget {
  const MesConversationsScreen({super.key});

  @override
  State<MesConversationsScreen> createState() => _MesConversationsScreenState();
}

const _police = 'Poppins';

/// Mes conversations (la règle Firestore exige le filtre sur le membre).
Query<Map<String, dynamic>> _mesConversations(String uid) => FirebaseFirestore
    .instance
    .collection('conversations')
    .where('membreId', isEqualTo: uid);

class _MesConversationsScreenState extends State<MesConversationsScreen> {
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  /// Titres des répétitions concernées (chargés une fois, sans toute la base).
  final _titres = <String, String>{};
  final _demandes = <String>{};

  Future<void> _chargerTitres(Iterable<String> ids) async {
    final manquants = ids.where(_demandes.add).toList();
    for (var i = 0; i < manquants.length; i += 30) {
      final paquet = manquants.skip(i).take(30).toList();
      try {
        final snap = await FirebaseFirestore.instance
            .collection('repetitions')
            .where(FieldPath.documentId, whereIn: paquet)
            .get();
        for (final d in snap.docs) {
          _titres[d.id] = d.data()['titre'] is String
              ? d.data()['titre'] as String
              : 'Répétition';
        }
        // Absente de la base : la répétition a été supprimée depuis.
        for (final id in paquet.where((id) => !_titres.containsKey(id))) {
          _titres[id] = repetitionSupprimee;
        }
      } catch (_) {
        _demandes.removeAll(paquet); // hors connexion : réessai plus tard
      }
    }
    if (mounted && manquants.isNotEmpty) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursChorale.creme,
      appBar: AppBar(title: const Text('Mes excuses')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _mesConversations(_uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          // Tri sur le téléphone : un tri côté serveur exigerait un index.
          final convs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final ta = a.data()['lastSentAt'], tb = b.data()['lastSentAt'];
              if (ta is! Timestamp) return -1; // en cours d'envoi : en haut
              if (tb is! Timestamp) return 1;
              return tb.compareTo(ta);
            });
          if (convs.isEmpty) return _vide();
          _chargerTitres(
            convs
                .map((d) => d.data()['repetitionId'])
                .whereType<String>()
                .toSet(),
          );

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemCount: convs.length,
            itemBuilder: (_, i) => _carte(convs[i].data()),
          );
        },
      ),
    );
  }

  Widget _vide() => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 56,
            color: CouleursChorale.aubergineClair,
          ),
          SizedBox(height: 12),
          Text(
            'Aucune excuse pour le moment.\nOuvrez une répétition puis 💬 '
            'pour prévenir le chef.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _police,
              color: CouleursChorale.aubergineClair,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _carte(Map<String, dynamic> c) {
    final repId = c['repetitionId'] as String? ?? '';
    final titre = _titres[repId] ?? '…';
    final nonLu = c['unreadByMembre'] == true;
    final dernier = c['lastMessage'] is String
        ? c['lastMessage'] as String
        : '';
    final date = c['lastSentAt'] is Timestamp
        ? dateCourte((c['lastSentAt'] as Timestamp).toDate(), DateTime.now())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: nonLu ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: nonLu ? CouleursChorale.or : CouleursChorale.bordure,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const CircleAvatar(
          backgroundColor: CouleursChorale.aubergine,
          child: Icon(Icons.event_note, color: Colors.white, size: 20),
        ),
        title: Text(
          titre,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: _police,
            fontWeight: nonLu ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        subtitle: Text(
          nonLu ? 'Nouvelle réponse du chef' : dernier,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: _police,
            fontSize: 13,
            color: nonLu ? CouleursChorale.aubergine : Colors.grey.shade600,
            fontWeight: nonLu ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              date,
              style: const TextStyle(
                fontFamily: _police,
                fontSize: 11.5,
                color: CouleursChorale.aubergineClair,
              ),
            ),
            if (nonLu) ...[
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: CouleursChorale.or,
                ),
              ),
            ],
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ConversationScreen(
              repetitionId: repId,
              repetitionTitre: titre,
              membreId: _uid,
              membreNom: 'Moi',
            ),
          ),
        ),
      ),
    );
  }
}

/// Icône de l'onglet « Mes excuses » avec le nombre de réponses du chef
/// pas encore lues.
class IconeMesExcuses extends StatelessWidget {
  const IconeMesExcuses({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Icon(Icons.message);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _mesConversations(
        uid,
      ).where('unreadByMembre', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        final n = snapshot.data?.docs.length ?? 0;
        return Badge(
          isLabelVisible: n > 0,
          label: Text('$n'),
          child: const Icon(Icons.message),
        );
      },
    );
  }
}
