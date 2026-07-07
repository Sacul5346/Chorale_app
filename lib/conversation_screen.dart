import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConversationScreen extends StatefulWidget {
  final String repetitionId;
  final String repetitionTitre;
  final String membreId;
  final String membreNom;

  const ConversationScreen({
    super.key,
    required this.repetitionId,
    required this.repetitionTitre,
    required this.membreId,
    required this.membreNom,
  });

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  // ID unique de la conversation : repId_membreId
  String get convId => '${widget.repetitionId}_${widget.membreId}';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final texte = _messageController.text.trim();
    if (texte.isEmpty) return;

    debugPrint('ConvId: $convId');
    debugPrint('RepetitionId: ${widget.repetitionId}');
    debugPrint('MembreId: ${widget.membreId}');

    _messageController.clear();

    final senderId = FirebaseAuth.instance.currentUser!.uid;

    // Créer ou mettre à jour le document de conversation
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .set({
      'repetitionId': widget.repetitionId,
      'membreId': widget.membreId,
      'lastMessage': texte,
      'lastSentAt': FieldValue.serverTimestamp(),
      'unreadByResponsable': senderId == widget.membreId,
    }, SetOptions(merge: true));

    // Ajouter le message dans la sous-collection
    await FirebaseFirestore.instance
        .collection('conversations')
        .doc(convId)
        .collection('messages')
        .add({
      'texte': texte,
      'senderId': senderId,
      'lu': false,
      'sentAt': FieldValue.serverTimestamp(),
    });

    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.membreNom,
                style: const TextStyle(fontSize: 16)),
            Text(widget.repetitionTitre,
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(convId)
                  .collection('messages')
                  .orderBy('sentAt', descending: false)
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
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Aucun message pour le moment',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                // Marquer les messages comme lus
                for (var msg in messages) {
                  if (msg['senderId'] != currentUid && msg['lu'] == false) {
                    msg.reference.update({'lu': true});
                  }
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(
                        _scrollController.position.maxScrollExtent);
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['senderId'] == currentUid;
                    final isResponsable = msg['senderId'] != widget.membreId;

                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.7,
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Colors.deepPurple
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  isResponsable
                                      ? 'Responsable'
                                      : widget.membreNom,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade300,
                                  ),
                                ),
                              ),
                            Text(
                              msg['texte'] ?? '',
                              style: TextStyle(
                                color: isMe
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Zone de saisie
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Écris un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.send,
                        color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}