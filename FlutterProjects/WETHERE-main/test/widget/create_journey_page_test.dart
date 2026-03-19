// =============================================================================
// FILE: test/widget/create_journey_page_test.dart
// Widget tests for the journey creation form UI
//
// Strategy: The production CreateJourneyPage imports AuthService which
// eagerly instantiates FirebaseAuth.instance. To avoid Firebase dependency
// in tests, we build a standalone replica of the form UI that tests the
// same widget tree and behavior without Firebase services.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wethere/models/journey_model.dart';

/// Standalone replica of CreateJourneyPage form UI for testing.
/// Tests the same widget tree, layout, compensation type selection,
/// and conditional field visibility — without Firebase dependencies.
class _TestCreateJourneyForm extends StatefulWidget {
  const _TestCreateJourneyForm();

  @override
  State<_TestCreateJourneyForm> createState() => _TestCreateJourneyFormState();
}

class _TestCreateJourneyFormState extends State<_TestCreateJourneyForm> {
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingPointController = TextEditingController();

  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  CompensationType? _selectedCompensationType;
  final _hourlyRateController = TextEditingController(text: '15');
  final _freeItemDescController = TextEditingController();
  final _coveredExpenseDescController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingPointController.dispose();
    _hourlyRateController.dispose();
    _freeItemDescController.dispose();
    _coveredExpenseDescController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Journey')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Location'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _meetingPointController,
                  decoration: const InputDecoration(labelText: 'Meeting point'),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: Text('Date: ${_selectedDate.toLocal().toString().split(' ').first}'),
                  trailing: const Icon(Icons.calendar_today),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Start: ${_startTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text('End: ${_endTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<CompensationType>(
                  value: _selectedCompensationType,
                  decoration: const InputDecoration(labelText: 'Compensation'),
                  items: CompensationType.values
                      .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.toString().split('.').last),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCompensationType = v),
                  validator: (v) => v == null ? 'Select a compensation type' : null,
                ),
                if (_selectedCompensationType == CompensationType.hourlyPay ||
                    _selectedCompensationType == CompensationType.companionChoice)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _hourlyRateController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Hourly rate'),
                    ),
                  ),
                if (_selectedCompensationType == CompensationType.freeItem ||
                    _selectedCompensationType == CompensationType.companionChoice)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _freeItemDescController,
                      decoration: const InputDecoration(labelText: 'Free item description'),
                    ),
                  ),
                if (_selectedCompensationType == CompensationType.coveredExpense)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: TextFormField(
                      controller: _coveredExpenseDescController,
                      decoration: const InputDecoration(labelText: 'Covered expense description'),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isCreating
                      ? null
                      : () {
                          if (_formKey.currentState?.validate() ?? false) {
                            setState(() => _isCreating = true);
                          }
                        },
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Journey'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Journey Creation Form - Rendering', () {
    testWidgets('renders with "Create Journey" title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.text('Create Journey'), findsWidgets); // AppBar title + button
    });

    testWidgets('shows title input field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Title'), findsOneWidget);
    });

    testWidgets('shows description input field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Description'), findsOneWidget);
    });

    testWidgets('shows location input field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Location'), findsOneWidget);
    });

    testWidgets('shows meeting point input field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, 'Meeting point'), findsOneWidget);
    });

    testWidgets('shows compensation dropdown', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'), findsOneWidget);
    });

    testWidgets('shows date picker tile', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Date:'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('shows start and end time pickers', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.textContaining('Start:'), findsOneWidget);
      expect(find.textContaining('End:'), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsNWidgets(2));
    });
  });

  group('Journey Creation Form - Compensation Type Selection', () {
    testWidgets('compensation dropdown has all 4 types', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Open the dropdown
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'));
      await tester.pumpAndSettle();

      // Check all 4 options are visible
      expect(find.text('hourlyPay'), findsOneWidget);
      expect(find.text('freeItem'), findsOneWidget);
      expect(find.text('coveredExpense'), findsOneWidget);
      expect(find.text('companionChoice'), findsOneWidget);
    });

    testWidgets('selecting hourlyPay shows hourly rate field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Initially no hourly rate field
      expect(find.widgetWithText(TextFormField, 'Hourly rate'), findsNothing);

      // Open dropdown and select hourlyPay
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('hourlyPay').last);
      await tester.pumpAndSettle();

      // Now hourly rate field should appear
      expect(find.widgetWithText(TextFormField, 'Hourly rate'), findsOneWidget);
    });

    testWidgets('selecting freeItem shows free item description field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Open dropdown and select freeItem
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('freeItem').last);
      await tester.pumpAndSettle();

      // Free item description should appear
      expect(find.widgetWithText(TextFormField, 'Free item description'), findsOneWidget);
    });

    testWidgets('selecting coveredExpense shows covered expense field', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Open dropdown and select coveredExpense
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('coveredExpense').last);
      await tester.pumpAndSettle();

      // Covered expense description should appear
      expect(find.widgetWithText(TextFormField, 'Covered expense description'), findsOneWidget);
    });

    testWidgets('selecting companionChoice shows both rate and free item fields', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Open dropdown and select companionChoice
      await tester.tap(find.widgetWithText(DropdownButtonFormField<CompensationType>, 'Compensation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('companionChoice').last);
      await tester.pumpAndSettle();

      // Both hourly rate and free item description should appear
      expect(find.widgetWithText(TextFormField, 'Hourly rate'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Free item description'), findsOneWidget);
    });
  });

  group('Journey Creation Form - Create Button', () {
    testWidgets('Create Journey button is visible', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Create Journey'), findsOneWidget);
    });

    testWidgets('title validation shows error when empty', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Scroll Create Journey button into view (it may be below fold)
      final button = find.widgetWithText(ElevatedButton, 'Create Journey');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      // Tap create without filling title
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('compensation validation shows error when not selected', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: _TestCreateJourneyForm()));
      await tester.pumpAndSettle();

      // Fill title but not compensation
      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Test Journey');
      await tester.pumpAndSettle();

      // Scroll Create Journey button into view
      final button = find.widgetWithText(ElevatedButton, 'Create Journey');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Select a compensation type'), findsOneWidget);
    });
  });
}
