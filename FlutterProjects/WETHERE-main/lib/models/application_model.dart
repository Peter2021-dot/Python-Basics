import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationModel {
  final String id;
  final String journeyId;
  final String hostUserId;
  final String applicantUserId;
  final String status; // applied, accepted, rejected, cancelled
  final DateTime appliedAt;

  ApplicationModel({
    required this.id,
    required this.journeyId,
    required this.hostUserId,
    required this.applicantUserId,
    required this.status,
    required this.appliedAt,
  });

  factory ApplicationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ApplicationModel(
      id: doc.id,
      journeyId: data['journeyId'],
      hostUserId: data['hostUserId'],
      applicantUserId: data['applicantUserId'],
      status: data['status'],
      appliedAt: (data['appliedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'journeyId': journeyId,
      'hostUserId': hostUserId,
      'applicantUserId': applicantUserId,
      'status': status,
      'appliedAt': Timestamp.now(),
    };
  }
}
