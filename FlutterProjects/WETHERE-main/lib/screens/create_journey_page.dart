// ============================================================================
// FILE: lib/screens/create_journey_page.dart
// Complete file with all BuildContext issues fixed
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// AppTheme import removed (unused) to tidy warnings
import 'package:wethere/models/journey_model.dart';
import 'package:wethere/providers/journey_provider.dart';
import 'package:wethere/services/auth_service.dart';
import 'package:wethere/services/image_generation_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateJourneyPage extends StatefulWidget {
  final JourneyModel? existingJourney;

  const CreateJourneyPage({super.key, this.existingJourney});

  @override
  State<CreateJourneyPage> createState() => _CreateJourneyPageState();
}

class _CreateJourneyPageState extends State<CreateJourneyPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  final AuthService _authService = AuthService();
  final ImageGenerationService _imageGenService = ImageGenerationService();

  // Step 1
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingPointController = TextEditingController();

  // Step 2
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  // Step 3
  CompensationType? _selectedCompensationType;
  final _hourlyRateController = TextEditingController(text: '15');
  final _freeItemDescController = TextEditingController();
  final _coveredExpenseDescController = TextEditingController();
  final _choiceHourlyRateController = TextEditingController(text: '20');
  final _choiceFreeItemDescController = TextEditingController();
  String? _generatedImageUrl;
  bool _isGeneratingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingJourney != null) {
      final j = widget.existingJourney!;
      _titleController.text = j.title;
      _descriptionController.text = j.description;
      _locationController.text = j.location;
      _meetingPointController.text = j.meetingPoint;
      _selectedDate = j.date;
      _startTime = TimeOfDay.fromDateTime(j.startTime);
      _endTime = TimeOfDay.fromDateTime(j.endTime);
      _selectedCompensationType = j.compensationType;
      
      if (j.compensationType == CompensationType.hourlyPay) {
        _hourlyRateController.text = j.hourlyRate?.toString() ?? '15';
      } else if (j.compensationType == CompensationType.freeItem) {
        _freeItemDescController.text = j.freeItemDesc ?? '';
      } else if (j.compensationType == CompensationType.coveredExpense) {
        _coveredExpenseDescController.text = j.coveredExpenseDesc ?? '';
      } else if (j.compensationType == CompensationType.companionChoice) {
        _choiceHourlyRateController.text = j.hourlyRate?.toString() ?? '20';
        _choiceFreeItemDescController.text = j.freeItemDesc ?? '';
      }
      _generatedImageUrl = j.imageUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingPointController.dispose();
    _hourlyRateController.dispose();
    _freeItemDescController.dispose();
    _coveredExpenseDescController.dispose();
    _choiceHourlyRateController.dispose();
    _choiceFreeItemDescController.dispose();
    super.dispose();
  }

  // ========================================================================
  // CREATE / UPDATE JOURNEY (SAFE)
  // ========================================================================

  bool get _isEditing => widget.existingJourney != null;

  Future<void> _createJourney() async {
    setState(() => _isCreating = true);

    // ✅ Read provider BEFORE async
    final journeyProvider = context.read<JourneyProvider>();

    String finalImageUrl = _generatedImageUrl ?? 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80&w=800';
    
    // If we haven't generated one yet, try to generate it now
    if (_generatedImageUrl == null && _titleController.text.isNotEmpty) {
      try {
        // Wait at most 12 seconds for image generation/upload to avoid blocking user
        await _manualGenerateImage().timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('Image generation timed out or failed: $e. Using fallback image to proceed.');
        // If it times out, _generatedImageUrl remains null, and we'll use finalImageUrl fallback.
      }
      
      if (_generatedImageUrl != null) {
        finalImageUrl = _generatedImageUrl!;
      }
    }

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final userData = await _authService.getUserData(currentUser.uid);

      // Build a robust hostName fallback chain:
      // 1) Firestore firstName + lastName
      // 2) Firestore displayName
      // 3) FirebaseAuth currentUser.displayName
      // 4) Email local-part
      // 5) 'Anonymous'
      String hostName = 'Anonymous';
      if (userData != null) {
        final fn = (userData['firstName'] ?? '').toString().trim();
        final ln = (userData['lastName'] ?? '').toString().trim();
        if (fn.isNotEmpty || ln.isNotEmpty) {
          hostName = '$fn ${ln}'.trim();
        } else if ((userData['displayName'] ?? '').toString().trim().isNotEmpty) {
          hostName = (userData['displayName'] ?? '').toString().trim();
        }
      }

      // If still anonymous, try FirebaseAuth displayName
      if (hostName == 'Anonymous') {
        final authDisplay = currentUser.displayName;
        if (authDisplay != null && authDisplay.trim().isNotEmpty) {
          hostName = authDisplay.trim();
        }
      }

      // If still anonymous, try email local-part
      if (hostName == 'Anonymous' && currentUser.email != null) {
        final email = currentUser.email!;
        final local = email.split('@').first;
        if (local.trim().isNotEmpty) hostName = local.trim();
      }

      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final durationMinutes =
          endDateTime.difference(startDateTime).inMinutes;

      if (durationMinutes <= 0) {
        throw Exception('End time must be after start time');
      }

      final durationHours = (durationMinutes / 60).ceil();

      final locationParts = _locationController.text.split(',');
      final city = locationParts.length > 1
          ? locationParts.last.trim()
          : _locationController.text;

      // Validate Address & Get Coordinates
      final address = _locationController.text.trim();
      GeoPoint? coordinates;
      try {
        List<Location> locations = await locationFromAddress(address);
        if (locations.isNotEmpty) {
          final loc = locations.first;
          coordinates = GeoPoint(loc.latitude, loc.longitude);
        } else {
           throw Exception('Address not found');
        }
      } catch (e) {
        // Geocoding failed. Fallback to heuristic validation to reject "random text".
        // Rule: Must be > 5 chars AND (contain a comma OR contain a digit).
        // This accepts "123 Main St" (digit), "Paris, France" (comma), but rejects "hello world" (no digit/comma).
        bool hasComma = address.contains(',');
        bool hasDigit = RegExp(r'\d').hasMatch(address);
        bool isLongEnough = address.length > 5;
        
        if (isLongEnough && (hasComma || hasDigit)) {
           print('Geocoding warning: Could not verify address but format seems valid. Proceeding.');
           coordinates = null;
        } else {
           throw Exception('Address could not be verified and format is invalid. Please enter a full address (e.g. "Street, City").');
        }
      }

      final journey = JourneyModel(
        hostUserId: currentUser.uid,
        hostName: hostName,
        hostAvatar: userData?['profileImageUrl'],
        title: _titleController.text,
        description: _descriptionController.text,
        imageUrl: finalImageUrl,
        location: _locationController.text,
        locationCoordinates: coordinates, // Added coordinates
        meetingPoint: _meetingPointController.text,
        date: _selectedDate,
        startTime: startDateTime,
        endTime: endDateTime,
        duration: durationHours,
        compensationType: _selectedCompensationType!,
        hourlyRate: _selectedCompensationType == CompensationType.hourlyPay
            ? int.tryParse(_hourlyRateController.text)
            : _selectedCompensationType ==
                    CompensationType.companionChoice
                ? int.tryParse(_choiceHourlyRateController.text)
                : null,
        freeItemDesc: _selectedCompensationType == CompensationType.freeItem
            ? _freeItemDescController.text
            : _selectedCompensationType ==
                    CompensationType.companionChoice
                ? _choiceFreeItemDescController.text
                : null,
        coveredExpenseDesc:
            _selectedCompensationType == CompensationType.coveredExpense
                ? _coveredExpenseDescController.text
                : null,
        city: city,
        tags: _generateTags(),
      );

      final journeyId =
          await journeyProvider.createJourney(journey);

      if (!mounted) return;

      if (journeyId == null) {
        throw Exception('Failed to create journey');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Journey "${_titleController.text}" created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _updateJourney() async {
    setState(() => _isCreating = true);

    final journeyProvider = context.read<JourneyProvider>();

    try {
      final startDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final endDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      final durationMinutes =
          endDateTime.difference(startDateTime).inMinutes;

      if (durationMinutes <= 0) {
        throw Exception('End time must be after start time');
      }

      final durationHours = (durationMinutes / 60).ceil();

      final locationParts = _locationController.text.split(',');
      final city = locationParts.length > 1
          ? locationParts.last.trim()
          : _locationController.text;

      final updates = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'meetingPoint': _meetingPointController.text,
        'date': Timestamp.fromDate(_selectedDate),
        'startTime': Timestamp.fromDate(startDateTime),
        'endTime': Timestamp.fromDate(endDateTime),
        'duration': durationHours,
        'compensationType': _selectedCompensationType!.toString().split('.').last,
        'hourlyRate': _selectedCompensationType == CompensationType.hourlyPay
            ? int.tryParse(_hourlyRateController.text)
            : _selectedCompensationType ==
                    CompensationType.companionChoice
                ? int.tryParse(_choiceHourlyRateController.text)
                : null,
        'freeItemDesc': _selectedCompensationType == CompensationType.freeItem
            ? _freeItemDescController.text
            : _selectedCompensationType ==
                    CompensationType.companionChoice
                ? _choiceFreeItemDescController.text
                : null,
        'coveredExpenseDesc':
            _selectedCompensationType == CompensationType.coveredExpense
                ? _coveredExpenseDescController.text
                : null,
        'city': city,
        'tags': _generateTags(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await journeyProvider.updateJourney(widget.existingJourney!.id!, updates);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Journey "${_titleController.text}" updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  Future<void> _manualGenerateImage() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title first')),
      );
      return;
    }

    setState(() => _isGeneratingImage = true);

    try {
      final generatedUrl = await _imageGenService.generateAndUploadImage(_titleController.text);
      if (generatedUrl != null) {
        setState(() {
          _generatedImageUrl = generatedUrl;
        });
      }
    } catch (e) {
      debugPrint('Error manually generating image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating image: $e')),
      );
    } finally {
      setState(() => _isGeneratingImage = false);
    }
  }

  // ========================================================================
  // TAGS
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Update Journey' : 'Create Journey')),
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
                  decoration: InputDecoration(
                    labelText: 'Title',
                    suffixIcon: _isGeneratingImage
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.image_search),
                            onPressed: _manualGenerateImage,
                            tooltip: 'Generate Image',
                          ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                if (_generatedImageUrl != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Journey Image Preview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            children: [
                              Image.network(
                                _generatedImageUrl!,
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 180,
                                  color: Colors.grey[200],
                                  child: const Center(child: Icon(Icons.broken_image)),
                                ),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: ElevatedButton.icon(
                                  onPressed: _isGeneratingImage ? null : _manualGenerateImage,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Regenerate'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.black.withOpacity(0.6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    hintText: 'e.g., 123 Main St, Seattle, WA 98101',
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Location is required';
                    final hasZip = v.contains(RegExp(r'\d{5}'));
                    if (!hasZip) return 'Please include a 5-digit zip code';
                    return null;
                  },
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
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: Text('Start: ${_startTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: _startTime);
                          if (t != null) setState(() => _startTime = t);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: Text('End: ${_endTime.format(context)}'),
                        trailing: const Icon(Icons.access_time),
                        onTap: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: _endTime);
                          if (t != null) setState(() => _endTime = t);
                        },
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
                          if (_formKey.currentState?.validate() ?? true) {
                            if (_isEditing) {
                              _updateJourney();
                            } else {
                              _createJourney();
                            }
                          }
                        },
                  child: _isCreating
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Update Journey' : 'Create Journey'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<String> _generateTags() {
    final text =
        '${_titleController.text} ${_descriptionController.text}'
            .toLowerCase();

    final tags = <String>[];

    if (text.contains('shop')) tags.add('shopping');
    if (text.contains('food') || text.contains('dinner')) tags.add('food');
    if (text.contains('concert') || text.contains('music')) {
      tags.add('entertainment');
    }
    if (text.contains('gym') || text.contains('workout')) {
      tags.add('fitness');
    }
    if (text.contains('hike') || text.contains('outdoor')) {
      tags.add('outdoor');
    }

    return tags;
  }
}
