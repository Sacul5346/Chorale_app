import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'messagerie.dart';
import 'pointage.dart' show intentionDe, statutConstateDe;
import 'roles.dart';
import 'theme.dart';

/// Conversation d'excuse entre un membre et la direction (chef ou suppléant)
/// pour une répétition.
///
/// Les écritures ne sont jamais attendues : hors connexion, Firestore les
/// garde sur le téléphone et les envoie au retour du réseau (attendre
/// bloquerait l'écran jusque-là).
class ConversationScreen extends StatefulWidget {
  final String repetitionId;
  final String repetitionTitre;
  final String membreId;

  /// Nom du membre (affiché à la direction).
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

const _police = 'Poppins';

class _ConversationScreenState extends State<ConversationScreen> {
  final _saisie = TextEditingController();
  final _scroll = ScrollController();
  final _db = FirebaseFirestore.instance;
  final _moi = FirebaseAuth.instance.currentUser!.uid;

  /// Messages déjà marqués « lu » pendant cette visite (pas de doublons).
  final _dejaMarques = <String>{};

  String _monNom = '';
  String _monRole = 'membre'; // chef | suppleant | membre

  late final _conv = _db
      .collection('conversations')
      .doc('${widget.repetitionId}_${widget.membreId}');

  /// Le membre consulte sa propre conversation ; sinon, c'est la direction.
  bool get _vueMembre => _moi == widget.membreId;

  @override
  void initState() {
    super.initState();
    _chargerMonProfil();
    // Conversation lue par celui qui l'ouvre. Échec ignoré : elle n'existe
    // pas encore si aucun message n'a été envoyé.
    _conv
        .update({_vueMembre ? 'unreadByMembre' : 'unreadByResponsable': false})
        .catchError((_) {});
  }

  Future<void> _chargerMonProfil() async {
    try {
      final fiche = (await _db.collection('users').doc(_moi).get()).data();
      if (fiche == null || !mounted) return;
      setState(() {
        final nom = fiche['Nom'];
        _monNom = nom is String ? nom.trim() : '';
        _monRole = _vueMembre
            ? 'membre'
            : roleNormalise(fiche['role']) == 'chef'
            ? 'chef'
            : estSuppleant(fiche, DateTime.now())
            ? 'suppleant'
            : 'chef';
      });
    } catch (_) {
      // Hors connexion au premier lancement : rôle par défaut.
    }
  }

  @override
  void dispose() {
    _saisie.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Envoi, suppression
  // ---------------------------------------------------------------------

  void _envoyer([String? texteImpose]) {
    final texte = (texteImpose ?? _saisie.text).trim();
    if (texte.isEmpty) return;
    if (texteImpose == null) _saisie.clear();

    final deLaDirection = !_vueMembre;
    _conv
        .set({
          'repetitionId': widget.repetitionId,
          'membreId': widget.membreId,
          'lastMessage': texte,
          'lastSentAt': FieldValue.serverTimestamp(),
          'unreadByResponsable': !deLaDirection,
          'unreadByMembre': deLaDirection,
        }, SetOptions(merge: true))
        .catchError(_erreur);
    _conv
        .collection('messages')
        .add({
          'texte': texte,
          'senderId': _moi,
          'senderNom': _monNom,
          'senderRole': _vueMembre ? 'membre' : _monRole,
          'lu': false,
          'sentAt': FieldValue.serverTimestamp(),
          // Heure du téléphone, affichée tant que celle du serveur manque.
          'envoyeLe': Timestamp.now(),
        })
        .then<void>((_) {}, onError: _erreur);
    _allerEnBas(anime: true);
  }

  Future<void> _supprimer(
    DocumentReference<Map<String, dynamic>> message,
    bool estLeDernier,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: const Text(
          'Il sera remplacé par « Message supprimé » pour vous deux.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    message.update({'texte': '', 'supprime': true}).catchError(_erreur);
    if (estLeDernier) {
      _conv.update({'lastMessage': messageSupprime}).catchError(_erreur);
    }
  }

  /// La direction accepte l'excuse : réponse automatique et, si le membre
  /// avait annoncé son absence, présence « absent avec excuse ».
  Future<void> _accepterExcuse() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Accepter l’excuse ?'),
        content: Text(
          '${widget.membreNom} recevra « $messageExcuseAcceptee ». S’il a '
          'annoncé son absence, elle sera enregistrée « absent avec excuse » '
          'pour ${widget.repetitionTitre}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _envoyer(messageExcuseAcceptee);

    final messager = ScaffoldMessenger.of(context);
    try {
      final presences = _db.collection('presences');
      final existante = await presences
          .where('repetitionId', isEqualTo: widget.repetitionId)
          .where('userId', isEqualTo: widget.membreId)
          .limit(1)
          .get();
      final data = existante.docs.isEmpty
          ? const <String, dynamic>{}
          : existante.docs.first.data();
      final statut = statutExcuseAcceptee(
        intention: intentionDe(data),
        statutConstate: statutConstateDe(data),
      );
      if (statut == null) {
        messager.showSnackBar(
          const SnackBar(content: Text('Excuse acceptée. Présence inchangée.')),
        );
        return;
      }
      final champs = {
        'statut': statut,
        'valideePar': _moi,
        'confirmedAt': FieldValue.serverTimestamp(),
      };
      if (existante.docs.isEmpty) {
        presences
            .add({
              'userId': widget.membreId,
              'repetitionId': widget.repetitionId,
              ...champs,
            })
            .then<void>((_) {}, onError: _erreur);
      } else {
        existante.docs.first.reference.update(champs).catchError(_erreur);
      }
      messager.showSnackBar(
        const SnackBar(
          content: Text('Excuse acceptée : absent avec excuse.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _erreur(e);
    }
  }

  void _erreur(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
    );
  }

  void _allerEnBas({bool anime = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final fin = _scroll.position.maxScrollExtent;
      anime
          ? _scroll.animateTo(
              fin,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
          : _scroll.jumpTo(fin);
    });
  }

  // ---------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CouleursChorale.creme,
      appBar: AppBar(
        backgroundColor: CouleursChorale.aubergine,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: EnteteConversation(
          titre: _vueMembre ? 'Chef de chorale' : widget.membreNom,
          sousTitre: widget.repetitionTitre,
        ),
      ),
      body: Column(
        children: [
          if (!_vueMembre) _bandeauReponse(),
          Expanded(child: _messages()),
          if (!_vueMembre)
            ReponsesRapides(onAccepter: _accepterExcuse, onReponse: _envoyer),
          ZoneSaisie(controleur: _saisie, onEnvoyer: () => _envoyer()),
        ],
      ),
    );
  }

  /// Pour la direction : ce que le membre a répondu pour la répétition.
  Widget _bandeauReponse() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('presences')
          .where('repetitionId', isEqualTo: widget.repetitionId)
          .where('userId', isEqualTo: widget.membreId)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.docs.firstOrNull?.data() ?? const {};
        final intention = intentionDe(data);
        final statut = statutConstateDe(data);
        final (texte, couleur) = switch (intention) {
          'absent' => ('Absent', Colors.red.shade700),
          'retard' => ('En retard', Colors.orange.shade800),
          'present' => ('Vient', Colors.green.shade700),
          _ => ('Pas de réponse', CouleursChorale.aubergineClair),
        };
        return Container(
          width: double.infinity,
          color: CouleursChorale.lavande,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Text(
                'Réponse du membre : ',
                style: TextStyle(fontFamily: _police, fontSize: 12.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: couleur,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  texte,
                  style: const TextStyle(
                    fontFamily: _police,
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (statut == 'absent_excuse') ...[
                const SizedBox(width: 8),
                const Icon(Icons.verified, size: 16, color: Colors.green),
                const SizedBox(width: 2),
                const Text(
                  'Excusé',
                  style: TextStyle(fontFamily: _police, fontSize: 12),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _messages() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _conv.collection('messages').orderBy('sentAt').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return MessageVide(vueMembre: _vueMembre);
        }

        // Messages de l'autre personne : marqués lus (une fois chacun).
        for (final d in docs) {
          final m = d.data();
          if (m['senderId'] != _moi &&
              m['lu'] == false &&
              _dejaMarques.add(d.id)) {
            d.reference.update({'lu': true}).catchError((_) {});
          }
        }
        _allerEnBas();

        final maintenant = DateTime.now();
        // Dernier message envoyé par moi : c'est lui qui porte « Vu ».
        final dernierAMoi = docs.lastIndexWhere(
          (d) => d.data()['senderId'] == _moi,
        );

        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final m = docs[i].data();
            final date = dateMessage(m) ?? maintenant;
            final precedent = i == 0 ? null : docs[i - 1].data();
            final datePrecedente = precedent == null
                ? null
                : dateMessage(precedent) ?? maintenant;
            final aMoi = m['senderId'] == _moi;
            final supprime = m['supprime'] == true;
            final memeAuteur =
                precedent != null &&
                precedent['senderId'] == m['senderId'] &&
                !nouveauJour(datePrecedente, date);

            return Column(
              children: [
                if (nouveauJour(datePrecedente, date))
                  SeparateurJour(libelle: libelleJour(date, maintenant)),
                BulleMessage(
                  texte: supprime ? '' : (m['texte'] as String? ?? ''),
                  supprime: supprime,
                  aMoi: aMoi,
                  // Nom de l'auteur au début d'une série de l'autre personne.
                  auteur: aMoi || memeAuteur
                      ? null
                      : m['senderId'] == widget.membreId
                      ? widget.membreNom
                      : libelleDirection(m['senderRole']),
                  heure: heure(date),
                  vu: i == dernierAMoi ? m['lu'] == true : null,
                  onSupprimer: aMoi && !supprime
                      ? () =>
                            _supprimer(docs[i].reference, i == docs.length - 1)
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Date d'un message : heure serveur, sinon heure du téléphone (message en
/// attente d'envoi), sinon null.
DateTime? dateMessage(Map<String, dynamic> m) {
  final serveur = m['sentAt'];
  if (serveur is Timestamp) return serveur.toDate();
  final local = m['envoyeLe'];
  return local is Timestamp ? local.toDate() : null;
}

// -------------------------------------------------------------------------
// Éléments d'affichage (publics : réutilisés par l'aperçu en image)
// -------------------------------------------------------------------------

class EnteteConversation extends StatelessWidget {
  final String titre;
  final String sousTitre;
  const EnteteConversation({
    super.key,
    required this.titre,
    required this.sousTitre,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: CouleursChorale.or,
          child: Text(
            titre.isEmpty ? '?' : titre[0].toUpperCase(),
            style: const TextStyle(
              fontFamily: _police,
              color: CouleursChorale.aubergineFonce,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titre,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _police,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                sousTitre,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: _police,
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SeparateurJour extends StatelessWidget {
  final String libelle;
  const SeparateurJour({super.key, required this.libelle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CouleursChorale.lavandeFonce,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            libelle,
            style: const TextStyle(
              fontFamily: _police,
              fontSize: 11.5,
              color: CouleursChorale.aubergine,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class BulleMessage extends StatelessWidget {
  final String texte;
  final bool supprime;
  final bool aMoi;

  /// Nom affiché au-dessus (début d'une série de l'autre personne).
  final String? auteur;
  final String heure;

  /// Dernier message envoyé : true = lu, false = envoyé ; null = rien.
  final bool? vu;

  /// Appui long sur son propre message.
  final VoidCallback? onSupprimer;

  const BulleMessage({
    super.key,
    required this.texte,
    required this.aMoi,
    required this.heure,
    this.supprime = false,
    this.auteur,
    this.vu,
    this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    const pointe = Radius.circular(4);
    final fond = supprime
        ? Colors.transparent
        : aMoi
        ? CouleursChorale.aubergine
        : Colors.white;
    final couleurTexte = aMoi && !supprime
        ? Colors.white
        : const Color(0xFF2B2233);
    final couleurHeure = aMoi && !supprime
        ? Colors.white70
        : CouleursChorale.aubergineClair;

    return Align(
      alignment: aMoi ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(top: auteur != null ? 8 : 2, bottom: 2),
        child: Column(
          crossAxisAlignment: aMoi
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (auteur != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 3),
                child: Text(
                  auteur!,
                  style: const TextStyle(
                    fontFamily: _police,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: CouleursChorale.aubergineClair,
                  ),
                ),
              ),
            GestureDetector(
              onLongPress: onSupprimer,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                padding: const EdgeInsets.fromLTRB(14, 9, 12, 7),
                decoration: BoxDecoration(
                  color: fond,
                  border: supprime || !aMoi
                      ? Border.all(color: CouleursChorale.bordure)
                      : null,
                  borderRadius: BorderRadius.only(
                    topLeft: r,
                    topRight: r,
                    bottomLeft: aMoi ? r : pointe,
                    bottomRight: aMoi ? pointe : r,
                  ),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  children: [
                    if (supprime)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.block,
                            size: 15,
                            color: CouleursChorale.aubergineClair,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            messageSupprime,
                            style: TextStyle(
                              fontFamily: _police,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: couleurHeure,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        texte,
                        style: TextStyle(
                          fontFamily: _police,
                          fontSize: 15,
                          height: 1.35,
                          color: couleurTexte,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        heure,
                        style: TextStyle(
                          fontFamily: _police,
                          fontSize: 10.5,
                          color: couleurHeure,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (vu != null)
              Padding(
                padding: const EdgeInsets.only(top: 3, right: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      vu! ? Icons.done_all : Icons.done,
                      size: 14,
                      color: vu! ? CouleursChorale.or : Colors.grey,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      vu! ? 'Vu' : 'Envoyé',
                      style: const TextStyle(
                        fontFamily: _police,
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Réponses rapides de la direction, dont « Accepter l'excuse ».
class ReponsesRapides extends StatelessWidget {
  final VoidCallback onAccepter;
  final ValueChanged<String> onReponse;
  const ReponsesRapides({
    super.key,
    required this.onAccepter,
    required this.onReponse,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
        children: [
          ActionChip(
            avatar: const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            label: const Text('Accepter l’excuse'),
            labelStyle: const TextStyle(
              fontFamily: _police,
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
            backgroundColor: Colors.green.shade700,
            side: BorderSide.none,
            onPressed: onAccepter,
          ),
          for (final r in reponsesRapides) ...[
            const SizedBox(width: 8),
            ActionChip(
              label: Text(r),
              labelStyle: const TextStyle(
                fontFamily: _police,
                fontSize: 12.5,
                color: CouleursChorale.aubergine,
              ),
              backgroundColor: Colors.white,
              side: const BorderSide(color: CouleursChorale.bordure),
              onPressed: () => onReponse(r),
            ),
          ],
        ],
      ),
    );
  }
}

class ZoneSaisie extends StatelessWidget {
  final TextEditingController controleur;
  final VoidCallback onEnvoyer;
  const ZoneSaisie({
    super.key,
    required this.controleur,
    required this.onEnvoyer,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controleur,
                  minLines: 1,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontFamily: _police, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Écrire un message…',
                    hintStyle: const TextStyle(fontFamily: _police),
                    filled: true,
                    fillColor: CouleursChorale.creme,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: CouleursChorale.aubergine,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(46, 46),
                ),
                tooltip: 'Envoyer',
                icon: const Icon(Icons.send_rounded, size: 20),
                onPressed: onEnvoyer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageVide extends StatelessWidget {
  final bool vueMembre;
  const MessageVide({super.key, required this.vueMembre});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 56,
              color: CouleursChorale.aubergineClair,
            ),
            const SizedBox(height: 12),
            Text(
              vueMembre
                  ? 'Expliquez ici votre absence ou votre retard : le chef '
                        'vous répondra.'
                  : 'Aucun message pour le moment.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: _police,
                color: CouleursChorale.aubergineClair,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
