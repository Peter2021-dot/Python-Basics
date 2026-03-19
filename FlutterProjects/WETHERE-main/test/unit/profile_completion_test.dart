import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Unit tests for profile completion logic
// Note: These tests focus on the SharedPreferences-based profile storage
// and don't require Firebase mocking

void main() {
  group('Profile Completion Tests', () {
    late SharedPreferences prefs;

    setUp(() async {
      // Initialize SharedPreferences with mock values
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await prefs.clear();
    });

    test('Profile is incomplete when no data exists', () async {
      final isComplete = prefs.getBool('profile_complete') ?? false;
      expect(isComplete, false);
    });

    test('Profile is complete when flag is set', () async {
      await prefs.setBool('profile_complete', true);
      final isComplete = prefs.getBool('profile_complete') ?? false;
      expect(isComplete, true);
    });

    test('Profile progress is saved correctly', () async {
      final profileData = {
        'bio': 'This is my bio text that is long enough to pass validation',
        'occupation': 'Professional',
        'customOccupation': '',
        'languages': ['English', 'Spanish'],
        'interests': ['Sports', 'Music', 'Arts'],
        'journeyTypes': ['Shopping trips', 'Concerts/Events', 'Dining out'],
        'ethnicity': 'Prefer not to say',
        'availability': ['Weekday evenings', 'Weekend mornings'],
        'communicationStyle': 'Moderate',
        'transportation': ['Car owner', 'Rideshare'],
        'currentStep': 2,
      };

      await prefs.setString('profile_progress', jsonEncode(profileData));
      
      final savedData = prefs.getString('profile_progress');
      expect(savedData, isNotNull);
      
      final parsedData = jsonDecode(savedData!) as Map<String, dynamic>;
      expect(parsedData['bio'], 'This is my bio text that is long enough to pass validation');
      expect(parsedData['occupation'], 'Professional');
      expect(parsedData['languages'], ['English', 'Spanish']);
      expect(parsedData['currentStep'], 2);
    });

    test('Profile progress is cleared after completion', () async {
      // First save progress
      final profileData = {'bio': 'Test bio', 'currentStep': 1};
      await prefs.setString('profile_progress', jsonEncode(profileData));
      
      // Simulate completing profile
      await prefs.setBool('profile_complete', true);
      await prefs.remove('profile_progress');

      expect(prefs.getBool('profile_complete'), true);
      expect(prefs.getString('profile_progress'), isNull);
    });

    test('Custom occupation is stored correctly', () async {
      final profileData = {
        'occupation': 'Other',
        'customOccupation': 'AI Engineer',
      };

      await prefs.setString('profile_progress', jsonEncode(profileData));
      
      final savedData = prefs.getString('profile_progress');
      final parsedData = jsonDecode(savedData!) as Map<String, dynamic>;
      
      expect(parsedData['occupation'], 'Other');
      expect(parsedData['customOccupation'], 'AI Engineer');
    });
  });

  group('Profile Validation Tests', () {
    test('Bio validation - minimum length', () {
      const bio = 'This is a test bio';
      const minLength = 37;
      expect(bio.length >= minLength, false);
      
      const validBio = 'This is a test bio that is long enough';
      expect(validBio.length >= minLength, true);
    });

    test('Journey types validation - minimum selection', () {
      final journeyTypes = ['Shopping trips'];
      const minRequired = 3;
      expect(journeyTypes.length >= minRequired, false);
      
      journeyTypes.addAll(['Concerts/Events', 'Dining out']);
      expect(journeyTypes.length >= minRequired, true);
    });

    test('Step 1 validation logic', () {
      // Mock Step 1 data
      String bio = '';
      String? occupation;
      String customOccupation = '';
      List<String> languages = [];

      bool validateStep1() =>
          bio.length >= 37 &&
          occupation != null &&
          (occupation != 'Other' || customOccupation.isNotEmpty) &&
          languages.isNotEmpty;

      // All empty - should fail
      expect(validateStep1(), false);

      // Add bio
      bio = 'This is my bio that is definitely long enough';
      expect(validateStep1(), false);

      // Add occupation
      occupation = 'Professional';
      expect(validateStep1(), false);

      // Add language
      languages.add('English');
      expect(validateStep1(), true);

      // Test Other occupation without custom text
      occupation = 'Other';
      expect(validateStep1(), false);

      // Add custom occupation
      customOccupation = 'Custom Job';
      expect(validateStep1(), true);
    });

    test('Step 2 validation logic', () {
      List<String> interests = [];
      List<String> journeyTypes = [];

      bool validateStep2() =>
          interests.isNotEmpty &&
          journeyTypes.length >= 3;

      expect(validateStep2(), false);

      interests.add('Sports');
      expect(validateStep2(), false);

      journeyTypes.addAll(['Type 1', 'Type 2']);
      expect(validateStep2(), false);

      journeyTypes.add('Type 3');
      expect(validateStep2(), true);
    });

    test('Step 3 validation logic', () {
      String? ethnicity;
      List<String> availability = [];
      String? communicationStyle;
      List<String> transportation = [];

      bool validateStep3() =>
          ethnicity != null &&
          availability.isNotEmpty &&
          communicationStyle != null &&
          transportation.isNotEmpty;

      expect(validateStep3(), false);

      ethnicity = 'Prefer not to say';
      expect(validateStep3(), false);

      availability.add('Weekday evenings');
      expect(validateStep3(), false);

      communicationStyle = 'Moderate';
      expect(validateStep3(), false);

      transportation.add('Car owner');
      expect(validateStep3(), true);
    });
  });
}
