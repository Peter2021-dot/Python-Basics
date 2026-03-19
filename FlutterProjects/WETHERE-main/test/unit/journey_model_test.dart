// =============================================================================
// FILE: test/unit/journey_model_test.dart
// Unit tests for JourneyModel pure logic
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:wethere/models/journey_model.dart';

void main() {
  group('JourneyModel - Badge Text', () {
    test('hourlyPay badge shows rate per hour', () {
      final journey = _createJourney(
        compensationType: CompensationType.hourlyPay,
        hourlyRate: 25,
      );
      expect(journey.badgeText, '\$25/h');
    });

    test('hourlyPay badge handles null rate', () {
      final journey = _createJourney(
        compensationType: CompensationType.hourlyPay,
        hourlyRate: null,
      );
      expect(journey.badgeText, '\$0/h');
    });

    test('freeItem badge shows emoji and description', () {
      final journey = _createJourney(
        compensationType: CompensationType.freeItem,
        freeItemEmoji: '🎟️',
        freeItemDesc: 'Concert Ticket',
      );
      expect(journey.badgeText, '🎟️ Concert Ticket');
    });

    test('freeItem badge handles null values', () {
      final journey = _createJourney(
        compensationType: CompensationType.freeItem,
      );
      expect(journey.badgeText, '🎫 Free');
    });

    test('coveredExpense badge shows emoji and description', () {
      final journey = _createJourney(
        compensationType: CompensationType.coveredExpense,
        coveredExpenseEmoji: '🍕',
        coveredExpenseDesc: 'Dinner',
      );
      expect(journey.badgeText, '🍕 Dinner');
    });

    test('coveredExpense badge handles null values', () {
      final journey = _createJourney(
        compensationType: CompensationType.coveredExpense,
      );
      expect(journey.badgeText, '🍽️ Covered');
    });

    test('companionChoice badge shows rate OR freeItem', () {
      final journey = _createJourney(
        compensationType: CompensationType.companionChoice,
        hourlyRate: 20,
        freeItemEmoji: '🎫',
      );
      expect(journey.badgeText, '\$20/h OR 🎫 Free');
    });
  });

  group('JourneyModel - Badge Color Hex', () {
    test('hourlyPay color is orange', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      expect(journey.badgeColorHex, '#FF6B35');
    });

    test('freeItem color is green', () {
      final journey = _createJourney(compensationType: CompensationType.freeItem);
      expect(journey.badgeColorHex, '#4CAF50');
    });

    test('coveredExpense color is teal', () {
      final journey = _createJourney(compensationType: CompensationType.coveredExpense);
      expect(journey.badgeColorHex, '#26A69A');
    });

    test('companionChoice color is purple', () {
      final journey = _createJourney(compensationType: CompensationType.companionChoice);
      expect(journey.badgeColorHex, '#7C4DFF');
    });
  });

  group('JourneyModel - toMap Serialization', () {
    test('toMap includes all required fields', () {
      final journey = _createJourney(
        compensationType: CompensationType.hourlyPay,
        hourlyRate: 30,
      );
      final map = journey.toMap();

      expect(map['hostUserId'], 'host-123');
      expect(map['hostName'], 'Test Host');
      expect(map['title'], 'Test Journey');
      expect(map['description'], 'A test journey');
      expect(map['location'], 'New York');
      expect(map['meetingPoint'], 'Central Park');
      expect(map['duration'], 2);
      expect(map['compensationType'], 'hourlyPay');
      expect(map['hourlyRate'], 30);
      expect(map['status'], 'open');
      expect(map['maxCompanions'], 1);
      expect(map['city'], 'New York');
      expect(map['tags'], isEmpty);
    });

    test('toMap serializes compensation type as string', () {
      for (final type in CompensationType.values) {
        final journey = _createJourney(compensationType: type);
        final map = journey.toMap();
        expect(map['compensationType'], type.toString().split('.').last);
      }
    });
  });

  group('JourneyModel - toUiMap', () {
    test('toUiMap includes UI display fields', () {
      final journey = _createJourney(
        compensationType: CompensationType.freeItem,
        freeItemDesc: 'Movie Ticket',
        freeItemEmoji: '🎬',
      );
      final uiMap = journey.toUiMap();

      expect(uiMap['hostName'], 'Test Host');
      expect(uiMap['title'], 'Test Journey');
      expect(uiMap['location'], 'New York');
      expect(uiMap['compensationType'], 'freeItem');
      expect(uiMap['freeItemDesc'], 'Movie Ticket');
      expect(uiMap['freeItemEmoji'], '🎬');
    });

    test('toUiMap serializes dates as ISO strings', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      final uiMap = journey.toUiMap();

      expect(uiMap['date'], isA<String>());
      expect(uiMap['startTime'], isA<String>());
      expect(uiMap['endTime'], isA<String>());
    });
  });

  group('JourneyModel - Defaults', () {
    test('default status is open', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      expect(journey.status, 'open');
    });

    test('default maxCompanions is 1', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      expect(journey.maxCompanions, 1);
    });

    test('default currentApplicants is 0', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      expect(journey.currentApplicants, 0);
    });

    test('default views is 0', () {
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      expect(journey.views, 0);
    });

    test('createdAt and updatedAt default to now', () {
      final before = DateTime.now();
      final journey = _createJourney(compensationType: CompensationType.hourlyPay);
      final after = DateTime.now();

      expect(journey.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(journey.updatedAt.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });
  });
}

/// Helper to create a JourneyModel with minimal required fields
JourneyModel _createJourney({
  required CompensationType compensationType,
  int? hourlyRate,
  String? freeItemDesc,
  String? freeItemEmoji,
  String? coveredExpenseDesc,
  String? coveredExpenseEmoji,
}) {
  return JourneyModel(
    hostUserId: 'host-123',
    hostName: 'Test Host',
    title: 'Test Journey',
    description: 'A test journey',
    imageUrl: 'https://example.com/image.jpg',
    location: 'New York',
    meetingPoint: 'Central Park',
    date: DateTime(2026, 3, 15),
    startTime: DateTime(2026, 3, 15, 10, 0),
    endTime: DateTime(2026, 3, 15, 12, 0),
    duration: 2,
    compensationType: compensationType,
    hourlyRate: hourlyRate,
    freeItemDesc: freeItemDesc,
    freeItemEmoji: freeItemEmoji,
    coveredExpenseDesc: coveredExpenseDesc,
    coveredExpenseEmoji: coveredExpenseEmoji,
    city: 'New York',
  );
}
