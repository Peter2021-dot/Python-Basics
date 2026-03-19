// =============================================================================
// FILE: test/helpers/mock_data.dart
// Reusable mock data for tests
// =============================================================================

import 'dart:convert';

/// Mock profile data for different states
class MockProfileData {
  /// A fully complete profile (all 3 steps filled)
  static Map<String, dynamic> get complete => {
    'bio': 'I love traveling and meeting new people! Always up for adventure.',
    'occupation': 'Professional',
    'customOccupation': '',
    'languages': ['English', 'Spanish'],
    'interests': ['Sports', 'Music', 'Travel', 'Food & Dining'],
    'journeyTypes': ['Shopping trips', 'Concerts/Events', 'Dining out', 'Outdoor adventures'],
    'ethnicity': 'Prefer not to say',
    'availability': ['Weekday evenings', 'Weekend mornings', 'Weekend afternoons'],
    'communicationStyle': 'Moderate',
    'transportation': ['Car owner', 'Rideshare'],
    'currentStep': 2,
  };

  /// Profile with only step 1 completed
  static Map<String, dynamic> get step1Only => {
    'bio': 'I love traveling and meeting new people! Always up for adventure.',
    'occupation': 'Student',
    'customOccupation': '',
    'languages': ['English'],
    'interests': <String>[],
    'journeyTypes': <String>[],
    'ethnicity': null,
    'availability': <String>[],
    'communicationStyle': null,
    'transportation': <String>[],
    'currentStep': 1,
  };

  /// Profile with step 1 and 2 completed
  static Map<String, dynamic> get step1And2 => {
    'bio': 'I love traveling and meeting new people! Always up for adventure.',
    'occupation': 'Professional',
    'customOccupation': '',
    'languages': ['English', 'French'],
    'interests': ['Sports', 'Music', 'Travel'],
    'journeyTypes': ['Shopping trips', 'Concerts/Events', 'Fitness activities'],
    'ethnicity': null,
    'availability': <String>[],
    'communicationStyle': null,
    'transportation': <String>[],
    'currentStep': 2,
  };

  /// Completely empty profile
  static Map<String, dynamic> get empty => {
    'bio': '',
    'occupation': null,
    'customOccupation': '',
    'languages': <String>[],
    'interests': <String>[],
    'journeyTypes': <String>[],
    'ethnicity': null,
    'availability': <String>[],
    'communicationStyle': null,
    'transportation': <String>[],
    'currentStep': 0,
  };

  /// Profile with "Other" occupation filled in
  static Map<String, dynamic> get withCustomOccupation => {
    ...complete,
    'occupation': 'Other',
    'customOccupation': 'AI Engineer',
  };

  /// Encode profile data to JSON string (as stored in SharedPreferences)
  static String encode(Map<String, dynamic> data) => jsonEncode(data);
}

/// Mock user data
class MockUserData {
  static const String testUserId = 'test-user-123';
  static const String testEmail = 'test@example.com';
  static const String testFirstName = 'Test';
  static const String testLastName = 'User';
  static const String testPhone = '+1234567890';
}

/// Occupation options (mirrors CreateProfilePage)
class ProfileOptions {
  static const List<String> occupations = [
    'Student', 'Professional', 'Freelancer', 'Entrepreneur',
    'Retired', 'Homemaker', 'Other',
  ];

  static const List<String> languages = [
    'English', 'Spanish', 'French', 'Mandarin', 'Hindi', 'Arabic',
    'Portuguese', 'Japanese', 'Korean', 'German', 'Italian', 'Russian', 'Other',
  ];

  static const List<String> interests = [
    'Sports', 'Music', 'Arts', 'Food & Dining', 'Outdoor Activities',
    'Gaming', 'Reading', 'Travel', 'Fitness', 'Shopping', 'Photography',
    'Cooking', 'Movies', 'Dancing', 'Yoga', 'Hiking', 'Swimming',
    'Cycling', 'Volunteering', 'Technology', 'Fashion', 'Pets',
    'Gardening', 'Board Games',
  ];

  static const List<String> journeyTypes = [
    'Shopping trips', 'Concerts/Events', 'Fitness activities', 'Dining out',
    'Coffee/casual hangouts', 'Outdoor adventures', 'Cultural activities',
    'Movie nights', 'Sports games', 'Museum visits', 'Grocery runs',
    'Dog walking', 'Brunch', 'Nightlife', 'Road trips', 'Study sessions',
    'Walking/Jogging', 'Art galleries',
  ];

  static const List<String> ethnicities = [
    'Asian', 'Black/African American', 'Hispanic/Latino', 'Middle Eastern',
    'Native American', 'Pacific Islander', 'White/Caucasian',
    'Mixed/Multiracial', 'Prefer not to say',
  ];

  static const List<String> availability = [
    'Weekday mornings', 'Weekday afternoons', 'Weekday evenings',
    'Weekend mornings', 'Weekend afternoons', 'Weekend evenings', 'Flexible',
  ];

  static const List<String> communicationStyles = [
    'Chatty/Social', 'Moderate', 'Quiet/Reserved', 'Go with the flow',
  ];

  static const List<String> transportation = [
    'Car owner', 'Public transit', 'Bike', 'Walk', 'Rideshare',
  ];
}
