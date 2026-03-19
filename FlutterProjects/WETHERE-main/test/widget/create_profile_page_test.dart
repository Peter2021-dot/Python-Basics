// =============================================================================
// FILE: test/widget/create_profile_page_test.dart
// Widget tests for the multi-step profile completion form
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wethere/screens/create_profile_page.dart';
import '../helpers/test_helpers.dart';
import '../helpers/mock_data.dart';

void main() {
  setUp(() {
    // Initialize SharedPreferences with empty mock values
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Form - Rendering', () {
    testWidgets('renders with appbar title "Complete Your Profile"', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Complete Your Profile'), findsOneWidget);
    });

    testWidgets('shows progress indicator', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(ProfileFinders.progressIndicator, findsOneWidget);
    });

    testWidgets('shows "Step 1 of 3" initially', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 3'), findsOneWidget);
    });

    testWidgets('shows "About You" as step label on step 1', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('About You'), findsOneWidget);
    });
  });

  group('Profile Form - Step 1 Fields', () {
    testWidgets('Step 1 shows bio text field', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(ProfileFinders.step1Title, findsOneWidget);
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Step 1 shows occupation section', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Occupation *'), findsOneWidget);
    });

    testWidgets('Step 1 shows languages section', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Languages Spoken *'), findsOneWidget);
    });

    testWidgets('Step 1 shows profile photo upload', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Add Photo (Optional)'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    });

    testWidgets('Step 1 shows Next button (not Back)', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(ProfileFinders.nextButton, findsOneWidget);
      expect(ProfileFinders.backButton, findsNothing);
    });
  });

  group('Profile Form - Step Navigation', () {
    testWidgets('cannot proceed from step 1 without filling fields', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Tap Next without filling anything
      await tester.tap(ProfileFinders.nextButton);
      await tester.pumpAndSettle();

      // Should still be on step 1
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(ProfileFinders.step1Title, findsOneWidget);
    });

    testWidgets('shows language chips that can be toggled', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Look for language filter chips
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Spanish'), findsOneWidget);
      expect(find.text('French'), findsOneWidget);
    });

    testWidgets('shows occupation dropdown options', (tester) async {
      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Find the dropdown and verify it exists
      expect(find.text('Select your occupation'), findsOneWidget);
    });
  });

  group('Profile Form - Progress Persistence', () {
    testWidgets('loads saved progress from SharedPreferences', (tester) async {
      // Pre-populate SharedPreferences with saved progress
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1And2),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Should be on step 3 (currentStep = 2 in the saved data)
      expect(find.text('Step 3 of 3'), findsOneWidget);
    });

    testWidgets('shows step 2 when step 1 progress is saved', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1Only),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Should be on step 2 (currentStep = 1)
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Interests'), findsOneWidget);
    });
  });

  group('Profile Form - Step 2 Content', () {
    testWidgets('Step 2 shows interests and journey type sections', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1Only),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Interests & Hobbies *'), findsOneWidget);
      expect(find.text('Preferred Journey Types *'), findsOneWidget);
    });

    testWidgets('Step 2 shows interest chips', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1Only),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      // Verify some interest chips are visible
      expect(find.text('Sports'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('Step 2 shows Back button', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1Only),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(ProfileFinders.backButton, findsOneWidget);
    });
  });

  group('Profile Form - Step 3 Content', () {
    testWidgets('Step 3 shows all detail fields', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1And2),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(find.text('Ethnicity *'), findsOneWidget);
      expect(find.text('Availability / Schedule *'), findsOneWidget);
      expect(find.text('Communication Style *'), findsOneWidget);
      expect(find.text('Transportation *'), findsOneWidget);
    });

    testWidgets('Step 3 shows Complete Profile button instead of Next', (tester) async {
      SharedPreferences.setMockInitialValues({
        'profile_progress': MockProfileData.encode(MockProfileData.step1And2),
      });

      await pumpApp(tester, const CreateProfilePage());
      await tester.pumpAndSettle();

      expect(ProfileFinders.completeButton, findsOneWidget);
      expect(ProfileFinders.nextButton, findsNothing);
    });
  });
}
