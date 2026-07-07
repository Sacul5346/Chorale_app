import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'conversation_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages & Excuses'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('conversations')
            .orderBy('lastSentAt', descending: true)
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
                  Icon(Icons.message_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucune conversation pour le moment',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('users').get(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final usersById = <String, Map<String, dynamic>>{};
              for (var doc in userSnapshot.data!.docs) {
                usersById[doc.id] = doc.data() as Map<String, dynamic>;
              }

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('repetitions')
                    .get(),
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
                      final membreId = conv['membreId'];
                      final repId = conv['repetitionId'];
                      final userData = usersById[membreId];
                      final nom = userData?['Nom'] ?? 'Inconnu';
                      final photoBase64 = userData?['photoBase64'];
                      final repTitre = repsById[repId] ?? 'Répétition';
                      final lastMessage = conv['lastMessage'] ?? '';
                      final unread = conv['unreadByResponsable'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.shade100,
                            backgroundImage: photoBase64 != null
                                ? MemoryImage(base64Decode(photoBase64))
                                : null,
                            child: photoBase64 == null
                                ? Text(
                                    nom[0].toUpperCase(),
                                    style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          title: Text(
                            nom,
                            style: TextStyle(
                              fontWeight: unread
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            '$repTitre\n$lastMessage',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: unread ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          isThreeLine: true,
                          trailing: unread
                              ? const Icon(Icons.circle,
                                  color: Colors.orange, size: 12)
                              : const Icon(Icons.chevron_right,
                                  color: Colors.grey),
                          onTap: () async {
                            // Marquer comme lu par le responsable
                            await conv.reference
                                .update({'unreadByResponsable': false});

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConversationScreen(
                                    repetitionId: repId,
                                    repetitionTitre: repTitre,
                                    membreId: membreId,
                                    membreNom: nom,
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      );
                    },
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