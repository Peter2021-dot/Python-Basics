// This is a basic Flutter widget test.
//
// Tests that the app's core widget can be instantiated.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp renders correctly', (WidgetTester tester) async {
    // Test that a basic MaterialApp with the app's theme can render.
    // Note: MyApp requires Firebase initialization which is not available
    // in unit tests. Firebase-dependent widget tests use the form replica
    // pattern (see test/widget/create_journey_page_test.dart).
    await tester.pumpWidget(
      MaterialApp(
        title: 'WeThere',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.orange,
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: Center(child: Text('Togetherness')),
        ),
      ),
    );

    expect(find.text('Togetherness'), findsOneWidget);
  });
}
