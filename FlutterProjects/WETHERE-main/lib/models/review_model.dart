import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String? id;
  final String journeyId;
  final String reviewerId;
  final String reviewerName; // Snapshot for display
  final String? reviewerAvatar;
  final String revieweeId; // The user being reviewed (Host or Companion)
  
  // Overall rating (average of category ratings)
  final double rating;
  
  // Category ratings (new!)
  final double? punctualityRating;
  final double? friendlinessRating;
  final double? communicationRating;
  final double? safetyRating;
  
  final String comment;
  final List<String> photoUrls; // Photo URLs (new!)
  
  // Host response (new!)
  final String? hostResponse;
  final DateTime? hostResponseDate;
  
  // Verification & moderation (new!)
  final bool isVerified; // True if journey was completed
  final bool isFlagged; // True if reported
  final String? flagReason;
  
  // Helpful votes (new!)
  final int helpfulCount;
  final List<String> helpfulVoters; // User IDs who found this helpful
  
  final DateTime createdAt;
  final DateTime updatedAt;

  ReviewModel({
    this.id,
    required this.journeyId,
    required this.reviewerId,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.revieweeId,
    required this.rating,
    this.punctualityRating,
    this.friendlinessRating,
    this.communicationRating,
    this.safetyRating,
    required this.comment,
    this.photoUrls = const [],
    this.hostResponse,
    this.hostResponseDate,
    this.isVerified = false,
    this.isFlagged = false,
    this.flagReason,
    this.helpfulCount = 0,
    this.helpfulVoters = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'journeyId': journeyId,
      'reviewerId': reviewerId,
      'reviewerName': reviewerName,
      'reviewerAvatar': reviewerAvatar,
      'revieweeId': revieweeId,
      'rating': rating,
      'punctualityRating': punctualityRating,
      'friendlinessRating': friendlinessRating,
      'communicationRating': communicationRating,
      'safetyRating': safetyRating,
      'comment': comment,
      'photoUrls': photoUrls,
      'hostResponse': hostResponse,
      'hostResponseDate': hostResponseDate != null 
          ? Timestamp.fromDate(hostResponseDate!) 
          : null,
      'isVerified': isVerified,
      'isFlagged': isFlagged,
      'flagReason': flagReason,
      'helpfulCount': helpfulCount,
      'helpfulVoters': helpfulVoters,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      journeyId: data['journeyId'] ?? '',
      reviewerId: data['reviewerId'] ?? '',
      reviewerName: data['reviewerName'] ?? 'Anonymous',
      reviewerAvatar: data['reviewerAvatar'],
      revieweeId: data['revieweeId'] ?? '',
      rating: (data['rating'] ?? 0.0).toDouble(),
      punctualityRating: data['punctualityRating'] != null 
          ? (data['punctualityRating'] as num).toDouble() 
          : null,
      friendlinessRating: data['friendlinessRating'] != null 
          ? (data['friendlinessRating'] as num).toDouble() 
          : null,
      communicationRating: data['communicationRating'] != null 
          ? (data['communicationRating'] as num).toDouble() 
          : null,
      safetyRating: data['safetyRating'] != null 
          ? (data['safetyRating'] as num).toDouble() 
          : null,
      comment: data['comment'] ?? '',
      photoUrls: data['photoUrls'] != null 
          ? List<String>.from(data['photoUrls']) 
          : [],
      hostResponse: data['hostResponse'],
      hostResponseDate: data['hostResponseDate'] != null 
          ? (data['hostResponseDate'] as Timestamp).toDate() 
          : null,
      isVerified: data['isVerified'] ?? false,
      isFlagged: data['isFlagged'] ?? false,
      flagReason: data['flagReason'],
      helpfulCount: data['helpfulCount'] ?? 0,
      helpfulVoters: data['helpfulVoters'] != null 
          ? List<String>.from(data['helpfulVoters']) 
          : [],
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  // Helper to calculate average category rating
  double get averageCategoryRating {
    final ratings = [
      punctualityRating,
      friendlinessRating,
      communicationRating,
      safetyRating,
    ].where((r) => r != null).map((r) => r!).toList();
    
    if (ratings.isEmpty) return rating;
    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  // Copy with method for updates
  ReviewModel copyWith({
    String? hostResponse,
    DateTime? hostResponseDate,
    bool? isFlagged,
    String? flagReason,
    int? helpfulCount,
    List<String>? helpfulVoters,
  }) {
    return ReviewModel(
      id: id,
      journeyId: journeyId,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      reviewerAvatar: reviewerAvatar,
      revieweeId: revieweeId,
      rating: rating,
      punctualityRating: punctualityRating,
      friendlinessRating: friendlinessRating,
      communicationRating: communicationRating,
      safetyRating: safetyRating,
      comment: comment,
      photoUrls: photoUrls,
      hostResponse: hostResponse ?? this.hostResponse,
      hostResponseDate: hostResponseDate ?? this.hostResponseDate,
      isVerified: isVerified,
      isFlagged: isFlagged ?? this.isFlagged,
      flagReason: flagReason ?? this.flagReason,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      helpfulVoters: helpfulVoters ?? this.helpfulVoters,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
