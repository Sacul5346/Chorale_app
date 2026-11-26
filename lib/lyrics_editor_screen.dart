import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'association_playbacks.dart';
import 'parametres.dart';
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
    // Lien fixe du dossier des playbacks (réglé par le chef).
    final dossier = (await ParametresChorale.charger()).dossierPlaybacks;
    if (!mounted) return;

    final titre = widget.songData['title'] is String
        ? widget.songData['title'] as String
        : '';

    final resultat = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          /// Choix du fichier dans un dossier : le lien du fichier choisi
          /// devient le playback.
          Future<void> choisir(String lienDossier) async {
            final fichier = await showDialog<FichierDrive>(
              context: dialogContext,
              builder: (_) => _ChoixFichierDrive(
                idDossier: idDossierDrive(lienDossier)!,
                titreChanson: titre,
              ),
            );
            if (fichier != null && dialogContext.mounted) {
              Navigator.pop(dialogContext, lienFichierDrive(fichier.id));
            }
          }

          return AlertDialog(
            title: const Text('Playback (Google Drive)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DossierPlaybacks(
                    lien: dossier,
                    onChoisir: dossier.isEmpty ? null : () => choisir(dossier),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Ou collez ci-dessous le lien d’un fichier audio Google '
                    'Drive, ou d’un dossier (vous choisirez ensuite le '
                    'fichier). Le fichier doit être partagé à « Tous les '
                    'utilisateurs disposant du lien ».',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: 'Lien Google Drive',
                      border: const OutlineInputBorder(),
                      errorText: erreur,
                      errorMaxLines: 6,
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
                  // Lien de dossier : on choisit le fichier dedans.
                  if (idFichierDrive(lien) == null &&
                      idDossierDrive(lien) != null) {
                    choisir(lien);
                    return;
                  }
                  if (idFichierDrive(lien) == null) {
                    setDialogState(
                      () => erreur =
                          'Ce n’est pas un lien Google Drive de fichier ou '
                          'de dossier.',
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, lien);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
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

/// Lien fixe du dossier Google Drive des playbacks, toujours affiché en haut
/// de la fenêtre d'ajout : on y choisit le fichier, on copie son lien.
class _DossierPlaybacks extends StatelessWidget {
  final String lien;

  /// Ouvre la liste des fichiers du dossier (null si pas de dossier).
  final VoidCallback? onChoisir;
  const _DossierPlaybacks({required this.lien, this.onChoisir});

  Future<void> _ouvrir(BuildContext context) async {
    var ok = false;
    try {
      ok = await launchUrl(
        Uri.parse(lien),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir le lien.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (lien.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CouleursChorale.lavande,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Le chef peut enregistrer le lien du dossier des playbacks '
                'dans ⋮ › Paramètres de la chorale.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      decoration: BoxDecoration(
        color: CouleursChorale.lavande,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CouleursChorale.lavandeFonce),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.folder_shared,
                size: 18,
                color: CouleursChorale.aubergine,
              ),
              SizedBox(width: 6),
              Text(
                'Dossier des playbacks',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (onChoisir != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.library_music, size: 18),
                label: const Text('Choisir dans le dossier'),
                onPressed: onChoisir,
              ),
            ),
          const SizedBox(height: 6),
          SelectableText(
            lien,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ouvrir le dossier'),
                onPressed: () => _ouvrir(context),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copier'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: lien));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lien du dossier copié')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liste des fichiers audio d'un dossier Drive pour choisir le playback
/// d'une chanson. Les noms qui ressemblent au titre sont proposés en tête.
class _ChoixFichierDrive extends StatefulWidget {
  final String idDossier;
  final String titreChanson;
  const _ChoixFichierDrive({
    required this.idDossier,
    required this.titreChanson,
  });

  @override
  State<_ChoixFichierDrive> createState() => _ChoixFichierDriveState();
}

class _ChoixFichierDriveState extends State<_ChoixFichierDrive> {
  late final Future<List<FichierDrive>> _fichiers = fichiersAudioDuDossier(
    widget.idDossier,
  ).then((f) => trierPourChanson(f, widget.titreChanson));
  String _recherche = '';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir le playback'),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: FutureBuilder<List<FichierDrive>>(
          future: _fichiers,
          builder: (context, snap) {
            if (snap.hasError) {
              final e = snap.error;
              return Center(
                child: Text(
                  e is DriveException ? e.message : 'Erreur : $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              );
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final tous = snap.data!;
            if (tous.isEmpty) {
              return const Center(
                child: Text(
                  'Aucun fichier audio dans ce dossier.',
                  textAlign: TextAlign.center,
                ),
              );
            }
            final cle = normaliserNom(_recherche);
            final visibles = cle.isEmpty
                ? tous
                : tous
                      .where(
                        (f) =>
                            normaliserNom(f.nom, fichier: true).contains(cle),
                      )
                      .toList();
            return Column(
              children: [
                if (widget.titreChanson.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Pour « ${widget.titreChanson} »',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Rechercher un fichier',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (t) => setState(() => _recherche = t),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: visibles.isEmpty
                      ? const Center(child: Text('Aucun fichier trouvé.'))
                      : ListView.builder(
                          itemCount: visibles.length,
                          itemBuilder: (_, i) {
                            final f = visibles[i];
                            final suggere =
                                ressemblance(widget.titreChanson, f.nom) >=
                                seuilSuggestion;
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                suggere ? Icons.star : Icons.audiotrack,
                                color: suggere
                                    ? CouleursChorale.or
                                    : CouleursChorale.aubergineClair,
                              ),
                              title: Text(f.nom),
                              subtitle: suggere
                                  ? const Text(
                                      'Suggéré : nom proche du titre',
                                      style: TextStyle(fontSize: 11),
                                    )
                                  : null,
                              onTap: () => Navigator.pop(context, f),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
      ],
    );
  }
}
