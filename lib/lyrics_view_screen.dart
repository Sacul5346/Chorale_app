import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'playback.dart';
import 'theme.dart';

/// Lecture des paroles pour tous les rôles (lecture seule), avec :
///  - le playback de la chanson (s'il existe) ;
///  - le défilement automatique : au rythme du playback, ou à vitesse
///    réglable sans playback. Toucher le texte met le défilement en pause ;
///  - le mode scène (fond noir, texte clair) pour chanter ;
///  - A- / A+ pour la taille du texte.
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

class _LyricsViewScreenState extends State<LyricsViewScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_avancer);
  Duration _dernierTick = Duration.zero;

  double _taille = 22;
  bool _scene = false;

  /// Défilement automatique activé (mis en pause si on touche le texte).
  bool _defilement = false;

  /// Avec un playback : suivre la chanson plutôt qu'une vitesse fixe.
  bool _suivrePlayback = true;

  /// Vitesse sans playback, de 1 (lent) à 5 (rapide).
  double _vitesse = 2;

  bool _aUnPlayback = false;
  bool _enLecture = false;
  double _ratioLecture = 0;

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  bool get _modeSuivi => _aUnPlayback && _suivrePlayback;

  /// Le ticker (≈ 60 fois par seconde) ne tourne que lorsqu'il y a
  /// réellement quelque chose à faire défiler, pour économiser la batterie.
  void _majTicker() {
    final utile = _defilement && (!_modeSuivi || _enLecture);
    if (utile && !_ticker.isActive) {
      _dernierTick = Duration.zero;
      _ticker.start();
    } else if (!utile && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _avancer(Duration ecoule) {
    final dt = (ecoule - _dernierTick).inMicroseconds / 1e6;
    _dernierTick = ecoule;
    if (!_scroll.hasClients || dt <= 0) return;
    final pos = _scroll.position;
    final max = pos.maxScrollExtent;
    if (max <= 0) return;

    double cible;
    if (_modeSuivi) {
      // La ligne « en cours » (proportionnelle à l'avancée de la chanson)
      // est gardée vers le tiers haut de l'écran. Rapprochement en douceur.
      final hauteur = max + pos.viewportDimension;
      final voulu = (hauteur * _ratioLecture - pos.viewportDimension * 0.3)
          .clamp(0.0, max);
      cible = pos.pixels + (voulu - pos.pixels) * (dt * 2).clamp(0.0, 1.0);
    } else {
      cible = pos.pixels + _vitesse * 12 * dt;
      if (cible >= max) {
        cible = max;
        setState(() => _defilement = false);
        _majTicker();
      }
    }
    _scroll.jumpTo(cible.clamp(0.0, max));
  }

  void _surProgression(Duration position, Duration total, bool enLecture) {
    _ratioLecture = total.inMilliseconds > 0
        ? (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0)
        : 0;
    if (enLecture != _enLecture) {
      // Lancer le playback active le suivi automatique des paroles.
      setState(() {
        _enLecture = enLecture;
        if (enLecture && _suivrePlayback) _defilement = true;
      });
      _majTicker();
    }
  }

  void _basculerDefilement() {
    setState(() => _defilement = !_defilement);
    _majTicker();
  }

  @override
  Widget build(BuildContext context) {
    final fond = _scene ? Colors.black : CouleursChorale.creme;
    final texte = _scene ? const Color(0xFFF3EEE4) : const Color(0xFF2B2233);

    return Scaffold(
      backgroundColor: fond,
      appBar: AppBar(
        backgroundColor: _scene ? Colors.black : null,
        title: Text(widget.titre, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Réduire le texte',
            icon: const Icon(Icons.text_decrease),
            onPressed: _taille > 14 ? () => setState(() => _taille -= 2) : null,
          ),
          IconButton(
            tooltip: 'Agrandir le texte',
            icon: const Icon(Icons.text_increase),
            onPressed: _taille < 44 ? () => setState(() => _taille += 2) : null,
          ),
          IconButton(
            tooltip: _scene ? 'Mode normal' : 'Mode scène',
            icon: Icon(_scene ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => setState(() => _scene = !_scene),
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
          String champ(String nom) =>
              data[nom] is String ? (data[nom] as String).trim() : '';
          final paroles = champ('lyrics');
          final playback = champ('playbackUrl');
          _aUnPlayback = playback.isNotEmpty;

          return Column(
            children: [
              Expanded(
                child: NotificationListener<ScrollStartNotification>(
                  // Le choriste reprend la main en touchant le texte.
                  onNotification: (n) {
                    if (n.dragDetails != null && _defilement) {
                      setState(() => _defilement = false);
                      _majTicker();
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                    children: [
                      _entete(
                        champ('title').isEmpty ? widget.titre : champ('title'),
                        champ('artist'),
                        champ('region'),
                        texte,
                      ),
                      const SizedBox(height: 28),
                      if (paroles.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Les paroles de cette chanson n’ont pas encore '
                            'été ajoutées.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: texte.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        )
                      else
                        Text(
                          paroles,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: _taille,
                            height: 1.65,
                            color: texte,
                            letterSpacing: 0.2,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (paroles.isNotEmpty) _barreDefilement(),
              if (playback.isNotEmpty)
                PlaybackBar(
                  lienDrive: playback,
                  onProgression: _surProgression,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _entete(String titre, String artiste, String region, Color texte) {
    return Column(
      children: [
        Icon(Icons.music_note, color: CouleursChorale.or, size: 28),
        const SizedBox(height: 8),
        Text(
          titre,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: texte,
            letterSpacing: 0.3,
          ),
        ),
        if (artiste.isNotEmpty || region.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            [artiste, region].where((s) => s.isNotEmpty).join('  ·  '),
            textAlign: TextAlign.center,
            style: TextStyle(color: texte.withValues(alpha: 0.6)),
          ),
        ],
        const SizedBox(height: 14),
        Container(width: 56, height: 2, color: CouleursChorale.or),
      ],
    );
  }

  Widget _barreDefilement() {
    final couleur = _scene ? Colors.white : CouleursChorale.aubergine;
    return Material(
      color: _scene ? const Color(0xFF151515) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 12, 2),
        child: Row(
          children: [
            IconButton(
              tooltip: _defilement
                  ? 'Arrêter le défilement'
                  : 'Défilement automatique',
              color: couleur,
              icon: Icon(
                _defilement
                    ? Icons.pause_circle_outline
                    : Icons.slow_motion_video,
              ),
              onPressed: _basculerDefilement,
            ),
            // Vitesse réglable seulement quand on ne suit pas la chanson.
            if (_modeSuivi)
              Expanded(
                child: Text(
                  _defilement ? 'Suit la chanson' : 'Défilement auto',
                  style: TextStyle(color: couleur, fontSize: 13),
                ),
              )
            else ...[
              Icon(Icons.speed, size: 18, color: couleur),
              Expanded(
                child: Slider(
                  value: _vitesse,
                  min: 1,
                  max: 5,
                  divisions: 8,
                  label: 'Vitesse ${_vitesse.toStringAsFixed(1)}',
                  onChanged: (v) => setState(() => _vitesse = v),
                ),
              ),
            ],
            if (_aUnPlayback)
              FilterChip(
                label: const Text('Suivre la chanson'),
                selected: _suivrePlayback,
                onSelected: (v) {
                  setState(() => _suivrePlayback = v);
                  _majTicker();
                },
              ),
          ],
        ),
      ),
    );
  }
}
