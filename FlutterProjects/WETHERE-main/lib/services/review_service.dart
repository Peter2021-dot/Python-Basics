import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review_model.dart';

class ReviewService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submit a review with verification check
  Future<void> submitReview(ReviewModel review) async {
    if (review.revieweeId.isEmpty) {
      throw Exception('Cannot review user with empty ID');
    }

    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Verify that the journey is completed before allowing review
    final journeyDoc = await _firestore.collection('journeys').doc(review.journeyId).get();
    if (!journeyDoc.exists) {
      throw Exception('Journey not found');
    }

    final journeyData = journeyDoc.data() as Map<String, dynamic>;
    final journeyStatus = journeyData['status'] ?? '';
    final isCompleted = journeyStatus == 'completed' || 
                       (journeyData['endTime'] as Timestamp).toDate().isBefore(DateTime.now());

    // Create verified review
    final verifiedReview = ReviewModel(
      journeyId: review.journeyId,
      reviewerId: review.reviewerId,
      reviewerName: review.reviewerName,
      reviewerAvatar: review.reviewerAvatar,
      revieweeId: review.revieweeId,
      rating: review.rating,
      punctualityRating: review.punctualityRating,
      friendlinessRating: review.friendlinessRating,
      communicationRating: review.communicationRating,
      safetyRating: review.safetyRating,
      comment: review.comment,
      photoUrls: review.photoUrls,
      isVerified: isCompleted,
    );

    // 1. Create Review Reference
    final reviewRef = _firestore.collection('reviews').doc();
    
    // 2. Save Review Document FIRST (ensure data is saved)
    try {
      await reviewRef.set(verifiedReview.toMap());
    } catch (e) {
      print('Error saving review document: $e');
      throw e;
    }

    // 3. Update User's Rating (Reviewee)
    try {
      await _updateUserRating(review.revieweeId, review.rating);
    } catch (e) {
      print('Warning: Failed to update user rating stats: $e');
    }

    // 4. Mark journey as reviewed by this user
    try {
      await _firestore.collection('journeys').doc(review.journeyId).update({
        'reviewedBy.${userId}': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Warning: Failed to mark journey as reviewed: $e');
    }
  }

  /// Update user's overall rating
  Future<void> _updateUserRating(String userId, double newRating) async {
    final userRef = _firestore.collection('users').doc(userId);
    
    await _firestore.runTransaction((transaction) async {
      final userDoc = await transaction.get(userRef);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final double currentRating = (data['rating'] ?? 0.0).toDouble();
        final int currentCount = data['reviewsCount'] ?? 0;
        
        final double updatedRating = ((currentRating * currentCount) + newRating) / (currentCount + 1);
        
        transaction.update(userRef, {
          'rating': updatedRating,
          'reviewsCount': currentCount + 1,
        });
      }
    });
  }

  /// Add host response to a review
  Future<void> addHostResponse(String reviewId, String response) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    // Verify the user is the reviewee (host)
    final reviewDoc = await _firestore.collection('reviews').doc(reviewId).get();
    if (!reviewDoc.exists) {
      throw Exception('Review not found');
    }

    final reviewData = reviewDoc.data() as Map<String, dynamic>;
    if (reviewData['revieweeId'] != userId) {
      throw Exception('Only the reviewed user can respond');
    }

    await _firestore.collection('reviews').doc(reviewId).update({
      'hostResponse': response,
      'hostResponseDate': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Flag a review as inappropriate
  Future<void> flagReview(String reviewId, String reason) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    await _firestore.collection('reviews').doc(reviewId).update({
      'isFlagged': true,
      'flagReason': reason,
      'flaggedBy': userId,
      'flaggedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Also create a report for moderation
    await _firestore.collection('reports').add({
      'type': 'review',
      'reviewId': reviewId,
      'reportedBy': userId,
      'reason': reason,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Toggle helpful vote on a review
  Future<void> toggleHelpfulVote(String reviewId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    final reviewRef = _firestore.collection('reviews').doc(reviewId);
    
    await _firestore.runTransaction((transaction) async {
      final reviewDoc = await transaction.get(reviewRef);
      if (reviewDoc.exists) {
        final data = reviewDoc.data() as Map<String, dynamic>;
        final List<String> voters = data['helpfulVoters'] != null 
            ? List<String>.from(data['helpfulVoters']) 
            : [];
        
        if (voters.contains(userId)) {
          // Remove vote
          voters.remove(userId);
          transaction.update(reviewRef, {
            'helpfulVoters': voters,
            'helpfulCount': FieldValue.increment(-1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Add vote
          voters.add(userId);
          transaction.update(reviewRef, {
            'helpfulVoters': voters,
            'helpfulCount': FieldValue.increment(1),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }

  /// Get reviews for a user with filtering options
  Stream<List<ReviewModel>> getReviewsForUser(
    String userId, {
    bool excludeFlagged = true,
    int? limit,
  }) {
    Query query = _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId);

    if (excludeFlagged) {
      query = query.where('isFlagged', isEqualTo: false);
    }

    query = query.orderBy('createdAt', descending: true);

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => ReviewModel.fromFirestore(doc))
        .toList());
  }

  /// Get review by specific reviewer for a specific journey
  Future<ReviewModel?> getReview(String journeyId, String reviewerId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('journeyId', isEqualTo: journeyId)
        .where('reviewerId', isEqualTo: reviewerId)
        .limit(1)
        .get();
        
    if (snapshot.docs.isNotEmpty) {
      return ReviewModel.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  /// Get all reviews for a journey as a stream
  Stream<List<ReviewModel>> getReviewsForJourneyStream(String journeyId) {
    return _firestore
        .collection('reviews')
        .where('journeyId', isEqualTo: journeyId)
        .where('isFlagged', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReviewModel.fromFirestore(doc))
            .toList());
  }

  /// Get ANY single review for a specific journey (for display/preview)
  Future<ReviewModel?> getReviewForJourney(String journeyId) async {
    try {
      final snapshot = await _firestore
          .collection('reviews')
          .where('journeyId', isEqualTo: journeyId)
          .where('isFlagged', isEqualTo: false)
          .limit(1)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        return ReviewModel.fromFirestore(snapshot.docs.first);
      }
      return null;
    } catch (e) {
      print('Error in getReviewForJourney: $e');
      return null;
    }
  }

  /// Check if user has already reviewed a journey
  Future<bool> hasUserReviewedJourney(String journeyId, String userId) async {
    final snapshot = await _firestore
        .collection('reviews')
        .where('journeyId', isEqualTo: journeyId)
        .where('reviewerId', isEqualTo: userId)
        .limit(1)
        .get();
    
    return snapshot.docs.isNotEmpty;
  }

  /// Get user's review statistics
  Future<Map<String, dynamic>> getUserReviewStats(String userId) async {
    final reviews = await _firestore
        .collection('reviews')
        .where('revieweeId', isEqualTo: userId)
        .where('isFlagged', isEqualTo: false)
        .get();

    if (reviews.docs.isEmpty) {
      return {
        'totalReviews': 0,
        'averageRating': 0.0,
        'punctualityAvg': 0.0,
        'friendlinessAvg': 0.0,
        'communicationAvg': 0.0,
        'safetyAvg': 0.0,
        'verifiedCount': 0,
      };
    }

    double totalRating = 0;
    double totalPunctuality = 0;
    double totalFriendliness = 0;
    double totalCommunication = 0;
    double totalSafety = 0;
    int punctualityCount = 0;
    int friendlinessCount = 0;
    int communicationCount = 0;
    int safetyCount = 0;
    int verifiedCount = 0;

    for (var doc in reviews.docs) {
      final review = ReviewModel.fromFirestore(doc);
      totalRating += review.rating;
      
      if (review.punctualityRating != null) {
        totalPunctuality += review.punctualityRating!;
        punctualityCount++;
      }
      if (review.friendlinessRating != null) {
        totalFriendliness += review.friendlinessRating!;
        friendlinessCount++;
      }
      if (review.communicationRating != null) {
        totalCommunication += review.communicationRating!;
        communicationCount++;
      }
      if (review.safetyRating != null) {
        totalSafety += review.safetyRating!;
        safetyCount++;
      }
      if (review.isVerified) {
        verifiedCount++;
      }
    }

    return {
      'totalReviews': reviews.docs.length,
      'averageRating': totalRating / reviews.docs.length,
      'punctualityAvg': punctualityCount > 0 ? totalPunctuality / punctualityCount : 0.0,
      'friendlinessAvg': friendlinessCount > 0 ? totalFriendliness / friendlinessCount : 0.0,
      'communicationAvg': communicationCount > 0 ? totalCommunication / communicationCount : 0.0,
      'safetyAvg': safetyCount > 0 ? totalSafety / safetyCount : 0.0,
      'verifiedCount': verifiedCount,
    };
  }
}
