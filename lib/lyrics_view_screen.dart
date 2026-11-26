import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'paroles.dart';
import 'playback.dart';
import 'theme.dart';

/// Lecture des paroles pour tous les rôles (lecture seule), avec :
///  - un en-tête en dégradé qui se replie quand on fait défiler ;
///  - les paroles en strophes : couplets numérotés, refrain mis en valeur ;
///  - un panneau flottant unique : playback, défilement automatique (au
///    rythme du playback ou à vitesse réglable), taille du texte, mode scène ;
///  - la taille du texte aussi réglable en pinçant à deux doigts.
/// Toucher le texte met le défilement automatique en pause.
class LyricsViewScreen extends StatefulWidget {
  final String songId;
  final String titre;

  /// Données de la chanson (aperçus et tests). Par défaut : Firestore, en
  /// direct (une correction du gestionnaire de paroles apparaît aussitôt).
  final Stream<Map<String, dynamic>?>? source;

  const LyricsViewScreen({
    super.key,
    required this.songId,
    required this.titre,
    this.source,
  });

  @override
  State<LyricsViewScreen> createState() => _LyricsViewScreenState();
}

const _police = 'Poppins';
const _tailleMin = 14.0, _tailleMax = 44.0;

class _LyricsViewScreenState extends State<LyricsViewScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_avancer);
  Duration _dernierTick = Duration.zero;

  late final Stream<Map<String, dynamic>?> _source =
      widget.source ??
      FirebaseFirestore.instance
          .collection('songs')
          .doc(widget.songId)
          .snapshots()
          .map((s) => s.data());

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

  // Pincement à deux doigts (taille du texte). Un Listener n'entre pas en
  // concurrence avec le défilement, contrairement à un détecteur de geste.
  final _doigts = <int, Offset>{};
  double? _ecartInitial;
  double _tailleInitiale = 22;

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

  void _changerTaille(double nouvelle) =>
      setState(() => _taille = nouvelle.clamp(_tailleMin, _tailleMax));

  void _doigtPose(PointerDownEvent e) {
    _doigts[e.pointer] = e.position;
    if (_doigts.length == 2) {
      final p = _doigts.values.toList();
      _ecartInitial = (p[0] - p[1]).distance;
      _tailleInitiale = _taille;
    }
  }

  void _doigtBouge(PointerMoveEvent e) {
    if (!_doigts.containsKey(e.pointer)) return;
    _doigts[e.pointer] = e.position;
    final initial = _ecartInitial;
    if (_doigts.length != 2 || initial == null || initial < 20) return;
    final p = _doigts.values.toList();
    _changerTaille(_tailleInitiale * (p[0] - p[1]).distance / initial);
  }

  void _doigtLeve(PointerEvent e) {
    _doigts.remove(e.pointer);
    if (_doigts.length < 2) _ecartInitial = null;
  }

  @override
  Widget build(BuildContext context) {
    final c = _Couleurs(_scene);
    return Scaffold(
      backgroundColor: c.fond,
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _source,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(context, c, 'Impossible de charger les paroles.');
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data ?? const {};
          String champ(String nom) =>
              data[nom] is String ? (data[nom] as String).trim() : '';
          final paroles = champ('lyrics');
          final playback = champ('playbackUrl');
          _aUnPlayback = playback.isNotEmpty;
          final strophes = decouperParoles(paroles);
          final titre = champ('title').isEmpty ? widget.titre : champ('title');

          return Stack(
            children: [
              Listener(
                onPointerDown: _doigtPose,
                onPointerMove: _doigtBouge,
                onPointerUp: _doigtLeve,
                onPointerCancel: _doigtLeve,
                child: NotificationListener<ScrollStartNotification>(
                  // Le choriste reprend la main en touchant le texte.
                  onNotification: (n) {
                    if (n.dragDetails != null && _defilement) {
                      setState(() => _defilement = false);
                      _majTicker();
                    }
                    return false;
                  },
                  child: CustomScrollView(
                    controller: _scroll,
                    slivers: [
                      _entete(c, titre, [champ('region'), champ('artist')]),
                      SliverPadding(
                        // Marge du bas : le panneau flottant ne cache rien.
                        padding: EdgeInsets.fromLTRB(
                          16,
                          20,
                          16,
                          playback.isNotEmpty ? 230 : 160,
                        ),
                        sliver: strophes.isEmpty
                            ? SliverToBoxAdapter(child: _vide(c))
                            : SliverList.separated(
                                itemCount: strophes.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: _taille * 0.9),
                                itemBuilder: (_, i) => _strophe(c, strophes[i]),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 12),
                  child: _panneau(c, playback, paroles.isNotEmpty),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------------
  // En-tête
  // -------------------------------------------------------------------

  Widget _entete(_Couleurs c, String titre, List<String> etiquettes) {
    final infos = etiquettes.where((e) => e.isNotEmpty).toList();
    return SliverAppBar(
      pinned: true,
      expandedHeight: infos.isEmpty ? 150 : 180,
      backgroundColor: c.enteteFonce,
      foregroundColor: Colors.white,
      // Titre réduit, visible une fois l'en-tête replié.
      title: _TitreReplie(titre: titre, controleur: _scroll),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.enteteClair, c.enteteFonce],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 52, 24, 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _police,
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  if (infos.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final e in infos)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: CouleursChorale.or.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            child: Text(
                              e,
                              style: const TextStyle(
                                fontFamily: _police,
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Container(width: 44, height: 3, color: CouleursChorale.or),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Strophes
  // -------------------------------------------------------------------

  Widget _strophe(_Couleurs c, Strophe s) {
    final style = TextStyle(
      fontFamily: _police,
      fontSize: _taille,
      height: 1.55,
      color: c.texte,
    );

    if (s.repriseRefrain) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: c.refrainFond,
            borderRadius: BorderRadius.circular(20),
          ),
          // Icône plutôt que « ↻ » : absent de la police Poppins.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.replay, size: 15, color: c.or),
              const SizedBox(width: 6),
              Text(
                'Refrain',
                style: TextStyle(
                  fontFamily: _police,
                  color: c.or,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (s.refrain) {
      return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 14, 14),
        decoration: BoxDecoration(
          color: c.refrainFond,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: c.or, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REFRAIN',
              style: TextStyle(
                fontFamily: _police,
                color: c.or,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(s.texte, style: style.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Numéro du couplet, aligné sur la première ligne.
          SizedBox(
            width: 30,
            child: Padding(
              padding: EdgeInsets.only(top: (_taille * 1.55 - 22) / 2),
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: c.or, width: 1.4),
                ),
                child: Text(
                  '${s.numero}',
                  style: TextStyle(
                    fontFamily: _police,
                    color: c.or,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: Text(s.texte, style: style)),
        ],
      ),
    );
  }

  Widget _vide(_Couleurs c) => Padding(
    padding: const EdgeInsets.only(top: 40),
    child: Column(
      children: [
        Icon(Icons.lyrics_outlined, size: 48, color: c.texteDoux),
        const SizedBox(height: 12),
        Text(
          'Les paroles de cette chanson n’ont pas encore été ajoutées.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _police,
            color: c.texteDoux,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );

  Widget _message(BuildContext context, _Couleurs c, String texte) => Scaffold(
    backgroundColor: c.fond,
    appBar: AppBar(title: Text(widget.titre)),
    body: Center(
      child: Text(texte, style: TextStyle(color: c.texte)),
    ),
  );

  // -------------------------------------------------------------------
  // Panneau flottant
  // -------------------------------------------------------------------

  Widget _panneau(_Couleurs c, String playback, bool aDesParoles) {
    return Material(
      color: c.panneau,
      // Ombre légère en mode normal ; aucune sur fond noir.
      elevation: _scene ? 0 : 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (playback.isNotEmpty) ...[
              PlaybackBar(
                lienDrive: playback,
                onProgression: _surProgression,
                integre: true,
                couleur: c.commande,
              ),
              Divider(height: 1, color: c.texteDoux.withValues(alpha: 0.25)),
            ],
            Row(
              children: [
                if (aDesParoles) ...[
                  IconButton(
                    tooltip: _defilement
                        ? 'Arrêter le défilement'
                        : 'Défilement automatique',
                    color: _defilement ? c.or : c.commande,
                    icon: Icon(
                      _defilement
                          ? Icons.pause_circle_outline
                          : Icons.slow_motion_video,
                    ),
                    onPressed: _basculerDefilement,
                  ),
                  Expanded(child: _reglageDefilement(c)),
                ] else
                  const Spacer(),
                IconButton(
                  tooltip: 'Réduire le texte',
                  color: c.commande,
                  icon: const Icon(Icons.text_decrease),
                  onPressed: _taille > _tailleMin
                      ? () => _changerTaille(_taille - 2)
                      : null,
                ),
                IconButton(
                  tooltip: 'Agrandir le texte',
                  color: c.commande,
                  icon: const Icon(Icons.text_increase),
                  onPressed: _taille < _tailleMax
                      ? () => _changerTaille(_taille + 2)
                      : null,
                ),
                IconButton(
                  tooltip: _scene ? 'Mode normal' : 'Mode scène',
                  color: c.commande,
                  icon: Icon(_scene ? Icons.light_mode : Icons.dark_mode),
                  onPressed: () => setState(() => _scene = !_scene),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Avec un playback : suivre la chanson (ou pas). Sinon : la vitesse.
  Widget _reglageDefilement(_Couleurs c) {
    if (_aUnPlayback) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _suivrePlayback = !_suivrePlayback);
          _majTicker();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(
                _suivrePlayback ? Icons.sync : Icons.sync_disabled,
                size: 18,
                color: _suivrePlayback ? c.or : c.texteDoux,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  _suivrePlayback ? 'Suit la chanson' : 'Vitesse fixe',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: _police,
                    fontSize: 12.5,
                    color: c.commande,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: c.or,
        thumbColor: c.or,
        inactiveTrackColor: c.texteDoux.withValues(alpha: 0.3),
        trackHeight: 3,
      ),
      child: Slider(
        value: _vitesse,
        min: 1,
        max: 5,
        divisions: 8,
        label: 'Vitesse ${_vitesse.toStringAsFixed(1)}',
        onChanged: (v) => setState(() => _vitesse = v),
      ),
    );
  }
}

/// Titre de la barre, affiché seulement quand l'en-tête est replié.
class _TitreReplie extends StatefulWidget {
  final String titre;
  final ScrollController controleur;
  const _TitreReplie({required this.titre, required this.controleur});

  @override
  State<_TitreReplie> createState() => _TitreReplieState();
}

class _TitreReplieState extends State<_TitreReplie> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controleur.addListener(_maj);
  }

  @override
  void dispose() {
    widget.controleur.removeListener(_maj);
    super.dispose();
  }

  void _maj() {
    final visible =
        widget.controleur.hasClients && widget.controleur.offset > 90;
    if (visible != _visible) setState(() => _visible = visible);
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: _visible ? 1 : 0,
    duration: const Duration(milliseconds: 200),
    child: Text(
      widget.titre,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: _police,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Couleurs des modes normal (crème) et scène (noir, pour chanter).
class _Couleurs {
  final bool scene;
  const _Couleurs(this.scene);

  Color get fond => scene ? Colors.black : CouleursChorale.creme;
  Color get texte => scene ? const Color(0xFFF3EEE4) : const Color(0xFF2B2233);
  Color get texteDoux =>
      scene ? const Color(0xFF9A93A6) : CouleursChorale.aubergineClair;
  Color get or => CouleursChorale.or;
  Color get refrainFond =>
      scene ? Colors.white.withValues(alpha: 0.07) : CouleursChorale.lavande;
  Color get enteteClair =>
      scene ? const Color(0xFF1E1A24) : CouleursChorale.aubergine;
  Color get enteteFonce =>
      scene ? const Color(0xFF0E0C11) : CouleursChorale.aubergineFonce;
  Color get panneau => scene ? const Color(0xFF1C1C1E) : Colors.white;
  Color get commande => scene ? Colors.white : CouleursChorale.aubergine;
}
