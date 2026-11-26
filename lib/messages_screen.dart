import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'conversation_screen.dart';
import 'messagerie.dart';
import 'theme.dart';

/// Excuses reçues par la direction (chef ou suppléant), regroupées par
/// répétition (la plus récente en haut), avec un filtre « Non lus ». Les
/// conversations des répétitions supprimées sont réunies à la fin et
/// peuvent être effacées d'un coup.
///
/// Données légères : seuls les membres et les répétitions qui ont une
/// conversation sont chargés (pas toute la base), une seule fois.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

const _police = 'Poppins';

/// Conversations affichées au plus (les plus récentes).
const _maxConversations = 100;

class _MessagesScreenState extends State<MessagesScreen> {
  final _db = FirebaseFirestore.instance;
  bool _nonLusSeulement = false;

  final _membres = <String, Map<String, dynamic>>{};
  final _repetitions = <String, InfoRepetition>{};
  final _enChargement = <String>{};

  /// Charge, par paquets de 30, les documents pas encore connus.
  Future<void> _completer(
    String collection,
    Iterable<String> ids,
    void Function(String id, Map<String, dynamic> data) ranger,
    Map<String, Object?> connus,
  ) async {
    final manquants = ids
        .where((id) => !connus.containsKey(id) && _enChargement.add(id))
        .toList();
    for (var i = 0; i < manquants.length; i += 30) {
      final paquet = manquants.skip(i).take(30).toList();
      try {
        final snap = await _db
            .collection(collection)
            .where(FieldPath.documentId, whereIn: paquet)
            .get();
        for (final d in snap.docs) {
          ranger(d.id, d.data());
        }
        // Absents de la base : supprimés depuis (conversation orpheline).
        final trouves = snap.docs.map((d) => d.id).toSet();
        for (final id in paquet.where((id) => !trouves.contains(id))) {
          ranger(id, const {'supprime': true});
        }
      } catch (_) {
        // Hors connexion : on réessaiera au prochain affichage.
        _enChargement.removeAll(paquet);
      }
    }
    if (mounted && manquants.isNotEmpty) setState(() {});
  }

  void _chargerManquants(List<QueryDocumentSnapshot<Map<String, dynamic>>> c) {
    final membres = {
      for (final d in c)
        if (d.data()['membreId'] is String) d.data()['membreId'] as String,
    };
    final reps = {
      for (final d in c)
        if (d.data()['repetitionId'] is String)
          d.data()['repetitionId'] as String,
    };
    _completer('users', membres, (id, d) => _membres[id] = d, _membres);
    _completer(
      'repetitions',
      reps,
      (id, d) => _repetitions[id] = d['supprime'] == true
          ? const InfoRepetition.supprimee()
          : InfoRepetition(
              d['titre'] is String ? d['titre'] as String : 'Répétition',
              d['date'] is Timestamp ? (d['date'] as Timestamp).toDate() : null,
            ),
      _repetitions,
    );
  }

  Future<void> _supprimerConversation(
    DocumentReference<Map<String, dynamic>> conv,
    String nom,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la conversation ?'),
        content: Text(
          'Tous les messages avec $nom pour cette répétition seront '
          'définitivement supprimés.',
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
    await _effacer([conv]);
  }

  /// Efface des conversations et leurs messages. Firestore ne supprime pas
  /// les sous-collections avec leur parent : on les vide d'abord.
  Future<void> _effacer(
    List<DocumentReference<Map<String, dynamic>>> convs,
  ) async {
    try {
      var lot = _db.batch();
      var operations = 0;
      for (final conv in convs) {
        final messages = await conv.collection('messages').get();
        for (final ref in [...messages.docs.map((m) => m.reference), conv]) {
          lot.delete(ref);
          // Un lot Firestore est limité à 500 opérations.
          if (++operations == 450) {
            lot.commit().catchError((Object e) => _erreur(e));
            lot = _db.batch();
            operations = 0;
          }
        }
      }
      if (operations > 0) lot.commit().catchError((Object e) => _erreur(e));
    } catch (e) {
      _erreur(e);
    }
  }

  /// Nettoyage : toutes les conversations des répétitions supprimées.
  Future<void> _nettoyer(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> orphelines,
  ) async {
    final n = orphelines.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nettoyer les excuses ?'),
        content: Text(
          '$n conversation${n > 1 ? 's concernent' : ' concerne'} des '
          'répétitions qui n’existent plus. '
          '${n > 1 ? 'Elles seront définitivement effacées' : 'Elle sera définitivement effacée'}, '
          'avec leurs messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _effacer([for (final c in orphelines) c.reference]);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$n conversation${n > 1 ? 's effacées' : ' effacée'}.'),
        ),
      );
    }
  }

  void _erreur(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Erreur : $e'), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('conversations')
          .orderBy('lastSentAt', descending: true)
          .limit(_maxConversations)
          .snapshots(),
      builder: (context, snapshot) {
        final toutes = snapshot.data?.docs ?? const [];
        _chargerManquants(toutes);
        final orphelines = toutes
            .where(
              (d) => _repetitions[d.data()['repetitionId']]?.supprimee ?? false,
            )
            .toList();
        return Scaffold(
          backgroundColor: CouleursChorale.creme,
          appBar: AppBar(
            title: const Text('Excuses'),
            actions: [
              if (orphelines.isNotEmpty)
                IconButton(
                  tooltip: 'Effacer les excuses des répétitions supprimées',
                  icon: Badge(
                    label: Text('${orphelines.length}'),
                    child: const Icon(Icons.cleaning_services_outlined),
                  ),
                  onPressed: () => _nettoyer(orphelines),
                ),
            ],
          ),
          body: _corps(snapshot, toutes),
        );
      },
    );
  }

  Widget _corps(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> toutes,
  ) {
    if (snapshot.hasError) {
      return const Center(child: Text('Impossible de charger.'));
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final nonLues = toutes
        .where((d) => d.data()['unreadByResponsable'] == true)
        .toList();
    final liste = _nonLusSeulement ? nonLues : toutes;
    final groupes = grouperParRepetition(
      liste,
      (d) => d.data()['repetitionId'] as String? ?? '',
      _repetitions,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Row(
            children: [
              ChoiceChip(
                label: Text('Tous (${toutes.length})'),
                selected: !_nonLusSeulement,
                onSelected: (_) => setState(() => _nonLusSeulement = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Non lus (${nonLues.length})'),
                selected: _nonLusSeulement,
                onSelected: (_) => setState(() => _nonLusSeulement = true),
              ),
            ],
          ),
        ),
        Expanded(
          child: liste.isEmpty
              ? _vide()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                  children: [
                    for (final g in groupes) ...[
                      _enteteGroupe(g),
                      for (final c in g.conversations) _carte(c),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// En-tête de section : date de la répétition (ou « Répétitions
  /// supprimées »), son titre s'il est personnalisé, et le nombre d'excuses.
  Widget _enteteGroupe(
    GroupeExcuses<QueryDocumentSnapshot<Map<String, dynamic>>> g,
  ) {
    final date = g.info?.date;
    final titre = g.supprimees
        ? 'Répétitions supprimées'
        : date != null
        ? titreGroupe(date, DateTime.now())
        : (g.info?.titre ?? '…');
    // Titre personnalisé (« Concert de Noël ») : affiché sous la date.
    final perso = g.info?.titre ?? '';
    final sousTitre =
        !g.supprimees &&
            date != null &&
            perso.isNotEmpty &&
            !perso.startsWith('Répétition du ')
        ? perso
        : g.supprimees
        ? 'Appui long sur une excuse, ou 🧹 en haut pour tout effacer'
        : null;
    final n = g.conversations.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(
            g.supprimees ? Icons.event_busy : Icons.event,
            size: 18,
            color: g.supprimees
                ? CouleursChorale.aubergineClair
                : CouleursChorale.or,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre.toUpperCase(),
                  style: TextStyle(
                    fontFamily: _police,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: g.supprimees
                        ? CouleursChorale.aubergineClair
                        : CouleursChorale.aubergine,
                  ),
                ),
                if (sousTitre != null)
                  Text(
                    sousTitre,
                    style: const TextStyle(
                      fontFamily: _police,
                      fontSize: 11.5,
                      color: CouleursChorale.aubergineClair,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '$n excuse${n > 1 ? 's' : ''}',
            style: const TextStyle(
              fontFamily: _police,
              fontSize: 11.5,
              color: CouleursChorale.aubergineClair,
            ),
          ),
        ],
      ),
    );
  }

  Widget _vide() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.mark_chat_read_outlined,
          size: 56,
          color: CouleursChorale.aubergineClair,
        ),
        const SizedBox(height: 12),
        Text(
          _nonLusSeulement
              ? 'Aucune excuse non lue.'
              : 'Aucune excuse pour le moment.',
          style: const TextStyle(
            fontFamily: _police,
            color: CouleursChorale.aubergineClair,
          ),
        ),
      ],
    ),
  );

  Widget _carte(QueryDocumentSnapshot<Map<String, dynamic>> conv) {
    final c = conv.data();
    final membreId = c['membreId'] as String? ?? '';
    final repId = c['repetitionId'] as String? ?? '';
    final fiche = _membres[membreId];
    final nomBrut = fiche?['Nom'];
    final nom = nomBrut is String && nomBrut.trim().isNotEmpty
        ? nomBrut.trim()
        : fiche == null
        ? '…'
        : fiche['supprime'] == true
        ? 'Membre supprimé'
        : 'Sans nom';
    final info = _repetitions[repId];
    final repTitre = info == null
        ? 'Répétition'
        : info.supprimee
        ? repetitionSupprimee
        : info.titre;
    final photo = fiche?['photoBase64'];
    final nonLu = c['unreadByResponsable'] == true;
    final dernier = c['lastMessage'] is String
        ? c['lastMessage'] as String
        : '';
    final date = c['lastSentAt'] is Timestamp
        ? dateCourte((c['lastSentAt'] as Timestamp).toDate(), DateTime.now())
        : '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: nonLu ? 2 : 0,
      color: nonLu ? Colors.white : Colors.white.withValues(alpha: 0.75),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: nonLu ? CouleursChorale.or : CouleursChorale.bordure,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onLongPress: () => _supprimerConversation(conv.reference, nom),
        onTap: () {
          // Pas d'attente : hors connexion, l'écran s'ouvrirait jamais.
          conv.reference
              .update({'unreadByResponsable': false})
              .catchError((_) {});
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ConversationScreen(
                repetitionId: repId,
                repetitionTitre: repTitre,
                membreId: membreId,
                membreNom: nom,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: CouleursChorale.lavandeFonce,
                backgroundImage: photo is String && photo.isNotEmpty
                    ? MemoryImage(base64Decode(photo))
                    : null,
                child: photo is String && photo.isNotEmpty
                    ? null
                    : Text(
                        nom[0].toUpperCase(),
                        style: const TextStyle(
                          fontFamily: _police,
                          color: CouleursChorale.aubergine,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            nom,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _police,
                              fontSize: 15,
                              fontWeight: nonLu
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontFamily: _police,
                            fontSize: 11.5,
                            color: nonLu
                                ? CouleursChorale.or
                                : CouleursChorale.aubergineClair,
                            fontWeight: nonLu
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dernier,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: _police,
                              fontSize: 13,
                              color: nonLu
                                  ? const Color(0xFF2B2233)
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (nonLu)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: CouleursChorale.or,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
