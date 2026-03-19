// =============================================================================
// FILE: test/helpers/firebase_test_setup.dart
// Firebase mock setup for widget tests that import Firebase-dependent screens
// =============================================================================

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Callback = void Function(MethodCall call);

/// Sets up Firebase Core mock so widgets that import Firebase-dependent
/// services (AuthService, JourneyService, etc.) can be instantiated in tests.
///
/// Call this at the top of main() in any widget test that uses screens
/// which directly import Firebase packages.
void setupFirebaseMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();

  setupFirebaseCoreMocks();
}
