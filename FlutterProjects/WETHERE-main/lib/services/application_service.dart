import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ApplicationService {
  final _db = FirebaseFirestore.instance;
  final _notificationService = NotificationService();

  Future<void> applyToJourney({
    required String journeyId,
    required String hostUserId,
    required String applicantUserId,
    String? selectedReward,
  }) async {
    await _db.collection('applications').add({
      'journeyId': journeyId,
      'hostUserId': hostUserId,
      'applicantUserId': applicantUserId,
      'status': 'applied',
      'selectedReward': selectedReward,
      'appliedAt': FieldValue.serverTimestamp(),
    });

    // Increment counter on journey
    await _db.collection('journeys').doc(journeyId).update({
      'currentApplicants': FieldValue.increment(1),
    });

    // Get journey and applicant info for notification
    final journeyDoc = await _db.collection('journeys').doc(journeyId).get();
    final applicantDoc = await _db.collection('users').doc(applicantUserId).get();
    
    final journeyTitle = journeyDoc.data()?['title'] ?? 'a journey';
    final applicantName = applicantDoc.data()?['displayName'] ?? 
                          applicantDoc.data()?['fullName'] ?? 'Someone';

    // Send notification to host
    await _notificationService.sendNotificationToUser(
      userId: hostUserId,
      title: 'New Application',
      body: '$applicantName applied to your journey: $journeyTitle',
      data: {
        'type': 'new_application',
        'journeyId': journeyId,
        'applicantUserId': applicantUserId,
      },
    );
  }

  /// Accept an application
  Future<void> acceptApplication({
    required String applicationId,
    required String journeyId,
  }) async {
    // Get application data
    final appDoc = await _db.collection('applications').doc(applicationId).get();
    final applicantUserId = appDoc.data()?['applicantUserId'] as String?;
    
    if (applicantUserId == null) return;

    // Update application status
    await _db.collection('applications').doc(applicationId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    // Update journey with accepted companion
    await _db.collection('journeys').doc(journeyId).update({
      'acceptedCompanionId': applicantUserId,
      'status': 'filled',
    });

    // Get journey info for notification
    final journeyDoc = await _db.collection('journeys').doc(journeyId).get();
    final journeyTitle = journeyDoc.data()?['title'] ?? 'a journey';

    // Send notification to applicant
    await _notificationService.sendNotificationToUser(
      userId: applicantUserId,
      title: 'Application Accepted! 🎉',
      body: 'Your application for "$journeyTitle" has been accepted!',
      data: {
        'type': 'application_accepted',
        'journeyId': journeyId,
      },
    );
  }

  /// Reject an application
  Future<void> rejectApplication(String applicationId, String applicantUserId) async {
    await _db.collection('applications').doc(applicationId).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    // Optionally send notification
    await _notificationService.sendNotificationToUser(
      userId: applicantUserId,
      title: 'Application Update',
      body: 'Unfortunately, your application was not selected this time.',
      data: {
        'type': 'application_rejected',
      },
    );
  }
}
