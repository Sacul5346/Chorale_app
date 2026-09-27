import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'conversation_screen.dart';
import 'theme.dart';

class MessagesScreen extends StatelessWidget {
  /// Le chef consulte les excuses sans les marquer comme lues : le badge
  /// « non lu » reste pour le responsable, qui y répond.
  final bool marquerLu;

  const MessagesScreen({super.key, this.marquerLu = true});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages & Excuses')),
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
                  Text(
                    'Aucune conversation pour le moment',
                    style: TextStyle(color: Colors.grey),
                  ),
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
                    repsById[doc.id] =
                        (doc.data() as Map<String, dynamic>)['titre']
                            as String? ??
                        'Sans titre';
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conv = conversations[index];
                      final convData = conv.data() as Map<String, dynamic>;
                      final membreId = convData['membreId'];
                      final repId = convData['repetitionId'];
                      final userData = usersById[membreId];
                      final nomBrut = userData?['Nom'];
                      final nom = nomBrut is String && nomBrut.trim().isNotEmpty
                          ? nomBrut.trim()
                          : 'Inconnu';
                      final photoBase64 = userData?['photoBase64'];
                      final repTitre = repsById[repId] ?? 'Répétition';
                      final lastMessage = convData['lastMessage'] ?? '';
                      final unread = convData['unreadByResponsable'] == true;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: CouleursChorale.lavandeFonce,
                            backgroundImage: photoBase64 != null
                                ? MemoryImage(base64Decode(photoBase64))
                                : null,
                            child: photoBase64 == null
                                ? Text(
                                    nom[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: CouleursChorale.aubergine,
                                      fontWeight: FontWeight.bold,
                                    ),
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
                              ? const Icon(
                                  Icons.circle,
                                  color: Colors.orange,
                                  size: 12,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey,
                                ),
                          onTap: () async {
                            // Marquer comme lu par le responsable
                            if (marquerLu) {
                              await conv.reference.update({
                                'unreadByResponsable': false,
                              });
                            }

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
