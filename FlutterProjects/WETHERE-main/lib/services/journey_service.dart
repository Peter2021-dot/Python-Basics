import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/journey_model.dart';

class JourneyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Create a new journey
  Future<String> createJourney(JourneyModel journey) async {
    try {
      // 1. Fetch host's current rating/reviews
      final userDoc = await _firestore.collection('users').doc(journey.hostUserId).get();
      double rating = 0.0;
      int reviews = 0;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        rating = (data['rating'] ?? 0.0).toDouble();
        reviews = data['reviewsCount'] ?? 0; // consistent with create_profile_page
      }

      // 2. Add to map
      final map = journey.toMap();
      map['hostRating'] = rating;
      map['hostReviewCount'] = reviews;

      final docRef = await _firestore.collection('journeys').add(map);
      print('Journey created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating journey: $e');
      throw Exception('Failed to create journey: $e');
    }
  }

  // Toggle Like (Favorite)
  Future<void> toggleLike(String journeyId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(journeyId);
        
    final doc = await ref.get();
    if (doc.exists) {
      await ref.delete();
    } else {
      await ref.set({
        'likedAt': FieldValue.serverTimestamp(),
        'journeyId': journeyId,
      });
    }
  }

  // Get current user's liked journey IDs
  Stream<Set<String>> getLikedJourneyIdsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value({});

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toSet();
    });
  }

  // Get all open journeys (real-time stream)
  Stream<List<JourneyModel>> getOpenJourneys({
    List<CompensationType>? compensationFilters,
    String? priceRange,
    String? dateFilter,
    String? sortBy = 'recent',
    String? searchQuery,
  }) {
    try {
      // Calculate date ranges first
      DateTime? startDate;
      DateTime? endDate;
      final now = DateTime.now();
      
      if (dateFilter != null && dateFilter != 'any') {
        if (dateFilter == 'today') {
           startDate = DateTime(now.year, now.month, now.day);
           endDate = startDate.add(const Duration(days: 1));
        } else if (dateFilter == 'thisWeek') {
           startDate = DateTime(now.year, now.month, now.day);
           endDate = startDate.add(const Duration(days: 7));
        } else if (dateFilter == 'thisWeekend') {
           final nextSat = now.add(Duration(days: (DateTime.saturday - now.weekday + 7) % 7));
           startDate = DateTime(nextSat.year, nextSat.month, nextSat.day);
           endDate = startDate.add(const Duration(days: 2));
        } else if (dateFilter == 'nextWeek') {
           final nextMon = now.add(Duration(days: (8 - now.weekday) % 7));
           if (now.weekday == DateTime.monday) {
             startDate = now.add(const Duration(days: 7));
           } else {
             startDate = nextMon;
           }
           endDate = startDate.add(const Duration(days: 7));
        }
      }

      // Start with base query
      Query query = _firestore
          .collection('journeys')
          .where('status', isEqualTo: 'open');

      // Strategy: Use minimal DB filtering to avoid index issues
      // Apply compensation filter only if no date/price filters (to avoid complex indexes)
      bool useCompensationInDb = compensationFilters != null && 
                                  compensationFilters.isNotEmpty && 
                                  startDate == null && 
                                  (priceRange == null || priceRange == 'any');

      if (useCompensationInDb) {
        final filterStrings = compensationFilters!
            .map((e) => e.toString().split('.').last)
            .toList();
        query = query.where('compensationType', whereIn: filterStrings);
      }

      // Apply date filter in DB only if no price filter (Firestore limitation)
      bool useDateInDb = startDate != null && (priceRange == null || priceRange == 'any');
      
      if (useDateInDb) {
        query = query.where('startTime', isGreaterThanOrEqualTo: startDate, isLessThan: endDate);
        query = query.orderBy('startTime');
      }

      // Apply price filter in DB only if no date filter
      bool usePriceInDb = (startDate == null) && (priceRange != null && priceRange != 'any');
      
      if (usePriceInDb) {
         if (priceRange == 'under15') {
            query = query.where('giftValue', isLessThan: 15);
            query = query.orderBy('giftValue');
         } else if (priceRange == '15to25') {
            query = query.where('giftValue', isGreaterThanOrEqualTo: 15);
            query = query.where('giftValue', isLessThanOrEqualTo: 25);
            query = query.orderBy('giftValue');
         } else if (priceRange == '25to40') {
            query = query.where('giftValue', isGreaterThanOrEqualTo: 25);
            query = query.where('giftValue', isLessThanOrEqualTo: 40);
            query = query.orderBy('giftValue');
         } else if (priceRange == 'over40') {
            query = query.where('giftValue', isGreaterThan: 40);
            query = query.orderBy('giftValue', descending: true);
         }
      }

      // Apply sorting only if no filters applied orderBy yet
      if (!useDateInDb && !usePriceInDb) {
        switch (sortBy) {
          case 'soonest':
            query = query.orderBy('startTime', descending: false);
            break;
          case 'highestPay':
            query = query.orderBy('giftValue', descending: true);
            break;
          case 'recent':
          default:
            query = query.orderBy('createdAt', descending: true);
            break;
        }
      }

      return query.snapshots().handleError((error) {
        print('Firestore query error (likely missing index): $error');
        // Return empty stream on error
        return Stream<QuerySnapshot>.value(
          _firestore.collection('journeys').limit(0).get() as QuerySnapshot
        );
      }).map((snapshot) {
        final List<JourneyModel> results = [];
        for (var doc in snapshot.docs) {
          try {
             results.add(JourneyModel.fromFirestore(doc));
          } catch (e) {
             print('getOpenJourneys: failed to parse doc ${doc.id}: $e');
          }
        }

        // CLIENT-SIDE FILTERING for filters not applied in DB
        
        // 1. Compensation Type (if not filtered in DB)
        if (!useCompensationInDb && compensationFilters != null && compensationFilters.isNotEmpty) {
          results.retainWhere((j) => compensationFilters.contains(j.compensationType));
        }

        // 2. Date Filter (if not filtered in DB)
        if (!useDateInDb && startDate != null && endDate != null) {
          results.retainWhere((j) {
            return j.startTime.isAfter(startDate!) && j.startTime.isBefore(endDate!);
          });
        }

        // 3. Price Filter (if not filtered in DB)
        if (!usePriceInDb && priceRange != null && priceRange != 'any') {
           results.retainWhere((j) {
              final value = j.giftValue ?? 0;
              switch (priceRange) {
                case 'under15': return value < 15;
                case '15to25': return value >= 15 && value <= 25;
                case '25to40': return value >= 25 && value <= 40;
                case 'over40': return value > 40;
                default: return true;
              }
           });
        }

        // 4. Search Query Filter (always client-side)
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final q = searchQuery.toLowerCase().trim();
          results.retainWhere((j) {
            final title = j.title.toLowerCase();
            final desc = j.description.toLowerCase();
            final loc = j.location.toLowerCase();
            final city = j.city.toLowerCase();
            final host = j.hostName.toLowerCase();
            
            return title.contains(q) || 
                   desc.contains(q) || 
                   loc.contains(q) || 
                   city.contains(q) ||
                   host.contains(q);
          });
        }

        return results;
      });
    } catch (e) {
      print('Error in getOpenJourneys: $e');
      // Return a stream that emits empty list on error
      return Stream.value([]);
    }
  }

  // Get journeys created by current user
  Stream<List<JourneyModel>> getMyCreatedJourneys() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    try {
      // Removed orderBy to avoid requiring complex composite index
      return _firestore
          .collection('journeys')
          .where('hostUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'open')
          .snapshots()
          .map((snapshot) {
        final List<JourneyModel> results = [];
        for (var doc in snapshot.docs) {
          try {
            results.add(JourneyModel.fromFirestore(doc));
          } catch (e) {
            print('getMyCreatedJourneys: failed to parse doc ${doc.id}: $e');
          }
        }
        
        // Client-side Sort
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        // Filter out journeys that have already ended so Active shows only upcoming
        final now = DateTime.now();
        final upcoming = results.where((m) => !m.endTime.isBefore(now)).toList();
        
        try {
          print('getMyCreatedJourneys: docs=${snapshot.docs.length} parsed=${results.length} upcoming=${upcoming.length}');
        } catch (_) {}
        return upcoming;
      });
    } catch (e) {
      print('Error getting my journeys: $e');
      return Stream.value([]);
    }
  }

  // Get past journeys (created by current user and completed)
  Stream<List<JourneyModel>> getMyPastJourneys() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);
    return getPastJourneysForUser(userId);
  }

  // Get past journeys for ANY user
  Stream<List<JourneyModel>> getPastJourneysForUser(String userId) {
    try {
      // Query all journeys created by the user
      return _firestore
          .collection('journeys')
          .where('hostUserId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final all = snapshot.docs.map((doc) => JourneyModel.fromFirestore(doc)).toList();
        
        // Client-side Sort by updatedAt (descending)
        all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        final now = DateTime.now();
        final past = all.where((m) {
          final s = m.status.toLowerCase();
          final ended = m.endTime.isBefore(now);
          // Treat as past if explicitly non-open (e.g. completed/filled/closed)
          // or if the journey's endTime is already in the past.
          return ended || (s != 'open' && s != 'cancelled');
        }).toList();
        return past;
      });
    } catch (e) {
      print('Error getting past journeys for user $userId: $e');
      return Stream.value([]);
    }
  }

  // Get all journeys created by current user (any status)
  Stream<List<JourneyModel>> getMyAllJourneys() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    try {
      // Removed orderBy to avoid index issues.
      return _firestore
          .collection('journeys')
          .where('hostUserId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final List<JourneyModel> results = [];
        for (var doc in snapshot.docs) {
          try {
            results.add(JourneyModel.fromFirestore(doc));
          } catch (e) {
            print('getMyAllJourneys: failed to parse doc ${doc.id}: $e');
          }
        }
        
        // Client-side Sort
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        try {
          print('getMyAllJourneys: user=$userId docs=${snapshot.docs.length} results=${results.length}');
        } catch (_) {}
        return results;
      });
    } catch (e) {
      print('Error getting my all journeys: $e');
      return Stream.value([]);
    }
  }

  // Get a single journey by ID
  Future<JourneyModel?> getJourneyById(String journeyId) async {
    try {
      final doc = await _firestore.collection('journeys').doc(journeyId).get();
      if (doc.exists) {
        return JourneyModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting journey: $e');
      return null;
    }
  }

  // Update journey
  Future<void> updateJourney(String journeyId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = Timestamp.now();
      await _firestore.collection('journeys').doc(journeyId).update(updates);
      print('Journey updated successfully');
    } catch (e) {
      print('Error updating journey: $e');
      throw Exception('Failed to update journey: $e');
    }
  }

  // Delete/Cancel journey
  Future<void> cancelJourney(String journeyId) async {
    try {
      await _firestore.collection('journeys').doc(journeyId).update({
        'status': 'cancelled',
        'updatedAt': Timestamp.now(),
      });
      print('Journey cancelled successfully');
    } catch (e) {
      print('Error cancelling journey: $e');
      throw Exception('Failed to cancel journey: $e');
    }
  }

  // Permanently delete a journey
  Future<void> deleteJourney(String journeyId) async {
    try {
      // 1. Check if ANY applicant is already accepted
      final journeyDoc = await _firestore.collection('journeys').doc(journeyId).get();
      if (journeyDoc.exists) {
        final data = journeyDoc.data() as Map<String, dynamic>;
        if (data['acceptedCompanionId'] != null) {
          throw Exception('Cannot delete journey after accepting an applicant.');
        }
      }

      // 2. Delete the journey document
      await _firestore.collection('journeys').doc(journeyId).delete();
      
      // 3. Also delete any applications for this journey
      final applicationsSnapshot = await _firestore
          .collection('applications')
          .where('journeyId', isEqualTo: journeyId)
          .get();
      
      for (var doc in applicationsSnapshot.docs) {
        await doc.reference.delete();
      }
      
      print('Journey deleted successfully');
    } catch (e) {
      print('Error deleting journey: $e');
      throw Exception('Failed to delete journey: $e');
    }
  }

  // Increment view count
  Future<void> incrementViews(String journeyId) async {
    try {
      await _firestore.collection('journeys').doc(journeyId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing views: $e');
    }
  }

  // Get journeys that a user has applied to
  Stream<List<JourneyModel>> getAppliedJourneys(String userId) {
    try {
      return _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .asyncMap((applicationsSnapshot) async {
            if (applicationsSnapshot.docs.isEmpty) {
              return <JourneyModel>[];
            }

            final journeyIds = applicationsSnapshot.docs
                .map((doc) => doc['journeyId'] as String)
                .toList();

            // Firestore 'whereIn' has a limit of 10 items
            if (journeyIds.isEmpty) {
              return <JourneyModel>[];
            }

            final journeysSnapshot = await _firestore
                .collection('journeys')
                .where(FieldPath.documentId, whereIn: journeyIds)
                .get();

            return journeysSnapshot.docs
                .map((doc) => JourneyModel.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error getting applied journeys: $e');
      return Stream.value([]);
    }
  }

  // Mark journey as complete
  Future<void> markAsComplete(String journeyId) async {
    try {
      await _firestore.collection('journeys').doc(journeyId).update({
        'status': 'completed',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error marking journey as complete: $e');
      throw Exception('Failed to mark journey as complete: $e');
    }
  }

  // Get user stats (rating, reviews, created, participated)
  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      // 1. Get User Doc for Rating/Reviews
      final userDoc = await _firestore.collection('users').doc(userId).get();
      double rating = 0.0;
      int reviews = 0;
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        rating = (data['rating'] ?? 0.0).toDouble();
        reviews = data['reviewsCount'] ?? 0;
      }

      // 2. Count Created Journeys (using count() aggregation)
      final createdSnap = await _firestore
          .collection('journeys')
          .where('hostUserId', isEqualTo: userId)
          .count()
          .get();
      final createdCount = createdSnap.count ?? 0;

      // 3. Count Participated (Accepted Applications)
      final participatedSnap = await _firestore
          .collection('applications')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .count()
          .get();
      final participatedCount = participatedSnap.count ?? 0;

      return {
        'rating': rating,
        'reviews': reviews,
        'created': createdCount,
        'participated': participatedCount,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'rating': 0.0,
        'reviews': 0,
        'created': 0,
        'participated': 0,
      };
    }
  }

  /// Mark a journey as completed (for host)
  Future<void> markJourneyAsCompleted(String journeyId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // Get journey to verify ownership
      final journeyDoc = await _firestore.collection('journeys').doc(journeyId).get();
      if (!journeyDoc.exists) throw Exception('Journey not found');

      final journeyData = journeyDoc.data() as Map<String, dynamic>;
      if (journeyData['hostUserId'] != userId) {
        throw Exception('Only the host can mark journey as completed');
      }

      // Update journey status
      await _firestore.collection('journeys').doc(journeyId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('Journey $journeyId marked as completed');
    } catch (e) {
      print('Error marking journey as completed: $e');
      throw Exception('Failed to mark journey as completed: $e');
    }
  }

  /// Auto-expire journeys that have passed their end time
  Future<void> autoExpireJourneys() async {
    try {
      final now = DateTime.now();
      
      // Query open journeys that have ended
      final expiredJourneys = await _firestore
          .collection('journeys')
          .where('status', isEqualTo: 'open')
          .where('endTime', isLessThan: now)
          .get();

      // Batch update to completed
      final batch = _firestore.batch();
      for (var doc in expiredJourneys.docs) {
        batch.update(doc.reference, {
          'status': 'completed',
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      print('Auto-expired ${expiredJourneys.docs.length} journeys');
    } catch (e) {
      print('Error auto-expiring journeys: $e');
    }
  }

  /// Report a journey for inappropriate content
  Future<void> reportJourney({
    required String journeyId,
    required String reason,
    String? details,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection('reports').add({
        'type': 'journey',
        'journeyId': journeyId,
        'reportedBy': userId,
        'reason': reason,
        'details': details ?? '',
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('Journey $journeyId reported successfully');
    } catch (e) {
      print('Error reporting journey: $e');
      throw Exception('Failed to report journey: $e');
    }
  }

  /// Report a user for inappropriate behavior
  Future<void> reportUser({
    required String reportedUserId,
    required String reason,
    String? details,
    String? journeyId,
  }) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      await _firestore.collection('reports').add({
        'type': 'user',
        'reportedUserId': reportedUserId,
        'reportedBy': userId,
        'reason': reason,
        'details': details ?? '',
        'journeyId': journeyId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print('User $reportedUserId reported successfully');
    } catch (e) {
      print('Error reporting user: $e');
      throw Exception('Failed to report user: $e');
    }
  }
}
