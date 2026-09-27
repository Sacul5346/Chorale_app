import 'package:cloud_firestore/cloud_firestore.dart';

/// Réglages de la chorale, modifiables dans l'app par le chef et le
/// responsable (écran « Paramètres de la chorale ») : on ne touche plus au
/// code quand l'organisation change. Stockés dans `parametres/chorale`.
/// Sans document enregistré, les valeurs par défaut ci-dessous s'appliquent.

const joursSemaine = {
  DateTime.monday: 'Lundi',
  DateTime.tuesday: 'Mardi',
  DateTime.wednesday: 'Mercredi',
  DateTime.thursday: 'Jeudi',
  DateTime.friday: 'Vendredi',
  DateTime.saturday: 'Samedi',
  DateTime.sunday: 'Dimanche',
};

/// Un créneau de répétition hebdomadaire.
class Creneau {
  final int jour; // DateTime.monday (1) … DateTime.sunday (7)
  final String heure; // texte libre, ex. « 18h00 »
  final String lieu;

  /// Proposé décoché lors de la génération (répétition à confirmer).
  final bool aConfirmer;

  const Creneau({
    required this.jour,
    required this.heure,
    required this.lieu,
    this.aConfirmer = false,
  });

  String get nomJour => joursSemaine[jour] ?? '?';

  Map<String, dynamic> versMap() => {
    'jour': jour,
    'heure': heure,
    'lieu': lieu,
    'aConfirmer': aConfirmer,
  };

  static Creneau? depuisMap(Object? m) {
    if (m is! Map) return null;
    final jour = m['jour'];
    if (jour is! int || !joursSemaine.containsKey(jour)) return null;
    return Creneau(
      jour: jour,
      heure: m['heure'] is String ? m['heure'] as String : '',
      lieu: m['lieu'] is String ? m['lieu'] as String : '',
      aConfirmer: m['aConfirmer'] == true,
    );
  }
}

/// Points d'activité par présence constatée (classement du mois).
const baremeParDefaut = {
  'present_heure': 3,
  'present_retard_excuse': 2,
  'present_retard_sans_excuse': 1,
  'absent_excuse': 0,
  'absent_sans_excuse': -1,
  // Bonus : le membre a donné sa réponse dans l'app avant la répétition.
  'reponse_a_lavance': 1,
};

const libellesBareme = {
  'present_heure': 'Présent à l’heure',
  'present_retard_excuse': 'En retard avec excuse',
  'present_retard_sans_excuse': 'En retard sans excuse',
  'absent_excuse': 'Absent avec excuse',
  'absent_sans_excuse': 'Absent sans excuse',
  'reponse_a_lavance': 'Bonus : a répondu à l’avance',
};

class ParametresChorale {
  final List<Creneau> creneaux;
  final List<String> regions;

  /// Heure du rappel envoyé la veille de chaque répétition (0-23).
  final int heureRappel;
  final Map<String, int> bareme;

  /// Notification quotidienne du verset du jour, et son heure (0-23).
  final bool versetActif;
  final int heureVerset;

  const ParametresChorale({
    required this.creneaux,
    required this.regions,
    required this.heureRappel,
    required this.bareme,
    this.versetActif = true,
    this.heureVerset = 6,
  });

  /// Fonctionnement de l'app avant les paramètres.
  static const defaut = ParametresChorale(
    creneaux: [
      Creneau(
        jour: DateTime.thursday,
        heure: '18h00',
        lieu: 'Salle de répétition',
      ),
      Creneau(
        jour: DateTime.saturday,
        heure: '14h00',
        lieu: 'Salle de répétition',
      ),
      Creneau(
        jour: DateTime.sunday,
        heure: '14h00',
        lieu: 'Salle de répétition',
        aConfirmer: true,
      ),
    ],
    regions: ['Sud', 'Merina', 'Sud-Est'],
    heureRappel: 18,
    bareme: baremeParDefaut,
  );

  factory ParametresChorale.depuisMap(Map<String, dynamic>? m) {
    if (m == null) return defaut;
    final creneaux = m['creneaux'] is List
        ? (m['creneaux'] as List)
              .map(Creneau.depuisMap)
              .whereType<Creneau>()
              .toList()
        : [...defaut.creneaux]; // copie : la liste par défaut est constante
    creneaux.sort((a, b) => a.jour.compareTo(b.jour));
    final regions = m['regions'] is List
        ? (m['regions'] as List)
              .whereType<String>()
              .map((r) => r.trim())
              .where((r) => r.isNotEmpty)
              .toList()
        : defaut.regions;
    final heure = m['heureRappel'];
    final heureVerset = m['heureVerset'];
    final bareme = {...baremeParDefaut};
    if (m['bareme'] is Map) {
      (m['bareme'] as Map).forEach((k, v) {
        if (k is String && bareme.containsKey(k) && v is num) {
          bareme[k] = v.toInt();
        }
      });
    }
    return ParametresChorale(
      creneaux: creneaux,
      regions: regions.isEmpty ? defaut.regions : regions,
      heureRappel: heure is int && heure >= 0 && heure <= 23 ? heure : 18,
      bareme: bareme,
      versetActif: m['versetActif'] != false,
      heureVerset: heureVerset is int && heureVerset >= 0 && heureVerset <= 23
          ? heureVerset
          : 6,
    );
  }

  Map<String, dynamic> versMap() => {
    'creneaux': creneaux.map((c) => c.versMap()).toList(),
    'regions': regions,
    'heureRappel': heureRappel,
    'bareme': bareme,
    'versetActif': versetActif,
    'heureVerset': heureVerset,
  };

  ParametresChorale copie({
    List<Creneau>? creneaux,
    List<String>? regions,
    int? heureRappel,
    Map<String, int>? bareme,
    bool? versetActif,
    int? heureVerset,
  }) => ParametresChorale(
    creneaux: creneaux ?? this.creneaux,
    regions: regions ?? this.regions,
    heureRappel: heureRappel ?? this.heureRappel,
    bareme: bareme ?? this.bareme,
    versetActif: versetActif ?? this.versetActif,
    heureVerset: heureVerset ?? this.heureVerset,
  );

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('parametres').doc('chorale');

  static Future<ParametresChorale> charger() async {
    try {
      return ParametresChorale.depuisMap((await _doc.get()).data());
    } catch (_) {
      return defaut; // hors ligne, ou règles pas encore publiées
    }
  }

  static Stream<ParametresChorale> ecouter() => _doc
      .snapshots()
      .map((s) => ParametresChorale.depuisMap(s.data()))
      .handleError((_) {});

  Future<void> enregistrer() => _doc.set(versMap());
}
