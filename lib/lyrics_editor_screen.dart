import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'playback.dart';
import 'theme.dart';

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
  late String _playback = widget.songData['playbackUrl'] is String
      ? widget.songData['playbackUrl'] as String
      : '';

  @override
  void initState() {
    super.initState();
    _lyricsController = TextEditingController(
      text: widget.songData['lyrics'] ?? '',
    );
  }

  /// Ajout / modification / suppression du lien Google Drive du playback.
  /// Enregistré tout de suite, indépendamment des paroles.
  Future<void> _editerPlayback() async {
    final controller = TextEditingController(text: _playback);
    String? erreur;

    final resultat = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Playback (Google Drive)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dans l’application Google Drive, sur le fichier audio :\n'
                  '1. ⋮ puis « Partager » (ou « Gérer l’accès »)\n'
                  '2. Accès général : « Tous les utilisateurs disposant du '
                  'lien »\n'
                  '3. « Copier le lien », puis collez-le ci-dessous.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Lien Google Drive',
                    border: const OutlineInputBorder(),
                    errorText: erreur,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conseil : un fichier léger (moins de 3 Mo) se charge plus '
                  'vite pour les membres.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            if (_playback.isNotEmpty)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () => Navigator.pop(dialogContext, ''),
                child: const Text('Supprimer'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                final lien = controller.text.trim();
                if (idFichierDrive(lien) == null) {
                  setDialogState(
                    () => erreur =
                        'Ce n’est pas un lien de fichier Google Drive.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, lien);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (resultat == null || resultat == _playback) return;

    try {
      await FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .update({
            'playbackUrl': resultat.isEmpty ? FieldValue.delete() : resultat,
            'updatedAt': DateTime.now(),
          });
      if (!mounted) return;
      setState(() => _playback = resultat);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultat.isEmpty
                ? 'Playback supprimé'
                : 'Playback enregistré : appuyez sur ▶ pour le tester',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
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
            color: CouleursChorale.lavande,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.songData['title'] ?? 'Sans titre',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.songData['artist'] ?? 'Artiste inconnu',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Région: ${widget.songData['region'] ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.headphones,
                      size: 20,
                      color: _playback.isEmpty
                          ? Colors.grey
                          : CouleursChorale.aubergine,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _playback.isEmpty
                            ? 'Aucun playback'
                            : 'Playback Google Drive ajouté',
                      ),
                    ),
                    TextButton(
                      onPressed: _isLoading ? null : _editerPlayback,
                      child: Text(_playback.isEmpty ? 'Ajouter' : 'Modifier'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_playback.isNotEmpty) PlaybackBar(lienDrive: _playback),
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
                  hintText:
                      'Entrez les lyrics ici...\n\nConseil: Séparez les couplets par des lignes vides',
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
