// ============================================================================
// FILE: lib/screens/create_journey_page.dart
// Complete file with all BuildContext issues fixed
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wethere/models/journey_model.dart';
import 'package:wethere/providers/journey_provider.dart';
import 'package:wethere/services/auth_service.dart';
import 'package:wethere/services/category_service.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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

  // Step 1
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _meetingPointController = TextEditingController();

  // Step 2
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  // Step 3 - Simplified compensation
  CompensationType? _selectedCompensationType;
  final _giftDescriptionController = TextEditingController();
  final _giftValueController = TextEditingController();
  String _selectedGiftEmoji = '🎁';
  
  // Category-based image system
  JourneyCategory? _selectedCategory;
  String? _selectedImageUrl;

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
      
      // Load gift details if editing existing journey
      if (j.compensationType == CompensationType.withGift) {
        _giftDescriptionController.text = j.giftDescription ?? '';
        _giftValueController.text = j.giftValue?.toString() ?? '';
        _selectedGiftEmoji = j.giftEmoji ?? '🎁';
      }
      _selectedImageUrl = j.imageUrl;
      
      // Try to find category based on existing image or title
      if (j.imageUrl != null && j.imageUrl!.isNotEmpty) {
        final foundCategory = CategoryService.getAllCategories().where(
          (cat) => cat.imagePath == j.imageUrl,
        ).firstOrNull;
        _selectedCategory = foundCategory ?? CategoryService.findBestCategory(j.title, j.description);
      } else {
        _selectedCategory = CategoryService.findBestCategory(j.title, j.description);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _meetingPointController.dispose();
    _giftDescriptionController.dispose();
    _giftValueController.dispose();
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

    String finalImageUrl = _selectedImageUrl ?? 'https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&q=80&w=800';
    
    // Use category-based image or auto-select category if none selected
    if (_selectedImageUrl == null) {
      if (_selectedCategory == null) {
        // Auto-select category based on title and description
        _selectedCategory = CategoryService.findBestCategory(
          _titleController.text, 
          _descriptionController.text
        );
      }
      _selectedImageUrl = _selectedCategory?.imagePath;
    }
    
    if (_selectedImageUrl != null) {
      finalImageUrl = _selectedImageUrl!;
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
        giftDescription: _selectedCompensationType == CompensationType.withGift
            ? _giftDescriptionController.text
            : null,
        giftEmoji: _selectedCompensationType == CompensationType.withGift
            ? _selectedGiftEmoji
            : null,
        giftValue: _selectedCompensationType == CompensationType.withGift
            ? double.tryParse(_giftValueController.text)
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
        'giftDescription': _selectedCompensationType == CompensationType.withGift
            ? _giftDescriptionController.text
            : null,
        'giftEmoji': _selectedCompensationType == CompensationType.withGift
            ? _selectedGiftEmoji
            : null,
        'giftValue': _selectedCompensationType == CompensationType.withGift
            ? double.tryParse(_giftValueController.text)
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

  void _showCategorySelection() {
    final categories = CategoryService.getAllCategories();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Journey Category'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: AssetImage(category.imagePath),
                  backgroundColor: Colors.grey[200],
                ),
                title: Text(category.name),
                subtitle: Text(category.description),
                onTap: () {
                  setState(() {
                    _selectedCategory = category;
                    _selectedImageUrl = category.imagePath;
                  });
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // TAGS
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Update Journey' : 'Create Journey'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              Colors.grey.withValues(alpha: 0.02),
              Colors.white,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Journey Image Section
              ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.image_outlined, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Journey Image',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        ShadButton.outline(
                            onPressed: _showCategorySelection,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.category, size: 16),
                                const SizedBox(width: 4),
                                const Text('Select Category'),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_selectedImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            Image.asset(
                              _selectedImageUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 200,
                                color: Colors.grey[200],
                                child: const Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: ShadButton(
                                onPressed: _showCategorySelection,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.refresh, size: 16, color: Colors.white),
                                    const SizedBox(width: 4),
                                    const Text('Change Category', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_selectedCategory != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.category, color: AppTheme.accentOrange, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Category: ${_selectedCategory!.name}',
                                style: TextStyle(
                                  color: AppTheme.accentOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'No image yet',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Basic Information Section
              ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Basic Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: _titleController,
                      placeholder: const Text('Give your journey a catchy title...'),
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: _descriptionController,
                      placeholder: const Text('Describe what makes this journey special...'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: _locationController,
                      placeholder: const Text('e.g., 123 Main St, Seattle, WA 98101'),
                    ),
                    const SizedBox(height: 16),
                    ShadInput(
                      controller: _meetingPointController,
                      placeholder: const Text('Where will you meet?'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Schedule Section
              ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ShadButton.outline(
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (d != null) setState(() => _selectedDate = d);
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text('Date: ${_selectedDate.toLocal().toString().split(' ').first}'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ShadButton.outline(
                            onPressed: () async {
                              final t = await showTimePicker(
                                  context: context, initialTime: _startTime);
                              if (t != null) setState(() => _startTime = t);
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text('Start: ${_startTime.format(context)}'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ShadButton.outline(
                            onPressed: () async {
                              final t = await showTimePicker(
                                  context: context, initialTime: _endTime);
                              if (t != null) setState(() => _endTime = t);
                            },
                            child: Row(
                              children: [
                                const Icon(Icons.access_time, size: 16),
                                const SizedBox(width: 8),
                                Text('End: ${_endTime.format(context)}'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Compensation Section
              ShadCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.payments_outlined, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        Text(
                          'Compensation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Simplified Compensation Selection
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Compensation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Two simple radio button options
                        RadioListTile<CompensationType>(
                          title: const Text('Without Remuneration'),
                          subtitle: const Text('No payment - just for the experience'),
                          value: CompensationType.withoutRemuneration,
                          groupValue: _selectedCompensationType,
                          onChanged: (value) => setState(() => _selectedCompensationType = value),
                        ),
                        RadioListTile<CompensationType>(
                          title: const Text('With Gift'),
                          subtitle: const Text('Offer money or a gift as appreciation'),
                          value: CompensationType.withGift,
                          groupValue: _selectedCompensationType,
                          onChanged: (value) => setState(() => _selectedCompensationType = value),
                        ),
                        
                        // Gift details section
                        if (_selectedCompensationType == CompensationType.withGift) ...[
                          const SizedBox(height: 16),
                          ShadInput(
                            controller: _giftDescriptionController,
                            placeholder: const Text('e.g., \$20, Coffee gift card, Free lunch...'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ShadInput(
                                  controller: _giftValueController,
                                  placeholder: const Text('Estimated value (\$)'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButton<String>(
                                  value: _selectedGiftEmoji,
                                  underline: const SizedBox(),
                                  items: const [
                                    DropdownMenuItem(value: '🎁', child: Text('🎁')),
                                    DropdownMenuItem(value: '💰', child: Text('💰')),
                                    DropdownMenuItem(value: '☕', child: Text('☕')),
                                    DropdownMenuItem(value: '🍽️', child: Text('🍽️')),
                                    DropdownMenuItem(value: '🎫', child: Text('🎫')),
                                    DropdownMenuItem(value: '🛍️', child: Text('🛍️')),
                                  ],
                                  onChanged: (value) => setState(() => _selectedGiftEmoji = value!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ShadButton(
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Update Journey' : 'Create Journey'),
                ),
              ),
            ],
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
