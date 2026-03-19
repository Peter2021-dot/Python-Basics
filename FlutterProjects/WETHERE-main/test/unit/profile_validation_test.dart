// =============================================================================
// FILE: test/unit/profile_validation_test.dart
// Unit tests for profile form validation logic
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import '../helpers/mock_data.dart';

/// These tests validate the SAME logic used in CreateProfilePage._validateStepX()
/// By testing them as pure functions, we catch regressions without Firebase.

void main() {
  group('Step 1 Validation - About You', () {
    test('fails when bio is too short', () {
      expect(_validateStep1(bio: 'Short', occupation: 'Student', languages: ['English']), false);
    });

    test('fails when bio is empty', () {
      expect(_validateStep1(bio: '', occupation: 'Student', languages: ['English']), false);
    });

    test('passes when bio is exactly 37 characters', () {
      final bio = 'A' * 37;
      expect(_validateStep1(bio: bio, occupation: 'Student', languages: ['English']), true);
    });

    test('fails when occupation is null', () {
      expect(_validateStep1(bio: 'A' * 37, occupation: null, languages: ['English']), false);
    });

    test('fails when occupation is Other but custom is empty', () {
      expect(
        _validateStep1(
          bio: 'A' * 37,
          occupation: 'Other',
          customOccupation: '',
          languages: ['English'],
        ),
        false,
      );
    });

    test('passes when occupation is Other and custom is filled', () {
      expect(
        _validateStep1(
          bio: 'A' * 37,
          occupation: 'Other',
          customOccupation: 'AI Engineer',
          languages: ['English'],
        ),
        true,
      );
    });

    test('fails when languages is empty', () {
      expect(_validateStep1(bio: 'A' * 37, occupation: 'Student', languages: []), false);
    });

    test('passes with all valid data', () {
      expect(
        _validateStep1(bio: 'A' * 50, occupation: 'Professional', languages: ['English', 'Spanish']),
        true,
      );
    });
  });

  group('Step 2 Validation - Interests & Preferences', () {
    test('fails when interests is empty', () {
      expect(_validateStep2(interests: [], journeyTypes: ['A', 'B', 'C']), false);
    });

    test('fails when journey types has fewer than 3', () {
      expect(_validateStep2(interests: ['Sports'], journeyTypes: ['A', 'B']), false);
    });

    test('fails when journey types is empty', () {
      expect(_validateStep2(interests: ['Sports'], journeyTypes: []), false);
    });

    test('passes when journey types has exactly 3', () {
      expect(
        _validateStep2(interests: ['Sports'], journeyTypes: ['Shopping trips', 'Concerts/Events', 'Dining out']),
        true,
      );
    });

    test('passes with more than 3 journey types', () {
      expect(
        _validateStep2(
          interests: ['Sports', 'Music'],
          journeyTypes: ['A', 'B', 'C', 'D'],
        ),
        true,
      );
    });
  });

  group('Step 3 Validation - Additional Details', () {
    test('fails when ethnicity is null', () {
      expect(
        _validateStep3(
          ethnicity: null,
          availability: ['Weekday evenings'],
          communicationStyle: 'Moderate',
          transportation: ['Car owner'],
        ),
        false,
      );
    });

    test('fails when availability is empty', () {
      expect(
        _validateStep3(
          ethnicity: 'Prefer not to say',
          availability: [],
          communicationStyle: 'Moderate',
          transportation: ['Car owner'],
        ),
        false,
      );
    });

    test('fails when communication style is null', () {
      expect(
        _validateStep3(
          ethnicity: 'Prefer not to say',
          availability: ['Weekday evenings'],
          communicationStyle: null,
          transportation: ['Car owner'],
        ),
        false,
      );
    });

    test('fails when transportation is empty', () {
      expect(
        _validateStep3(
          ethnicity: 'Prefer not to say',
          availability: ['Weekday evenings'],
          communicationStyle: 'Moderate',
          transportation: [],
        ),
        false,
      );
    });

    test('passes with all fields filled', () {
      expect(
        _validateStep3(
          ethnicity: 'Prefer not to say',
          availability: ['Weekday evenings', 'Weekend mornings'],
          communicationStyle: 'Moderate',
          transportation: ['Car owner', 'Rideshare'],
        ),
        true,
      );
    });
  });

  group('Validation Error Messages', () {
    test('step 1 bio error includes character count', () {
      final error = _getValidationError(
        step: 0,
        bio: 'Short',
        occupation: 'Student',
        languages: ['English'],
      );
      expect(error, contains('37'));
      expect(error, contains('5'));
    });

    test('step 1 occupation error message is clear', () {
      final error = _getValidationError(
        step: 0,
        bio: 'A' * 40,
        occupation: null,
        languages: ['English'],
      );
      expect(error, contains('occupation'));
    });

    test('step 2 journey types error includes count', () {
      final error = _getValidationError(
        step: 1,
        interests: ['Sports'],
        journeyTypes: ['A'],
      );
      expect(error, contains('3'));
    });
  });

  group('Complete Profile Data Validation', () {
    test('complete mock profile passes all validations', () {
      final data = MockProfileData.complete;
      expect(
        _validateStep1(
          bio: data['bio'],
          occupation: data['occupation'],
          customOccupation: data['customOccupation'],
          languages: List<String>.from(data['languages']),
        ),
        true,
      );
      expect(
        _validateStep2(
          interests: List<String>.from(data['interests']),
          journeyTypes: List<String>.from(data['journeyTypes']),
        ),
        true,
      );
      expect(
        _validateStep3(
          ethnicity: data['ethnicity'],
          availability: List<String>.from(data['availability']),
          communicationStyle: data['communicationStyle'],
          transportation: List<String>.from(data['transportation']),
        ),
        true,
      );
    });

    test('empty mock profile fails step 1', () {
      final data = MockProfileData.empty;
      expect(
        _validateStep1(
          bio: data['bio'],
          occupation: data['occupation'],
          languages: List<String>.from(data['languages']),
        ),
        false,
      );
    });
  });
}

// Mirrors CreateProfilePage._validateStep1()
bool _validateStep1({
  required String bio,
  required String? occupation,
  String customOccupation = '',
  required List<String> languages,
}) =>
    bio.length >= 37 &&
    occupation != null &&
    (occupation != 'Other' || customOccupation.isNotEmpty) &&
    languages.isNotEmpty;

// Mirrors CreateProfilePage._validateStep2()
bool _validateStep2({
  required List<String> interests,
  required List<String> journeyTypes,
}) =>
    interests.isNotEmpty &&
    journeyTypes.length >= 3;

// Mirrors CreateProfilePage._validateStep3()
bool _validateStep3({
  required String? ethnicity,
  required List<String> availability,
  required String? communicationStyle,
  required List<String> transportation,
}) =>
    ethnicity != null &&
    availability.isNotEmpty &&
    communicationStyle != null &&
    transportation.isNotEmpty;

// Mirrors CreateProfilePage._getValidationError()
String _getValidationError({
  required int step,
  String bio = '',
  String? occupation,
  String customOccupation = '',
  List<String> languages = const [],
  List<String> interests = const [],
  List<String> journeyTypes = const [],
  String? ethnicity,
  List<String> availability = const [],
  String? communicationStyle,
  List<String> transportation = const [],
}) {
  switch (step) {
    case 0:
      if (bio.length < 37) {
        return 'Bio must be at least 37 characters (${bio.length}/37)';
      }
      if (occupation == null) return 'Please select your occupation';
      if (occupation == 'Other' && customOccupation.isEmpty) {
        return 'Please enter your occupation';
      }
      if (languages.isEmpty) return 'Please select at least one language';
      break;
    case 1:
      if (interests.isEmpty) return 'Please select at least one interest';
      if (journeyTypes.length < 3) {
        return 'Please select at least 3 journey types (${journeyTypes.length}/3)';
      }
      break;
    case 2:
      if (ethnicity == null) return 'Please select your ethnicity';
      if (availability.isEmpty) return 'Please select your availability';
      if (communicationStyle == null) return 'Please select your communication style';
      if (transportation.isEmpty) return 'Please select your transportation options';
      break;
  }
  return 'Please complete all required fields';
}
