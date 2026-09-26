import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Lecture des paroles pour tous les rôles (lecture seule).
/// Le texte se fait défiler au doigt ; A- / A+ changent la taille.
class LyricsViewScreen extends StatefulWidget {
  final String songId;
  final String titre;

  const LyricsViewScreen({
    super.key,
    required this.songId,
    required this.titre,
  });

  @override
  State<LyricsViewScreen> createState() => _LyricsViewScreenState();
}

class _LyricsViewScreenState extends State<LyricsViewScreen> {
  double _taille = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Réduire le texte',
            icon: const Icon(Icons.text_decrease),
            onPressed: _taille > 14
                ? () => setState(() => _taille -= 2)
                : null,
          ),
          IconButton(
            tooltip: 'Agrandir le texte',
            icon: const Icon(Icons.text_increase),
            onPressed: _taille < 40
                ? () => setState(() => _taille += 2)
                : null,
          ),
        ],
      ),
      // Flux sur la chanson : une correction du gestionnaire de paroles
      // apparaît directement.
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('songs')
            .doc(widget.songId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Impossible de charger les paroles.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final paroles = data['lyrics'] is String
              ? (data['lyrics'] as String).trim()
              : '';
          final artiste = data['artist'] is String ? data['artist'] as String : '';
          final region = data['region'] is String ? data['region'] as String : '';

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            children: [
              if (artiste.isNotEmpty || region.isNotEmpty)
                Text(
                  [artiste, region].where((s) => s.isNotEmpty).join(' · '),
                  style: const TextStyle(color: Colors.grey),
                ),
              const SizedBox(height: 16),
              if (paroles.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Text(
                    'Les paroles de cette chanson n\'ont pas encore été '
                    'ajoutées.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                )
              else
                SelectableText(
                  paroles,
                  style: TextStyle(fontSize: _taille, height: 1.5),
                ),
            ],
          );
        },
      ),
    );
  }
}
