import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'badge.dart' show libelleBadge;
import 'parametres.dart';
import 'pointage.dart';
import 'roles.dart';
import 'theme.dart';

/// Pointage des présences à l'entrée de la répétition : le chef (ou son
/// suppléant) garde la caméra ouverte et chaque membre présente son badge.
///
/// Fonctionne sans internet : les écritures sont gardées sur le téléphone
/// et envoyées au retour du réseau. C'est pourquoi on n'attend jamais la
/// fin d'une écriture (elle ne se termine qu'une fois le serveur joint).
class ScanPresenceScreen extends StatefulWidget {
  final String repetitionId;
  final String repetitionTitre;
  final DateTime? date;
  final String heure;

  const ScanPresenceScreen({
    super.key,
    required this.repetitionId,
    required this.repetitionTitre,
    required this.date,
    required this.heure,
  });

  @override
  State<ScanPresenceScreen> createState() => _ScanPresenceScreenState();
}

/// Ce qu'affiche le bandeau après un scan.
class _Resultat {
  final String titre;
  final String detail;
  final Color couleur;
  final IconData icone;
  final String? photo;

  const _Resultat(
    this.titre,
    this.detail,
    this.couleur,
    this.icone, {
    this.photo,
  });
}

class _ScanPresenceScreenState extends State<ScanPresenceScreen> {
  final _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  final _db = FirebaseFirestore.instance;
  late final _presencesCol = _db.collection('presences');

  // Données chargées une fois à l'ouverture.
  Map<String, Map<String, dynamic>>? _membres; // uid -> fiche
  Set<String> _excuses = const {}; // membres ayant envoyé une excuse
  int _tolerance = toleranceRetardParDefaut;

  // Présences de la répétition, tenues à jour (y compris hors ligne).
  final _presences =
      <
        String,
        ({
          DocumentReference<Map<String, dynamic>> ref,
          Map<String, dynamic> data,
        })
      >{};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _abonnement;

  /// Statuts écrits pendant cette session : évite un doublon avant que le
  /// flux Firestore ne les renvoie.
  final _pointes = <String, String>{};

  _Resultat? _resultat;
  String? _dernierQr;
  DateTime _dernierScan = DateTime(2000);
  String? _erreurChargement;

  DateTime? get _debut =>
      widget.date == null ? null : debutRepetition(widget.date!, widget.heure);

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    try {
      final resultats = await Future.wait([
        _db.collection('users').get(),
        _db
            .collection('conversations')
            .where('repetitionId', isEqualTo: widget.repetitionId)
            .get(),
        ParametresChorale.charger(),
      ]);
      final users = resultats[0] as QuerySnapshot<Map<String, dynamic>>;
      final convs = resultats[1] as QuerySnapshot<Map<String, dynamic>>;
      final params = resultats[2] as ParametresChorale;

      _abonnement = _presencesCol
          .where('repetitionId', isEqualTo: widget.repetitionId)
          .snapshots()
          .listen((snap) {
            for (final d in snap.docs) {
              final uid = d.data()['userId'];
              if (uid is String) {
                _presences[uid] = (ref: d.reference, data: d.data());
              }
            }
            if (mounted) setState(() {});
          });

      if (!mounted) return;
      setState(() {
        _membres = {for (final u in users.docs) u.id: u.data()};
        _excuses = {
          for (final c in convs.docs)
            if (c.data()['membreId'] is String) c.data()['membreId'] as String,
        };
        _tolerance = params.toleranceRetard;
      });
    } catch (e) {
      if (mounted) setState(() => _erreurChargement = '$e');
    }
  }

  @override
  void dispose() {
    _abonnement?.cancel();
    _camera.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Comptage
  // ---------------------------------------------------------------------

  /// Membres attendus : comptes actifs, sauf le chef (comme les statistiques).
  Iterable<String> get _attendus => (_membres ?? const {}).entries
      .where(
        (e) =>
            e.value['actif'] != false &&
            roleNormalise(e.value['role']) != 'chef',
      )
      .map((e) => e.key);

  String _statutActuel(String uid) =>
      _pointes[uid] ?? statutConstateDe(_presences[uid]?.data ?? const {});

  int get _nbPresents =>
      _attendus.where((uid) => estPresent(_statutActuel(uid))).length;

  // ---------------------------------------------------------------------
  // Scan
  // ---------------------------------------------------------------------

  void _surDetection(BarcodeCapture capture) {
    if (_membres == null) return; // encore en chargement
    for (final code in capture.barcodes) {
      final brut = code.rawValue;
      if (brut == null) continue;
      final maintenant = DateTime.now();
      // Le même badge reste devant la caméra : on ne le traite qu'une fois.
      if (brut == _dernierQr &&
          maintenant.difference(_dernierScan) < const Duration(seconds: 3)) {
        return;
      }
      _dernierQr = brut;
      _dernierScan = maintenant;
      _traiter(brut, maintenant);
      return;
    }
  }

  void _traiter(String brut, DateTime maintenant) {
    final uid = membreDepuisQr(brut);
    final fiche = uid == null ? null : _membres![uid];

    if (uid == null) {
      _afficher(
        const _Resultat(
          'Code non reconnu',
          'Ce n’est pas un badge K.T.K.F.A.',
          Colors.red,
          Icons.error_outline,
        ),
        vibrationForte: true,
      );
      return;
    }
    if (fiche == null) {
      _afficher(
        const _Resultat(
          'Badge inconnu',
          'Ce membre n’existe plus dans l’application.',
          Colors.red,
          Icons.person_off_outlined,
        ),
        vibrationForte: true,
      );
      return;
    }

    final nom = _nom(fiche);
    final photo = fiche['photoBase64'] is String
        ? fiche['photoBase64'] as String
        : null;

    if (fiche['actif'] == false) {
      _afficher(
        _Resultat(
          nom,
          'Compte désactivé : présence non enregistrée.',
          Colors.red,
          Icons.block,
          photo: photo,
        ),
        vibrationForte: true,
      );
      return;
    }

    final dejaLa = _statutActuel(uid);
    if (estPresent(dejaLa)) {
      _afficher(
        _Resultat(
          nom,
          'Déjà pointé : ${_libelleStatut(dejaLa)}',
          Colors.orange.shade800,
          Icons.info_outline,
          photo: photo,
        ),
      );
      return;
    }

    final presence = _presences[uid];
    final intention = intentionDe(presence?.data ?? const {});
    final statut = statutAuScan(
      debut: _debut,
      scan: maintenant,
      toleranceMinutes: _tolerance,
      intention: intention,
      excuseEnvoyee: _excuses.contains(uid),
    );
    _ecrire(uid, statut, presence, intention);
    _pointes[uid] = statut;

    final voix = libelleBadge(role: fiche['role'], voix: fiche['voix']);
    _afficher(
      _Resultat(
        nom,
        [
          if (voix.isNotEmpty) voix,
          '${_libelleStatut(statut)} (${_hhmm(maintenant)})',
        ].join(' · '),
        statut == 'present_heure'
            ? Colors.green.shade700
            : Colors.amber.shade800,
        statut == 'present_heure' ? Icons.check_circle : Icons.schedule,
        photo: photo,
      ),
    );
  }

  /// Écrit sans attendre le serveur (voir la note de la classe).
  void _ecrire(
    String uid,
    String statut,
    ({DocumentReference<Map<String, dynamic>> ref, Map<String, dynamic> data})?
    presence,
    String intention,
  ) {
    final champs = <String, Object>{
      'statut': statut,
      'valideePar': FirebaseAuth.instance.currentUser!.uid,
      'confirmedAt': FieldValue.serverTimestamp(),
      'pointeParBadge': true,
    };
    final Future<void> ecriture;
    if (presence != null) {
      ecriture = presence.ref.update({
        ...champs,
        // Ancien format : on garde l'intention du membre avant de l'écraser.
        if (presence.data['intention'] == null && intention.isNotEmpty)
          'intention': intention,
      });
    } else {
      ecriture = _presencesCol.doc().set({
        'userId': uid,
        'repetitionId': widget.repetitionId,
        ...champs,
      });
    }
    ecriture.catchError((Object e) {
      _pointes.remove(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pointage refusé : $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {});
      }
    });
  }

  void _afficher(_Resultat r, {bool vibrationForte = false}) {
    vibrationForte
        ? HapticFeedback.heavyImpact()
        : HapticFeedback.mediumImpact();
    setState(() => _resultat = r);
  }

  // ---------------------------------------------------------------------
  // Fin du pointage : marquer les absents
  // ---------------------------------------------------------------------

  Future<void> _terminer() async {
    final absents = _attendus
        .where((uid) => _statutActuel(uid).isEmpty)
        .toList();
    if (absents.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final choix = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminer le pointage'),
        content: Text(
          '${absents.length} membre${absents.length > 1 ? 's n’ont' : ' n’a'} '
          'pas été scanné${absents.length > 1 ? 's' : ''}.\n\n'
          'Les marquer absents ? Avec excuse s’ils avaient prévenu dans '
          'l’app, sans excuse sinon. Vous pourrez corriger dans le tableau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continuer'),
            child: const Text('Continuer à scanner'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'quitter'),
            child: const Text('Quitter sans marquer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'absents'),
            child: const Text('Marquer absents'),
          ),
        ],
      ),
    );
    if (!mounted || choix == null || choix == 'continuer') return;

    if (choix == 'absents') {
      final lot = _db.batch();
      final moi = FirebaseAuth.instance.currentUser!.uid;
      for (final uid in absents) {
        final presence = _presences[uid];
        final intention = intentionDe(presence?.data ?? const {});
        final champs = <String, Object>{
          'statut': statutAbsent(
            intention: intention,
            excuseEnvoyee: _excuses.contains(uid),
          ),
          'valideePar': moi,
          'confirmedAt': FieldValue.serverTimestamp(),
        };
        if (presence != null) {
          lot.update(presence.ref, {
            ...champs,
            if (presence.data['intention'] == null && intention.isNotEmpty)
              'intention': intention,
          });
        } else {
          lot.set(_presencesCol.doc(), {
            'userId': uid,
            'repetitionId': widget.repetitionId,
            ...champs,
          });
        }
      }
      final messager = ScaffoldMessenger.of(context);
      // Pas d'attente : envoyé dès que le réseau le permet.
      lot.commit().catchError((Object e) {
        messager.showSnackBar(
          SnackBar(
            content: Text('Absences non enregistrées : $e'),
            backgroundColor: Colors.red,
          ),
        );
      });
      messager.showSnackBar(
        SnackBar(
          content: Text(
            '${absents.length} absence${absents.length > 1 ? 's' : ''} '
            'enregistrée${absents.length > 1 ? 's' : ''}.',
          ),
        ),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final membres = _membres;
    final date = widget.date;
    final aujourdhui = DateTime.now();
    final pasAujourdhui =
        date != null &&
        (date.year != aujourdhui.year ||
            date.month != aujourdhui.month ||
            date.day != aujourdhui.day);
    final debut = _debut;

    return Scaffold(
      appBar: AppBar(
        title: Text('Pointage · ${widget.repetitionTitre}'),
        actions: [
          IconButton(
            tooltip: 'Lampe',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _camera.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Changer de caméra',
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: () => _camera.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (pasAujourdhui)
            _bandeau(
              Colors.orange.shade100,
              Icons.warning_amber,
              'Attention : cette répétition n’a pas lieu aujourd’hui.',
            ),
          _bandeau(
            CouleursChorale.lavande,
            Icons.schedule,
            debut == null
                ? 'Heure de début inconnue : tout le monde est compté à '
                      'l’heure (corrigez à la main si besoin).'
                : 'Début ${_hhmm(debut)} · en retard après '
                      '${_hhmm(debut.add(Duration(minutes: _tolerance)))}',
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camera,
                  onDetect: _surDetection,
                  errorBuilder: (context, erreur) => _erreurCamera(erreur),
                ),
                // Viseur.
                Center(
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
                if (membres == null)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: _erreurChargement == null
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Impossible de charger les membres :\n'
                            '$_erreurChargement',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                  ),
              ],
            ),
          ),
          _panneauResultat(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      membres == null
                          ? 'Chargement…'
                          : 'Présents : $_nbPresents / ${_attendus.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: membres == null ? null : _terminer,
                    icon: const Icon(Icons.done_all),
                    label: const Text('Terminer'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bandeau(Color fond, IconData icone, String texte) => Material(
    color: fond,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icone, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(texte, style: const TextStyle(fontSize: 13))),
        ],
      ),
    ),
  );

  Widget _panneauResultat() {
    final r = _resultat;
    if (r == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Présentez un badge devant la caméra.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    final photo = r.photo;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      color: r.couleur,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Photo en grand : le chef vérifie que c'est bien la bonne personne.
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white24,
            backgroundImage: photo != null && photo.isNotEmpty
                ? MemoryImage(base64Decode(photo))
                : null,
            child: photo == null || photo.isEmpty
                ? Icon(r.icone, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.titre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  r.detail,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _erreurCamera(MobileScannerException erreur) {
    final texte = switch (erreur.errorCode) {
      MobileScannerErrorCode.permissionDenied =>
        'L’accès à la caméra a été refusé. Autorisez-le dans les réglages '
            'du téléphone (Applications › K.T.K.F.A › Autorisations).',
      MobileScannerErrorCode.unsupported =>
        'Cet appareil ne permet pas de scanner.',
      _ =>
        'Caméra indisponible : ${erreur.errorDetails?.message ?? erreur.errorCode.name}',
    };
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Text(
        texte,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  static String _nom(Map<String, dynamic> fiche) {
    final nom = fiche['Nom'];
    return nom is String && nom.trim().isNotEmpty ? nom.trim() : 'Sans nom';
  }

  static String _hhmm(DateTime d) =>
      '${d.hour}h${d.minute.toString().padLeft(2, '0')}';

  static String _libelleStatut(String statut) => switch (statut) {
    'present_heure' => 'À l’heure',
    'present_retard_excuse' => 'En retard (excusé)',
    'present_retard_sans_excuse' => 'En retard sans excuse',
    'absent_excuse' => 'Absent (excusé)',
    'absent_sans_excuse' => 'Absent sans excuse',
    _ => statut,
  };
}
