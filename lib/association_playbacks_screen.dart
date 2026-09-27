import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'association_playbacks.dart';

/// Relie en une fois les playbacks d'un dossier Google Drive aux chansons
/// du même nom (pour le gestionnaire de paroles).
class AssociationPlaybacksScreen extends StatefulWidget {
  const AssociationPlaybacksScreen({super.key});

  @override
  State<AssociationPlaybacksScreen> createState() =>
      _AssociationPlaybacksScreenState();
}

class _AssociationPlaybacksScreenState
    extends State<AssociationPlaybacksScreen> {
  final _lienController = TextEditingController();
  bool _chargement = false;
  bool _enregistrement = false;
  String? _erreur;
  ResultatAssociation? _resultat;
  int _nbFichiers = 0;

  /// Correspondances cochées (par id de chanson).
  final _coches = <String>{};

  @override
  void dispose() {
    _lienController.dispose();
    super.dispose();
  }

  Future<void> _analyser() async {
    final idDossier = idDossierDrive(_lienController.text);
    if (idDossier == null) {
      setState(
        () => _erreur =
            'Ce n’est pas un lien de dossier Google Drive (il doit contenir '
            '« /folders/ »).',
      );
      return;
    }
    setState(() {
      _chargement = true;
      _erreur = null;
      _resultat = null;
    });
    try {
      final fichiers = await fichiersAudioDuDossier(idDossier);
      final songs = await FirebaseFirestore.instance.collection('songs').get();
      final chansons = [
        for (final doc in songs.docs)
          if (doc.data()['title'] case final String titre)
            ChansonExistante(
              doc.id,
              titre,
              doc.data()['playbackUrl'] as String? ?? '',
            ),
      ];
      final resultat = associer(chansons, fichiers);
      if (!mounted) return;
      setState(() {
        _nbFichiers = fichiers.length;
        _resultat = resultat;
        // Par défaut : seulement les chansons sans playback. Les
        // remplacements sont à cocher volontairement.
        _coches
          ..clear()
          ..addAll(
            resultat.correspondances
                .where((c) => !c.dejaRelie && !c.remplace)
                .map((c) => c.chanson.id),
          );
      });
    } on DriveException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _enregistrer() async {
    final aRelier = _resultat!.correspondances
        .where((c) => _coches.contains(c.chanson.id))
        .toList();
    setState(() => _enregistrement = true);
    try {
      final db = FirebaseFirestore.instance;
      // Un lot Firestore est limité à 500 écritures.
      for (var i = 0; i < aRelier.length; i += 450) {
        final batch = db.batch();
        for (final c in aRelier.skip(i).take(450)) {
          batch.update(db.collection('songs').doc(c.chanson.id), {
            'playbackUrl': lienFichierDrive(c.fichier.id),
            'updatedAt': DateTime.now(),
          });
        }
        await batch.commit();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${aRelier.length} playback(s) relié(s) aux chansons.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _erreur = 'Enregistrement impossible : $e');
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultat;
    return Scaffold(
      appBar: AppBar(title: const Text('Associer les playbacks')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Mettez tous les playbacks dans un dossier Google Drive, en '
            'nommant chaque fichier comme la chanson dans l’app.\n'
            '2. Partagez le dossier : « Tous les utilisateurs disposant du '
            'lien » (Lecteur).\n'
            '3. Copiez le lien du dossier et collez-le ci-dessous.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _lienController,
            decoration: const InputDecoration(
              labelText: 'Lien du dossier Google Drive',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _chargement || _enregistrement ? null : _analyser,
            icon: _chargement
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: const Text('Chercher les correspondances'),
          ),
          if (_erreur != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_erreur!, style: const TextStyle(color: Colors.red)),
            ),
          if (r != null) ..._resultats(r),
        ],
      ),
      bottomNavigationBar: r == null || _coches.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: _enregistrement ? null : _enregistrer,
                  child: _enregistrement
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('Relier ${_coches.length} playback(s)'),
                ),
              ),
            ),
    );
  }

  List<Widget> _resultats(ResultatAssociation r) {
    final dejaRelies = r.correspondances.where((c) => c.dejaRelie).length;
    final aTraiter = r.correspondances.where((c) => !c.dejaRelie).toList();
    return [
      const SizedBox(height: 16),
      Text(
        '$_nbFichiers fichier(s) audio trouvé(s) · '
        '${r.correspondances.length} correspondance(s)'
        '${dejaRelies > 0 ? ' (dont $dejaRelies déjà reliée(s))' : ''}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      if (aTraiter.isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton(
              onPressed: () => setState(
                () => _coches.addAll(aTraiter.map((c) => c.chanson.id)),
              ),
              child: const Text('Tout cocher'),
            ),
            TextButton(
              onPressed: () => setState(_coches.clear),
              child: const Text('Tout décocher'),
            ),
          ],
        ),
        ...aTraiter.map(
          (c) => CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _coches.contains(c.chanson.id),
            onChanged: (v) => setState(
              () => v == true
                  ? _coches.add(c.chanson.id)
                  : _coches.remove(c.chanson.id),
            ),
            title: Text(c.chanson.titre),
            subtitle: Text(
              '← ${c.fichier.nom}'
              '${c.remplace ? '\n⚠️ Remplacera le playback actuel' : ''}',
              style: TextStyle(
                color: c.remplace ? Colors.orange.shade800 : null,
              ),
            ),
          ),
        ),
      ],
      if (r.ambigus.isNotEmpty)
        _encadre(
          '⚠️ Noms en double (${r.ambigus.length})',
          'Plusieurs fichiers ou plusieurs chansons portent ce nom : '
              'renommez-les pour les distinguer, ou reliez-les à la main.',
          r.ambigus,
          Colors.orange,
        ),
      if (r.fichiersSansChanson.isNotEmpty)
        _encadre(
          'Fichiers sans chanson du même nom (${r.fichiersSansChanson.length})',
          'Renommez-les dans Drive comme la chanson de l’app (ou ajoutez la '
              'chanson), puis relancez la recherche.',
          r.fichiersSansChanson.map((f) => f.nom).toList(),
          Colors.grey,
        ),
    ];
  }

  Widget _encadre(
    String titre,
    String explication,
    List<String> noms,
    Color couleur,
  ) {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: ExpansionTile(
        title: Text(titre, style: TextStyle(color: couleur)),
        subtitle: Text(explication, style: const TextStyle(fontSize: 12)),
        children: noms
            .map((n) => ListTile(dense: true, title: Text(n)))
            .toList(),
      ),
    );
  }
}
