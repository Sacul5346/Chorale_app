import 'package:cloud_firestore/cloud_firestore.dart';

class Presence {
  final String id;
  final String userId;
  final String repetitionId;
  final String statut; // present | absent | retard
  final String? valideePar;
  final DateTime? confirmedAt;

  Presence({
    required this.id,
    required this.userId,
    required this.repetitionId,
    required this.statut,
    this.valideePar,
    this.confirmedAt,
  });

  factory Presence.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Presence(
      id: doc.id,
      userId: data['userId'] ?? '',
      repetitionId: data['repetitionId'] ?? '',
      statut: data['statut'] ?? '',
      valideePar: data['valideePar'],
      confirmedAt: data['confirmedAt'] != null
          ? (data['confirmedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'repetitionId': repetitionId,
      'statut': statut,
      'valideePar': valideePar,
      'confirmedAt': FieldValue.serverTimestamp(),
    };
  }
}