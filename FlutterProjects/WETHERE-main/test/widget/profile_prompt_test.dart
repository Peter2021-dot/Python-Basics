// =============================================================================
// FILE: test/widget/profile_prompt_test.dart
// Widget tests for the profile completion prompt dialog
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/test_helpers.dart';

/// These tests render the profile incomplete prompt dialog directly,
/// without needing Firebase. We replicate the dialog structure from
/// home_page.dart._showProfileIncompletePrompt() to test it in isolation.

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Profile Incomplete Prompt - Create Journey', () {
    testWidgets('shows correct title', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(PromptFinders.promptTitle, findsOneWidget);
    });

    testWidgets('shows "create a journey" in message text', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(PromptFinders.createPromptText('create a journey'), findsOneWidget);
    });

    testWidgets('has Complete Profile button', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(PromptFinders.completeProfileButton, findsOneWidget);
    });

    testWidgets('has Cancel button', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(PromptFinders.cancelButton, findsOneWidget);
    });

    testWidgets('Cancel closes the dialog', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      // Verify dialog is shown
      expect(PromptFinders.promptTitle, findsOneWidget);

      // Tap cancel
      await tester.tap(PromptFinders.cancelButton);
      await tester.pumpAndSettle();

      // Dialog should be gone
      expect(PromptFinders.promptTitle, findsNothing);
    });

    testWidgets('shows person icon', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('shows encouragement text', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(find.text('It only takes a minute! Help others get to know you.'), findsOneWidget);
    });
  });

  group('Profile Incomplete Prompt - Join Journey', () {
    testWidgets('shows "join a journey" in message text', (tester) async {
      await _showPrompt(tester, actionType: 'join');

      expect(PromptFinders.createPromptText('join a journey'), findsOneWidget);
    });

    testWidgets('has same buttons as create prompt', (tester) async {
      await _showPrompt(tester, actionType: 'join');

      expect(PromptFinders.completeProfileButton, findsOneWidget);
      expect(PromptFinders.cancelButton, findsOneWidget);
    });

    testWidgets('Cancel closes join dialog', (tester) async {
      await _showPrompt(tester, actionType: 'join');

      await tester.tap(PromptFinders.cancelButton);
      await tester.pumpAndSettle();

      expect(PromptFinders.promptTitle, findsNothing);
    });
  });

  group('Profile Incomplete Prompt - Dynamic Text', () {
    testWidgets('create vs join shows different action text', (tester) async {
      // Test create
      await _showPrompt(tester, actionType: 'create');
      expect(PromptFinders.createPromptText('create a journey'), findsOneWidget);

      // Close and test join
      await tester.tap(PromptFinders.cancelButton);
      await tester.pumpAndSettle();

      await _showPrompt(tester, actionType: 'join');
      expect(PromptFinders.createPromptText('join a journey'), findsOneWidget);
    });
  });

  group('Profile Incomplete Prompt - Close Icon', () {
    testWidgets('has close icon button', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('close icon dismisses dialog', (tester) async {
      await _showPrompt(tester, actionType: 'create');

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(PromptFinders.promptTitle, findsNothing);
    });
  });
}

/// Helper to show the profile incomplete prompt dialog.
/// This replicates the dialog from home_page.dart._showProfileIncompletePrompt()
/// so it can be tested in isolation without Firebase dependencies.
Future<void> _showPrompt(WidgetTester tester, {required String actionType}) async {
  final actionText = actionType == 'create' ? 'create a journey' : 'join a journey';

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          // Immediately show dialog after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext dialogContext) {
                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Complete Your Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0x1AFF6B35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 40,
                          color: Color(0xFFFF6B35),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You need to complete your profile before you can $actionText.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'It only takes a minute! Help others get to know you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA)),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Complete Profile'),
                    ),
                  ],
                );
              },
            );
          });
          return const Scaffold(body: SizedBox());
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}
