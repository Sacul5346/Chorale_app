import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'association_playbacks.dart' show cleApiDrive;
import 'theme.dart';
import 'telechargement_web.dart'
    if (dart.library.io) 'telechargement_io.dart'
    as stockage;

/// Identifiant d'un fichier Google Drive à partir d'un lien de partage.
/// Formats acceptés :
///   https://drive.google.com/file/d/ID/view?usp=sharing
///   https://drive.google.com/open?id=ID
///   https://drive.google.com/uc?id=ID&export=download
/// Renvoie `null` si ce n'est pas un lien Drive reconnu.
String? idFichierDrive(String lien) {
  final texte = lien.trim();
  if (!texte.contains('drive.google.com') &&
      !texte.contains('docs.google.com')) {
    return null;
  }
  final match =
      RegExp(r'/d/([\w-]{20,})').firstMatch(texte) ??
      RegExp(r'[?&]id=([\w-]{20,})').firstMatch(texte);
  return match?.group(1);
}

/// Lien de téléchargement direct (lisible par le lecteur audio).
String? lienDirectDrive(String lien) {
  final id = idFichierDrive(lien);
  return id == null
      ? null
      : 'https://drive.google.com/uc?export=download&id=$id';
}

/// Lien du fichier via l'API Google Drive (clé API requise).
///
/// Indispensable dans un navigateur : les liens de téléchargement classiques
/// de Drive répondent 403 aux requêtes venant d'un autre site (en-têtes
/// Sec-Fetch-Site: cross-site), alors que l'API les accepte. Sur téléphone,
/// sert de solution de repli si le lien classique est refusé.
String? lienApiDrive(String lien, String cle) {
  final id = idFichierDrive(lien);
  return id == null || cle.isEmpty
      ? null
      : 'https://www.googleapis.com/drive/v3/files/$id?alt=media&key=$cle';
}

/// Barre de lecture d'un playback stocké sur Google Drive.
///
/// Sur téléphone, le premier appui sur ▶ propose de **télécharger** le
/// playback : il reste ensuite sur le téléphone et s'écoute sans internet.
/// Dans le navigateur (tests sur ordinateur), il est lu directement depuis
/// Drive.
class PlaybackBar extends StatefulWidget {
  final String lienDrive;

  /// Appelé à chaque avancée de la lecture (défilement des paroles au
  /// rythme de la chanson).
  final void Function(Duration position, Duration total, bool enLecture)?
  onProgression;

  const PlaybackBar({super.key, required this.lienDrive, this.onProgression});

  @override
  State<PlaybackBar> createState() => _PlaybackBarState();
}

class _PlaybackBarState extends State<PlaybackBar> {
  final _player = AudioPlayer();
  final _abonnements = <StreamSubscription<Object?>>[];

  /// Source chargée dans le lecteur (chemin local ou URL), pour ne pas la
  /// recharger à chaque appui.
  String? _sourceChargee;

  /// Chemin du fichier sur le téléphone, s'il est téléchargé.
  String? _cheminLocal;

  /// Progression du téléchargement en cours : null = aucun téléchargement,
  /// -1 = taille inconnue, sinon entre 0 et 1.
  double? _progression;
  bool _annuler = false;
  String? _erreur;

  String? get _idDrive => idFichierDrive(widget.lienDrive);

  @override
  void initState() {
    super.initState();
    _verifierFichierLocal();
    void signaler(_) => widget.onProgression?.call(
      _player.position,
      _player.duration ?? Duration.zero,
      _player.playing && _player.processingState != ProcessingState.completed,
    );
    _abonnements
      ..add(_player.positionStream.listen(signaler))
      ..add(_player.playerStateStream.listen(signaler));
  }

  @override
  void didUpdateWidget(PlaybackBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lienDrive != widget.lienDrive) {
      _player.stop();
      _sourceChargee = null;
      _cheminLocal = null;
      _erreur = null;
      _verifierFichierLocal();
    }
  }

  @override
  void dispose() {
    _annuler = true;
    for (final a in _abonnements) {
      a.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _verifierFichierLocal() async {
    final id = _idDrive;
    if (id == null) return;
    final chemin = await stockage.cheminLocal(id);
    if (mounted) setState(() => _cheminLocal = chemin);
  }

  Future<void> _lecturePause() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }
    final id = _idDrive;
    final url = lienDirectDrive(widget.lienDrive);
    if (id == null || url == null) {
      setState(() => _erreur = 'Lien de playback invalide.');
      return;
    }
    setState(() => _erreur = null);

    // Téléphone : on télécharge d'abord, avec l'accord du membre.
    if (stockage.telechargementPossible && _cheminLocal == null) {
      if (!await _confirmerTelechargement()) return;
      if (!await _telecharger(url, id)) return;
    }

    final chemin = _cheminLocal;
    String urlLecture = url;
    if (!stockage.telechargementPossible) {
      final urlApi = lienApiDrive(widget.lienDrive, cleApiDrive);
      if (urlApi == null) {
        setState(
          () => _erreur =
              'Lecture dans le navigateur impossible : la clé Google Drive '
              'n’est pas configurée (lancez l’app avec cle_drive.json).',
        );
        return;
      }
      urlLecture = urlApi;
    }
    final source = chemin ?? urlLecture;
    try {
      if (_sourceChargee != source) {
        await _player.setAudioSource(
          chemin != null
              ? AudioSource.file(chemin)
              : AudioSource.uri(Uri.parse(urlLecture)),
        );
        _sourceChargee = source;
      }
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(
          () => _erreur = chemin != null
              ? 'Ce fichier ne peut pas être lu. Supprimez-le puis '
                    'téléchargez-le à nouveau.'
              : 'Lecture impossible. Vérifiez votre connexion, et que le '
                    'fichier Drive est partagé à « Tous les utilisateurs '
                    'disposant du lien ».',
        );
      }
    }
  }

  Future<bool> _confirmerTelechargement() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Télécharger le playback ?'),
        content: const Text(
          'Le playback sera enregistré sur votre téléphone : vous pourrez '
          'ensuite l’écouter quand vous voulez, même sans internet.\n\n'
          'Le téléchargement utilise vos données mobiles (gratuit en Wi-Fi).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Plus tard'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.download),
            label: const Text('Télécharger'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _telecharger(String url, String id) async {
    setState(() {
      _progression = -1;
      _annuler = false;
    });
    Future<String> depuis(String adresse) => stockage.telecharger(
      adresse,
      id,
      progression: (p) {
        if (mounted) setState(() => _progression = p ?? -1);
      },
      annule: () => _annuler,
    );
    try {
      String chemin;
      try {
        chemin = await depuis(url);
      } on stockage.TelechargementException {
        // Lien classique refusé par Drive : on retente via l'API.
        final urlApi = lienApiDrive(widget.lienDrive, cleApiDrive);
        if (urlApi == null) rethrow;
        chemin = await depuis(urlApi);
      }
      if (mounted) setState(() => _cheminLocal = chemin);
      return mounted;
    } on stockage.TelechargementAnnule {
      return false;
    } on stockage.TelechargementException catch (e) {
      if (mounted) setState(() => _erreur = e.message);
      return false;
    } catch (_) {
      if (mounted) {
        setState(() => _erreur = 'Le téléchargement a échoué. Réessayez.');
      }
      return false;
    } finally {
      if (mounted) setState(() => _progression = null);
    }
  }

  Future<void> _supprimerFichier() async {
    final id = _idDrive;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer du téléphone ?'),
        content: const Text(
          'Le playback sera effacé de votre téléphone pour libérer de la '
          'place. Vous pourrez le télécharger à nouveau plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _player.stop();
    await stockage.supprimer(id);
    if (mounted) {
      setState(() {
        _cheminLocal = null;
        _sourceChargee = null;
      });
    }
  }

  static String _duree(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CouleursChorale.lavande,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_progression != null) _barreTelechargement() else _lecteur(),
              if (_cheminLocal != null && _progression == null)
                Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.offline_pin,
                      size: 16,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Sur ce téléphone : écoute possible sans internet',
                        style: TextStyle(fontSize: 12, color: Colors.green),
                      ),
                    ),
                    TextButton(
                      onPressed: _supprimerFichier,
                      child: const Text(
                        'Supprimer',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text(
                    _erreur!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barreTelechargement() {
    final p = _progression!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 0, 4),
      child: Row(
        children: [
          const Icon(Icons.download, color: CouleursChorale.aubergine),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p < 0
                      ? 'Téléchargement…'
                      : 'Téléchargement… ${(p * 100).round()} %',
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: p < 0 ? null : p),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _annuler = true,
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Widget _lecteur() {
    return Row(
      children: [
        StreamBuilder<PlayerState>(
          stream: _player.playerStateStream,
          builder: (context, snapshot) {
            final etat = snapshot.data;
            final charge =
                etat?.processingState == ProcessingState.loading ||
                etat?.processingState == ProcessingState.buffering;
            if (charge && (etat?.playing ?? false)) {
              return const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              );
            }
            final enLecture =
                (etat?.playing ?? false) &&
                etat?.processingState != ProcessingState.completed;
            return IconButton(
              iconSize: 36,
              color: CouleursChorale.aubergine,
              tooltip: enLecture ? 'Pause' : 'Écouter le playback',
              icon: Icon(
                enLecture
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
              ),
              onPressed: () {
                if (etat?.processingState == ProcessingState.completed) {
                  _player.seek(Duration.zero);
                }
                _lecturePause();
              },
            );
          },
        ),
        Expanded(
          child: StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final total = _player.duration ?? Duration.zero;
              final max = total.inMilliseconds.toDouble();
              return Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: max <= 0
                          ? 0
                          : position.inMilliseconds.clamp(0, max).toDouble(),
                      max: max <= 0 ? 1 : max,
                      onChanged: max <= 0
                          ? null
                          : (v) =>
                                _player.seek(Duration(milliseconds: v.round())),
                    ),
                  ),
                  Text(
                    '${_duree(position)} / ${_duree(total)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
