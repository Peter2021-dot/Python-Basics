import 'package:flutter/foundation.dart';
import '../models/journey_model.dart';
import '../services/journey_service.dart';

class JourneyProvider with ChangeNotifier {
  final JourneyService _journeyService = JourneyService();
  
  List<JourneyModel> _journeys = [];
  bool _isLoading = false;
  String? _error;

  List<JourneyModel> get journeys => _journeys;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Create journey
  Future<String?> createJourney(JourneyModel journey) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final journeyId = await _journeyService.createJourney(journey);
      
      _isLoading = false;
      notifyListeners();
      
      return journeyId;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Listen to journeys stream
  Stream<List<JourneyModel>> getJourneysStream({
    List<CompensationType>? compensationFilters,
    String? priceRange,
    String? dateFilter,
    String? sortBy,
    String? searchQuery,
  }) {
    return _journeyService.getOpenJourneys(
      compensationFilters: compensationFilters,
      priceRange: priceRange,
      dateFilter: dateFilter,
      sortBy: sortBy,
      searchQuery: searchQuery,
    );
  }

  // Listen to my created journeys
  Stream<List<JourneyModel>> getMyJourneysStream() {
    return _journeyService.getMyCreatedJourneys();
  }

  // Listen to my past (completed) journeys
  Stream<List<JourneyModel>> getMyPastJourneysStream() {
    return _journeyService.getMyPastJourneys();
  }

  // Listen to all journeys created by current user (any status)
  Stream<List<JourneyModel>> getMyAllJourneysStream() {
    return _journeyService.getMyAllJourneys();
  }

  Stream<List<JourneyModel>> getAppliedJourneysStream(String userId) {
    return _journeyService.getAppliedJourneys(userId);
  }

  // Toggle Like
  Future<void> toggleLike(String journeyId) {
    return _journeyService.toggleLike(journeyId);
  }

  // Listen to liked journey IDs
  Stream<Set<String>> getLikedJourneyIdsStream() {
    return _journeyService.getLikedJourneyIdsStream();
  }

  // Mark journey as complete
  Future<void> markAsComplete(String journeyId) async {
    return _journeyService.markAsComplete(journeyId);
  }

  // Update journey
  Future<void> updateJourney(String journeyId, Map<String, dynamic> updates) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _journeyService.updateJourney(journeyId, updates);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}