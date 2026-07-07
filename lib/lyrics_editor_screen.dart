import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LyricsEditorScreen extends StatefulWidget {
  final String songId;
  final Map<String, dynamic> songData;

  const LyricsEditorScreen({
    super.key,
    required this.songId,
    required this.songData,
  });

  @override
  State<LyricsEditorScreen> createState() => _LyricsEditorScreenState();
}

class _LyricsEditorScreenState extends State<LyricsEditorScreen> {
  late TextEditingController _lyricsController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _lyricsController = TextEditingController(
      text: widget.songData['lyrics'] ?? '',
    );
  }

  @override
  void dispose() {
    _lyricsController.dispose();
    super.dispose();
  }

  Future<void> _saveLyrics() async {
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({
        'lyrics': _lyricsController.text,
        'updatedAt': DateTime.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lyrics sauvegardées avec succès')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Éditer: ${widget.songData['title']}'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveLyrics,
          ),
        ],
      ),
      body: Column(
        children: [
          // En-tête avec infos de la chanson
          Container(
            color: Colors.deepPurple.withValues(alpha: 0.1),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songData['title'] ?? 'Sans titre',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  widget.songData['artist'] ?? 'Artiste inconnu',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Région: ${widget.songData['region']}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          // Éditeur de lyrics
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _lyricsController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Entrez les lyrics ici...\n\nConseil: Séparez les couplets par des lignes vides',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
          ),
          // Bouton de sauvegarde
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveLyrics,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Sauvegarder les lyrics'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
