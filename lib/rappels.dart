import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'anniversaires.dart';
import 'parametres.dart';
import 'repetition_model.dart';
import 'versets.dart';

/// Notifications locales, programmées sur le téléphone (sans serveur) :
///  - un rappel la veille de chaque répétition à venir, à 18h ;
///  - une alerte quand une répétition à venir est annulée. Elle arrive
///    quand l'app se synchronise (à l'ouverture), pas en temps réel :
///    une vraie notification « push » demanderait un serveur (forfait Blaze).

/// Madagascar : UTC+3 toute l'année, sans heure d'été. Un fuseau fixe évite
/// d'embarquer toute la base des fuseaux horaires dans l'app.
final tz.Location madagascar = tz.Location(
  'Indian/Antananarivo',
  [tz.minTime],
  [0],
  [const tz.TimeZone(Duration(hours: 3), isDst: false, abbreviation: 'EAT')],
);

/// Identifiant de notification stable pour une répétition (le `hashCode`
/// des chaînes n'est pas garanti d'une exécution à l'autre).
int idRappel(String repetitionId) {
  var h = 0;
  for (final c in repetitionId.codeUnits) {
    h = (h * 31 + c) & 0x1fffffff;
  }
  return h;
}

/// Les alertes d'annulation utilisent une autre plage d'identifiants.
int idAnnulation(String repetitionId) => idRappel(repetitionId) | 0x20000000;

class RappelPrevu {
  final int id;
  final tz.TZDateTime quand;
  final String titre;
  final String corps;

  /// Type : 'rappel', 'verset' ou 'anniversaire'.
  final String type;

  RappelPrevu(
    this.id,
    this.quand,
    this.titre,
    this.corps, [
    this.type = 'rappel',
  ]);
}

/// Verset du jour : plage d'identifiants 0x30000000.
int idVerset(DateTime jour) =>
    0x30000000 |
    ((DateTime.utc(jour.year, jour.month, jour.day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay) &
        0x0fffffff);

/// Anniversaire : plage d'identifiants 0x40000000.
int idAnniversaire(String uid) => 0x40000000 | idRappel(uid);

/// Versets des [jours] prochains jours, à [heure] h (heure de Madagascar).
/// Programmés d'avance : ils arrivent même si l'app n'est pas ouverte.
List<RappelPrevu> versetsAProgrammer(
  DateTime maintenant, {
  int heure = 6,
  int jours = 21,
}) {
  final debut = dateSansHeure(maintenant);
  return [
    for (var i = 0; i <= jours; i++)
      if (tz.TZDateTime(
            madagascar,
            debut.year,
            debut.month,
            debut.day + i,
            heure,
          )
          case final quand when quand.isAfter(maintenant))
        () {
          final v = versetDuJour(DateTime(quand.year, quand.month, quand.day));
          return RappelPrevu(
            idVerset(DateTime(quand.year, quand.month, quand.day)),
            quand,
            '📖 Verset du jour',
            '« ${v.texte} » — ${v.reference}',
            'verset',
          );
        }(),
  ];
}

/// Anniversaires des [jours] prochains jours, le jour J à [heure] h.
/// [monUid] : la personne concernée reçoit un message personnel.
List<RappelPrevu> anniversairesAProgrammer(
  Iterable<Anniversaire> anniversaires,
  DateTime maintenant, {
  String? monUid,
  int heure = 8,
  int jours = 60,
}) {
  final limite = dateSansHeure(maintenant).add(Duration(days: jours));
  return [
    for (final (a, date) in anniversairesAVenir(anniversaires, maintenant))
      if (!date.isAfter(limite))
        if (tz.TZDateTime(madagascar, date.year, date.month, date.day, heure)
            case final quand when quand.isAfter(maintenant))
          a.uid == monUid
              ? RappelPrevu(
                  idAnniversaire(a.uid),
                  quand,
                  '🎉 Joyeux anniversaire, ${a.nom} !',
                  'Toute la chorale vous souhaite une très belle journée.',
                  'anniversaire',
                )
              : RappelPrevu(
                  idAnniversaire(a.uid),
                  quand,
                  '🎂 Anniversaire',
                  'Aujourd’hui, c’est l’anniversaire de ${a.nom} ! '
                      'Pensez à lui souhaiter.',
                  'anniversaire',
                ),
  ];
}

/// Rappels à programmer : la veille à [heure] h (heure de Madagascar,
/// réglable dans les Paramètres de la chorale) de chaque répétition active
/// dont le rappel n'est pas déjà passé.
List<RappelPrevu> rappelsAProgrammer(
  List<Repetition> repetitions,
  DateTime maintenant, {
  int heure = 18,
}) {
  return [
    for (final rep in repetitions)
      if (rep.statut != 'annulé')
        if (tz.TZDateTime(
              madagascar,
              rep.date.year,
              rep.date.month,
              rep.date.day - 1,
              heure,
            )
            case final quand when quand.isAfter(maintenant))
          RappelPrevu(
            idRappel(rep.id),
            quand,
            'Rappel : ${rep.titre}',
            '${['Demain${rep.heure.isNotEmpty ? ' à ${rep.heure}' : ''}', if (rep.lieu.isNotEmpty) rep.lieu].join(' — ')}. Prévenez dans l’app si vous ne venez pas.',
          ),
  ];
}

/// Répétitions à venir annulées qui n'ont pas encore été signalées.
List<Repetition> annulationsASignaler(
  List<Repetition> repetitions,
  Set<String> dejaSignalees,
  DateTime maintenant,
) {
  final aujourdhui = dateSansHeure(maintenant);
  return repetitions
      .where(
        (r) =>
            r.statut == 'annulé' &&
            !r.date.isBefore(aujourdhui) &&
            !dejaSignalees.contains(r.id),
      )
      .toList();
}

class Rappels {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _pret = false;
  static const _typesGeres = {'rappel', 'verset', 'anniversaire'};
  static const _cleAnnulations = 'annulations_signalees';

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'repetitions',
      'Répétitions',
      channelDescription: 'Rappels et annulations de répétitions',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _detailsParType = {
    'rappel': _details,
    'verset': NotificationDetails(
      android: AndroidNotificationDetails(
        'verset',
        'Verset du jour',
        channelDescription: 'Un verset d’encouragement chaque matin',
      ),
    ),
    'anniversaire': NotificationDetails(
      android: AndroidNotificationDetails(
        'anniversaires',
        'Anniversaires',
        channelDescription: 'Anniversaires des membres de la chorale',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  };

  /// Seule l'app Android programme des notifications.
  static bool get _supporte =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _initialiser() async {
    if (_pret) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    // Android 13+ : demande l'autorisation d'afficher des notifications.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _pret = true;
  }

  /// Annule tous les rappels programmés (compte désactivé).
  static Future<void> toutAnnuler() async {
    if (!_supporte) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Rappels : $e');
    }
  }

  /// Aligne les notifications programmées sur la liste des répétitions.
  /// Les notifications sont un bonus : une erreur ici ne doit jamais
  /// empêcher d'utiliser l'app.
  static Future<void> synchroniser(
    List<Repetition> repetitions, {
    required bool alerterAnnulations,
    int heureRappel = 18,
    bool versetActif = true,
    int heureVerset = 6,
    List<Anniversaire> anniversaires = const [],
    String? monUid,
  }) async {
    if (!_supporte) return;
    try {
      await _initialiser();
      final maintenant = DateTime.now();

      // 1. Notifications programmées : rappels de la veille, verset du
      //    jour, anniversaires.
      final prevus = [
        ...rappelsAProgrammer(repetitions, maintenant, heure: heureRappel),
        if (versetActif) ...versetsAProgrammer(maintenant, heure: heureVerset),
        ...anniversairesAProgrammer(anniversaires, maintenant, monUid: monUid),
      ];
      final idsPrevus = prevus.map((r) => r.id).toSet();
      for (final attente in await _plugin.pendingNotificationRequests()) {
        if (_typesGeres.contains(attente.payload) &&
            !idsPrevus.contains(attente.id)) {
          await _plugin.cancel(id: attente.id);
        }
      }
      for (final r in prevus) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: r.quand,
          notificationDetails: r.type == 'verset'
              // Texte long : le verset entier s'affiche en dépliant.
              ? NotificationDetails(
                  android: AndroidNotificationDetails(
                    'verset',
                    'Verset du jour',
                    channelDescription:
                        'Un verset d’encouragement chaque matin',
                    styleInformation: BigTextStyleInformation(r.corps),
                  ),
                )
              : _detailsParType[r.type] ?? _details,
          // Inexact : pas d'autorisation « alarmes exactes » à demander ;
          // Android peut décaler la notification de quelques minutes.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.titre,
          body: r.corps,
          payload: r.type,
        );
      }

      // 2. Annulations.
      final prefs = await SharedPreferences.getInstance();
      final connues = prefs.getStringList(_cleAnnulations);
      final annulees = annulationsASignaler(
        repetitions,
        (connues ?? const []).toSet(),
        maintenant,
      );
      // Premier lancement : on mémorise les annulations existantes sans
      // les signaler (elles sont déjà visibles dans l'app).
      if (connues != null && alerterAnnulations) {
        for (final rep in annulees) {
          await _plugin.show(
            id: idAnnulation(rep.id),
            title: 'Répétition annulée',
            body:
                '${rep.titre} du ${rep.date.day}/${rep.date.month}'
                '${rep.causeAnnulation.isNotEmpty ? ' : ${rep.causeAnnulation}' : ''}',
            notificationDetails: _details,
          );
        }
      }
      await prefs.setStringList(_cleAnnulations, [
        ...?connues,
        ...annulees.map((r) => r.id),
      ]);
    } catch (e) {
      debugPrint('Rappels : $e');
    }
  }
}

/// Écoute les répétitions tant que l'utilisateur est connecté et tient les
/// notifications à jour.
class RappelsSync extends StatefulWidget {
  final String role;
  final Widget child;

  const RappelsSync({super.key, required this.role, required this.child});

  @override
  State<RappelsSync> createState() => _RappelsSyncState();
}

class _RappelsSyncState extends State<RappelsSync> {
  final _abonnements = <StreamSubscription<Object?>>[];
  List<Repetition>? _repetitions;
  ParametresChorale _parametres = ParametresChorale.defaut;
  List<Anniversaire> _anniversaires = const [];

  @override
  void initState() {
    super.initState();
    if (!Rappels._supporte) return;
    _abonnements
      ..add(
        FirebaseFirestore.instance
            .collection('repetitions')
            .where(
              'date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                dateSansHeure(DateTime.now()),
              ),
            )
            .snapshots()
            .listen((snap) {
              _repetitions = snap.docs.map(Repetition.fromFirestore).toList();
              _synchroniser();
            }),
      )
      // Changer une heure dans les paramètres reprogramme tout.
      ..add(
        ParametresChorale.ecouter().listen((p) {
          _parametres = p;
          _synchroniser();
        }),
      )
      ..add(
        ecouterAnniversaires().handleError((_) {}).listen((liste) {
          _anniversaires = liste;
          _synchroniser();
        }),
      );
  }

  void _synchroniser() {
    final reps = _repetitions;
    if (reps == null) return;
    Rappels.synchroniser(
      reps,
      // Le chef annule lui-même : inutile de l'alerter.
      alerterAnnulations: widget.role != 'chef',
      heureRappel: _parametres.heureRappel,
      versetActif: _parametres.versetActif,
      heureVerset: _parametres.heureVerset,
      anniversaires: _anniversaires,
      monUid: FirebaseAuth.instance.currentUser?.uid,
    );
  }

  @override
  void dispose() {
    for (final a in _abonnements) {
      a.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
