import 'package:cloud_firestore/cloud_firestore.dart';

class Repetition {
  final String id;
  final String titre;
  final DateTime date;
  final String heure;
  final String lieu;
  final String chefId;
  final String statut;
  final String chansons;
  final String raison;
  final String causeAnnulation;

  Repetition({
    required this.id,
    required this.titre,
    required this.date,
    required this.heure,
    required this.lieu,
    required this.chefId,
    required this.statut,
    this.chansons = '',
    this.raison = '',
    this.causeAnnulation = '',
  });

  factory Repetition.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Repetition(
      id: doc.id,
      titre: data['titre'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      heure: data['heure'] ?? '',
      lieu: data['lieu'] ?? '',
      chefId: data['chefId'] ?? '',
      statut: data['statut'] ?? 'actif',
      chansons: data['chansons'] ?? '',
      raison: data['raison'] ?? '',
      causeAnnulation: data['causeAnnulation'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titre': titre,
      'date': Timestamp.fromDate(date),
      'heure': heure,
      'lieu': lieu,
      'chefId': chefId,
      'statut': statut,
      'chansons': chansons,
      'raison': raison,
      'causeAnnulation': causeAnnulation,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}