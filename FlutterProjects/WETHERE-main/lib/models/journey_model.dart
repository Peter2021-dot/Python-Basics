// ============================================================================
// FILE: lib/models/journey_model.dart
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum CompensationType {
  withoutRemuneration,
  withGift,
}

class JourneyModel {
  final String? id;
  final String hostUserId;
  final String hostName;
  final String? hostAvatar;
  
  // Basic Info
  final String title;
  final String description;
  final String imageUrl;
  
  // Location
  final String location;
  final String meetingPoint;
  final GeoPoint? locationCoordinates;
  
  // Timing
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final int duration; // in hours
  
  // Compensation - Simplified system
  final CompensationType compensationType;
  final String? giftDescription; // For "with gift" - can be money amount or item description
  final String? giftEmoji;
  final double? giftValue; // Estimated monetary value of the gift
  
  // Status
  final String status; // open, filled, completed, cancelled
  final int maxCompanions;
  final int currentApplicants;
  final String? acceptedCompanionId;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final int views;
  
  // Searchability
  final List<String> tags;
  final String city;
  final String? zipCode;
  final String? state;
  final double hostRating;
  final int hostReviewCount;

  JourneyModel({
    this.id,
    required this.hostUserId,
    required this.hostName,
    this.hostAvatar,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.location,
    required this.meetingPoint,
    this.locationCoordinates,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.duration,
    required this.compensationType,
    this.giftDescription,
    this.giftEmoji,
    this.giftValue,
    this.status = 'open',
    this.maxCompanions = 1,
    this.currentApplicants = 0,
    this.acceptedCompanionId,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.views = 0,
    this.tags = const [],
    required this.city,
    this.zipCode,
    this.state,
    this.hostRating = 0.0,
    this.hostReviewCount = 0,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'hostUserId': hostUserId,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'location': location,
      'meetingPoint': meetingPoint,
      'locationCoordinates': locationCoordinates,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'duration': duration,
      'compensationType': compensationType.toString().split('.').last,
      'giftDescription': giftDescription,
      'giftEmoji': giftEmoji,
      'giftValue': giftValue,
      'status': status,
      'maxCompanions': maxCompanions,
      'currentApplicants': currentApplicants,
      'acceptedCompanionId': acceptedCompanionId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'views': views,
      'tags': tags,
      'city': city,
      'zipCode': zipCode,
      'state': state,
      'hostRating': hostRating,
      'hostReviewCount': hostReviewCount,
    };
  }

  // Create from Firestore document
  factory JourneyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return JourneyModel(
      id: doc.id,
      hostUserId: data['hostUserId'] ?? '',
      hostName: data['hostName'] ?? '',
      hostAvatar: data['hostAvatar'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      location: data['location'] ?? '',
      meetingPoint: data['meetingPoint'] ?? '',
      locationCoordinates: data['locationCoordinates'] is GeoPoint ? data['locationCoordinates'] as GeoPoint : null,
      date: data['date'] != null && data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      startTime: data['startTime'] != null && data['startTime'] is Timestamp ? (data['startTime'] as Timestamp).toDate() : DateTime.now(),
      endTime: data['endTime'] != null && data['endTime'] is Timestamp ? (data['endTime'] as Timestamp).toDate() : DateTime.now(),
      duration: data['duration'] ?? 0,
      compensationType: _parseCompensationType(data['compensationType']),
      giftDescription: data['giftDescription'],
      giftEmoji: data['giftEmoji'],
      giftValue: data['giftValue']?.toDouble(),
      status: data['status'] ?? 'open',
      maxCompanions: data['maxCompanions'] ?? 1,
      currentApplicants: data['currentApplicants'] ?? 0,
      acceptedCompanionId: data['acceptedCompanionId'],
      createdAt: data['createdAt'] != null && data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      updatedAt: data['updatedAt'] != null && data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : DateTime.now(),
      views: data['views'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      city: data['city'] ?? '',
      zipCode: data['zipCode'],
      state: data['state'],
      hostRating: (data['hostRating'] ?? 0.0).toDouble(),
      hostReviewCount: data['hostReviewCount'] ?? 0,
    );
  }

  static CompensationType _parseCompensationType(String? type) {
    switch (type) {
      case 'withoutRemuneration':
        return CompensationType.withoutRemuneration;
      case 'withGift':
        return CompensationType.withGift;
      default:
        return CompensationType.withoutRemuneration;
    }
  }

  // Get badge text for UI
  String get badgeText {
    switch (compensationType) {
      case CompensationType.withoutRemuneration:
        return 'No Remuneration';
      case CompensationType.withGift:
        return '${giftEmoji ?? '�'} ${giftDescription ?? 'Gift'}';
    }
  }

  // Get badge color for UI
  String get badgeColorHex {
    switch (compensationType) {
      case CompensationType.withoutRemuneration:
        return '#9E9E9E';
      case CompensationType.withGift:
        return '#FF6B35';
    }
  }

  // Convert to UI-friendly map for HomePage
  Map<String, dynamic> toUiMap() {
    return {
      'id': id,
      'hostName': hostName,
      'hostAvatar': hostAvatar,
      'views': views,
      'imageUrl': imageUrl,
      'title': title,
      'location': location,
      'meetingPoint': meetingPoint,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'compensationType': compensationType.toString().split('.').last,
      'giftDescription': giftDescription,
      'giftEmoji': giftEmoji,
      'giftValue': giftValue,
    };
  }
}