// =============================================================================
// FILE: test/helpers/test_helpers.dart
// Shared test utilities and widget wrappers
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wethere/providers/journey_provider.dart';
import 'package:wethere/providers/application_provider.dart';

/// Wraps a widget with MaterialApp for testing.
/// Use this for simple widget tests that don't need providers.
Widget wrapWithMaterialApp(Widget child) {
  return MaterialApp(
    home: child,
  );
}

/// Wraps a widget with MaterialApp and navigates to it via a route,
/// so Navigator operations work correctly.
Widget wrapWithScaffoldApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: child),
  );
}

/// Pumps a widget wrapped in MaterialApp.
Future<void> pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(wrapWithMaterialApp(child));
}

/// Common finders for profile form
class ProfileFinders {
  static Finder get bioField => find.byType(TextFormField).first;
  static Finder get nextButton => find.text('Next');
  static Finder get backButton => find.text('Back');
  static Finder get completeButton => find.text('Complete Profile');
  static Finder get step1Title => find.text('About Me *');
  static Finder get step2Title => find.text('Interests & Hobbies *');
  static Finder get step3Title => find.text('Ethnicity *');
  static Finder get progressIndicator => find.byType(LinearProgressIndicator);
}

/// Common finders for journey creation
class JourneyFinders {
  static Finder get titleField => find.widgetWithText(TextFormField, 'Title');
  static Finder get descriptionField => find.widgetWithText(TextFormField, 'Description');
  static Finder get locationField => find.widgetWithText(TextFormField, 'Location');
  static Finder get createButton => find.text('Create Journey');
  static Finder get compensationDropdown => find.widgetWithText(DropdownButtonFormField<dynamic>, 'Compensation');
}

/// Common finders for profile prompt
class PromptFinders {
  static Finder get promptTitle => find.text('Complete Your Profile');
  static Finder get cancelButton => find.text('Cancel');
  static Finder get completeProfileButton => find.text('Complete Profile');
  static Finder createPromptText(String action) =>
      find.textContaining('before you can $action');
}

/// Assertion helpers
void expectWidgetExists(Finder finder, {String? reason}) {
  expect(finder, findsOneWidget, reason: reason);
}

void expectWidgetNotExists(Finder finder, {String? reason}) {
  expect(finder, findsNothing, reason: reason);
}

void expectMultipleWidgets(Finder finder, int count, {String? reason}) {
  expect(finder, findsNWidgets(count), reason: reason);
}
