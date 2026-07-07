import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'conversation_screen.dart';

class MesConversationsScreen extends StatelessWidget {
  const MesConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes excuses'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .where('membreId', isEqualTo: currentUid)
            .snapshots(),
        builder: (context, convSnapshot) {
          if (!convSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = convSnapshot.data!.docs;

          if (conversations.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucune conversation pour le moment',
                      style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 8),
                  Text(
                    'Ouvre une répétition et envoie\nune excuse au responsable',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<QuerySnapshot>(
            future:
                FirebaseFirestore.instance.collection('repetitions').get(),
            builder: (context, repSnapshot) {
              if (!repSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final repsById = <String, String>{};
              for (var doc in repSnapshot.data!.docs) {
                repsById[doc.id] = doc['titre'] ?? 'Sans titre';
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: conversations.length,
                itemBuilder: (context, index) {
                  final conv = conversations[index];
                  final repId = conv['repetitionId'];
                  final repTitre = repsById[repId] ?? 'Répétition';
                  final lastMessage = conv['lastMessage'] ?? '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.music_note, color: Colors.white),
                      ),
                      title: Text(repTitre,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              repetitionId: repId,
                              repetitionTitre: repTitre,
                              membreId: currentUid,
                              membreNom: 'Moi',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}