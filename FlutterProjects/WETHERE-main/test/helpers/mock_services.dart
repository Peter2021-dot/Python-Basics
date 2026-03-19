// =============================================================================
// FILE: test/helpers/mock_services.dart
// Mock services for widget testing
// =============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wethere/providers/journey_provider.dart';
import 'package:wethere/providers/application_provider.dart';

/// Creates a widget wrapped with all necessary providers for testing.
/// Note: Provider-based tests that don't call Firestore work fine.
/// For tests that DO trigger Firestore (e.g. createJourney), you'd
/// need fake_cloud_firestore. For now, tests focus on UI rendering
/// and validation logic that doesn't hit Firebase.
Widget wrapWithProviders(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => JourneyProvider()),
      ChangeNotifierProvider(create: (_) => ApplicationProvider()),
    ],
    child: MaterialApp(
      home: child,
    ),
  );
}

/// Creates a widget wrapped with providers and Scaffold for testing.
Widget wrapWithProvidersAndScaffold(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => JourneyProvider()),
      ChangeNotifierProvider(create: (_) => ApplicationProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(body: child),
    ),
  );
}
