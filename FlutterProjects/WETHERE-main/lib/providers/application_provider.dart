import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journey_model.dart';

class ApplicationProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> applyToJourney({
    required JourneyModel journey,
    required String userId,
    required String userName,
    String? rewardChoice, // 'hourly' | 'freeItem'
  }) async {
    final applicationRef = _firestore.collection('applications').doc();
    final journeyRef =
        _firestore.collection('journeys').doc(journey.id);

    await _firestore.runTransaction((transaction) async {
      // Prevent overbooking
      if (journey.currentApplicants >= journey.maxCompanions) {
        throw Exception('Journey is already full');
      }

      // Save application
      transaction.set(applicationRef, {
        'journeyId': journey.id,
        'journeyTitle': journey.title,
        'userId': userId,
        'userName': userName,
        'hostUserId': journey.hostUserId,
        'rewardChoice': rewardChoice,
        'status': 'applied',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update journey
      transaction.update(journeyRef, {
        'currentApplicants': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<QuerySnapshot> getApplicationsForJourney(String journeyId) {
    return _firestore
        .collection('applications')
        .where('journeyId', isEqualTo: journeyId)
        .snapshots();
  }

  // Accept an application
  Future<void> acceptApplication(String applicationId, String journeyId, String applicantId) async {
    final applicationRef = _firestore.collection('applications').doc(applicationId);
    final journeyRef = _firestore.collection('journeys').doc(journeyId);

    await _firestore.runTransaction((transaction) async {
      // 1. Update Application status
      transaction.update(applicationRef, {
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 2. Update Journey accepted companion
      transaction.update(journeyRef, {
        'acceptedCompanionId': applicantId,
        'status': 'filled', // Optional: close journey if max capacity reached
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    notifyListeners();
  }

  // Reject an application
  Future<void> rejectApplication(String applicationId) async {
    await _firestore.collection('applications').doc(applicationId).update({
      'status': 'rejected',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  Stream<QuerySnapshot> getUserApplications(String userId) {
    return _firestore
        .collection('applications')
        .where('userId', isEqualTo: userId)
        .snapshots();
  }
}
