import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/utils/image_utils.dart';
import 'home_page.dart';

class CreateProfilePage extends StatefulWidget {
  final String firstName;
  final String lastName;
  final String phone;
  final String bio;
  final String? photoUrl;
  final String? occupation;
  /// If true, navigates back instead of to HomePage after completion
  final bool returnAfterComplete;

  const CreateProfilePage({
    super.key,
    this.firstName = '',
    this.lastName = '',
    this.phone = '',
    this.bio = '',
    this.photoUrl,
    this.occupation,
    this.returnAfterComplete = false,
  });

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _bioController = TextEditingController();

  int _currentStep = 0;
  bool _saving = false;

  Uint8List? _imageBytes;

  // Step 1: About You
  String? _selectedOccupation;
  final _customOccupationController = TextEditingController();
  final List<String> _selectedLanguages = [];

  // Date of Birth
  DateTime? _selectedDob;

  // Step 2: Interests & Preferences
  final List<String> _selectedInterests = [];
  final List<String> _selectedJourneyTypes = [];

  // Step 3: Additional Details
  String? _selectedEthnicity;
  final List<String> _selectedAvailability = [];
  String? _selectedCommunicationStyle;
  final List<String> _selectedTransportation = [];

  // Options
  static const List<String> _occupationOptions = [
    'Student',
    'Professional',
    'Freelancer',
    'Entrepreneur',
    'Retired',
    'Homemaker',
    'Other',
  ];

  static const List<String> _languageOptions = [
    'English',
    'Spanish',
    'French',
    'Mandarin',
    'Hindi',
    'Arabic',
    'Portuguese',
    'Japanese',
    'Korean',
    'German',
    'Italian',
    'Russian',
    'Other',
  ];

  static const List<String> _interestOptions = [
    'Sports',
    'Music',
    'Arts',
    'Food & Dining',
    'Outdoor Activities',
    'Gaming',
    'Reading',
    'Travel',
    'Fitness',
    'Shopping',
    'Photography',
    'Cooking',
    'Movies',
    'Dancing',
    'Yoga',
    'Hiking',
    'Swimming',
    'Cycling',
    'Volunteering',
    'Technology',
    'Fashion',
    'Pets',
    'Gardening',
    'Board Games',
  ];

  static const List<String> _journeyTypeOptions = [
    'Shopping trips',
    'Concerts/Events',
    'Fitness activities',
    'Dining out',
    'Coffee/casual hangouts',
    'Outdoor adventures',
    'Cultural activities',
    'Movie nights',
    'Sports games',
    'Museum visits',
    'Grocery runs',
    'Dog walking',
    'Brunch',
    'Nightlife',
    'Road trips',
    'Study sessions',
    'Walking/Jogging',
    'Art galleries',
  ];

  static const List<String> _ethnicityOptions = [
    'Asian',
    'Black/African American',
    'Hispanic/Latino',
    'Middle Eastern',
    'Native American',
    'Pacific Islander',
    'White/Caucasian',
    'Mixed/Multiracial',
    'Prefer not to say',
  ];

  static const List<String> _availabilityOptions = [
    'Weekday mornings',
    'Weekday afternoons',
    'Weekday evenings',
    'Weekend mornings',
    'Weekend afternoons',
    'Weekend evenings',
    'Flexible',
  ];

  static const List<String> _communicationStyleOptions = [
    'Chatty/Social',
    'Moderate',
    'Quiet/Reserved',
    'Go with the flow',
  ];

  static const List<String> _transportationOptions = [
    'Car owner',
    'Public transit',
    'Bike',
    'Walk',
    'Rideshare',
  ];

  @override
  void initState() {
    super.initState();
    _bioController.text = widget.bio;
    _selectedOccupation = widget.occupation;
    // Note: photoUrl can be used for preview but _imageBytes stays null until a NEW image is picked
    _loadSavedProgress();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _customOccupationController.dispose();
    super.dispose();
  }

  // Load saved progress from SharedPreferences
  Future<void> _loadSavedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('profile_progress');
    if (savedData != null) {
      try {
        final data = jsonDecode(savedData) as Map<String, dynamic>;
        setState(() {
          _bioController.text = data['bio'] ?? '';
          _selectedOccupation = data['occupation'];
          _customOccupationController.text = data['customOccupation'] ?? '';
          _selectedLanguages.addAll(List<String>.from(data['languages'] ?? []));
          if (data['dob'] != null) {
            _selectedDob = DateTime.tryParse(data['dob']);
          }
          _selectedInterests.addAll(List<String>.from(data['interests'] ?? []));
          _selectedJourneyTypes.addAll(List<String>.from(data['journeyTypes'] ?? []));
          _selectedEthnicity = data['ethnicity'];
          _selectedAvailability.addAll(List<String>.from(data['availability'] ?? []));
          _selectedCommunicationStyle = data['communicationStyle'];
          _selectedTransportation.addAll(List<String>.from(data['transportation'] ?? []));
          _currentStep = data['currentStep'] ?? 0;
        });
      } catch (e) {
        debugPrint('Error loading profile progress: $e');
      }
    }
  }

  // Save progress to SharedPreferences
  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'bio': _bioController.text,
      'occupation': _selectedOccupation,
      'customOccupation': _customOccupationController.text,
      'languages': _selectedLanguages,
      'dob': _selectedDob?.toIso8601String(),
      'interests': _selectedInterests,
      'journeyTypes': _selectedJourneyTypes,
      'ethnicity': _selectedEthnicity,
      'availability': _selectedAvailability,
      'communicationStyle': _selectedCommunicationStyle,
      'transportation': _selectedTransportation,
      'currentStep': _currentStep,
    };
    await prefs.setString('profile_progress', jsonEncode(data));
  }

  // IMAGE PICKER
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _imageBytes = await picked.readAsBytes();
      setState(() {});
    }
  }

  // STEP VALIDATION
  bool _validateStep0() => _imageBytes != null;

  bool _validateStep1() =>
      _selectedDob != null &&
      _isAtLeast18(_selectedDob!) &&
      _bioController.text.length >= 37 &&
      _selectedOccupation != null &&
      (_selectedOccupation != 'Other' || _customOccupationController.text.isNotEmpty) &&
      _selectedLanguages.isNotEmpty;

  bool _isAtLeast18(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age >= 18;
  }

  bool _validateStep2() =>
      _selectedInterests.isNotEmpty &&
      _selectedJourneyTypes.length >= 3;

  bool _validateStep3() =>
      _selectedEthnicity != null &&
      _selectedAvailability.isNotEmpty &&
      _selectedCommunicationStyle != null &&
      _selectedTransportation.isNotEmpty;

  String _getValidationError() {
    switch (_currentStep) {
      case 0:
        if (_imageBytes == null) return 'Please add a profile photo';
        break;
      case 1:
        if (_selectedDob == null) return 'Please select your date of birth';
        if (!_isAtLeast18(_selectedDob!)) return 'You must be 18 or older to use this app';
        if (_bioController.text.length < 37) {
          return 'Bio must be at least 37 characters (${_bioController.text.length}/37)';
        }
        if (_selectedOccupation == null) return 'Please select your occupation';
        if (_selectedOccupation == 'Other' && _customOccupationController.text.isEmpty) {
          return 'Please enter your occupation';
        }
        if (_selectedLanguages.isEmpty) return 'Please select at least one language';
        break;
      case 2:
        if (_selectedInterests.isEmpty) return 'Please select at least one interest';
        if (_selectedJourneyTypes.length < 3) {
          return 'Please select at least 3 journey types (${_selectedJourneyTypes.length}/3)';
        }
        break;
      case 3:
        if (_selectedEthnicity == null) return 'Please select your ethnicity';
        if (_selectedAvailability.isEmpty) return 'Please select your availability';
        if (_selectedCommunicationStyle == null) return 'Please select your communication style';
        if (_selectedTransportation.isEmpty) return 'Please select your transportation options';
        break;
    }
    return 'Please complete all required fields';
  }

  void _nextStep() async {
    bool valid = false;

    switch (_currentStep) {
      case 0:
        valid = _validateStep0();
        break;
      case 1:
        valid = _validateStep1();
        break;
      case 2:
        valid = _validateStep2();
        break;
      case 3:
        valid = _validateStep3();
        break;
    }

    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getValidationError()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _saveProgress();

    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _saveProfile();
    }
  }

  void _previousStep() async {
    if (_currentStep > 0) {
      await _saveProgress();
      setState(() => _currentStep--);
    }
  }

  // SAVE PROFILE
  // SAVE PROFILE
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in'), backgroundColor: Colors.red),
      );
      setState(() => _saving = false);
      return;
    }

    try {
      String? imageUrl;

      // 1. Image Upload (Resilient)
      if (_imageBytes != null) {
        try {
          debugPrint('Attempting Firebase Storage upload (compressed)...');
          
          // Compress the profile image
          final compressedBytes = await ImageUtils.compressImage(_imageBytes!, quality: 70, maxWidth: 600);
          
          final ref = FirebaseStorage.instance.ref('users/$uid/profile.jpg');
          await ref.putData(compressedBytes).timeout(const Duration(seconds: 30));
          imageUrl = await ref.getDownloadURL();
          debugPrint('Firebase Storage upload successful');
        } catch (storageError) {
          debugPrint('Firebase Storage upload failed: $storageError');
          // Fallback: Local server
          try {
            debugPrint('Attempting local server fallback...');
            final request = http.MultipartRequest(
              'POST', 
              Uri.parse('http://localhost:5000/upload-profile-image'),
            );
            request.fields['uid'] = uid;
            request.files.add(http.MultipartFile.fromBytes(
              'image', 
              _imageBytes!,
              filename: 'profile.jpg',
            ));
            
            // http.Client with timeout
            final client = http.Client();
            final streamedResponse = await client.send(request).timeout(const Duration(seconds: 5));
            final response = await http.Response.fromStream(streamedResponse);
            
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final rawPath = data['local_path'].toString().replaceAll('\\', '/');
              // Ensure we return a web-accessible URL instead of a folder path
              // Reusing the same server base as the upload request
              imageUrl = 'http://192.168.12.232:5000/$rawPath';
              debugPrint('Saved to local server successfully: $imageUrl');
            }
            client.close();
          } catch (localError) {
            debugPrint('Local server upload failed: $localError');
          }
        }
      }

      // 2. Prepare Profile Data (Resilient)
      final occupation = _selectedOccupation == 'Other' 
          ? _customOccupationController.text.trim() 
          : _selectedOccupation;

      final Map<String, dynamic> profileData = {
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'phone': widget.phone,
        'bio': _bioController.text.trim(),
        'occupation': occupation,
        'languages': _selectedLanguages,
        'interests': _selectedInterests,
        'journeyTypes': _selectedJourneyTypes,
        'ethnicity': _selectedEthnicity,
        'availability': _selectedAvailability,
        'communicationStyle': _selectedCommunicationStyle,
        'transportation': _selectedTransportation,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Handle optional or potentially failing data
      if (_selectedDob != null) {
        profileData['dateOfBirth'] = _selectedDob!.toIso8601String();
      }
      
      profileData['profileComplete'] = true;

      if (imageUrl != null) {
        profileData['photo'] = imageUrl;
      }

      // 3. Firestore Save (Resilient)
      try {
        debugPrint('Saving to Firestore...');
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(profileData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));
        debugPrint('Firestore save successful');
      } catch (firestoreError) {
        debugPrint('Firestore save failed: $firestoreError');
        // Continue anyway as per instructions
      }

      // 4. SharedPreferences (Resilient)
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('profile_complete', true);
        if (_selectedDob != null) {
          await prefs.setString('profile_dob', _selectedDob!.toIso8601String());
        }
        await prefs.remove('profile_progress');
      } catch (prefsError) {
        debugPrint('SharedPreferences update failed: $prefsError');
      }

      // 5. Finalize
      if (!mounted) return;

      // Show safety tips if needed (Non-blocking navigation)
      try {
        final prefs = await SharedPreferences.getInstance();
        final hasSeenSafetyTips = prefs.getBool('hasSeenSafetyTips') ?? false;
        if (!hasSeenSafetyTips) {
          await _showSafetyTipsDialog();
          await prefs.setBool('hasSeenSafetyTips', true);
        }
      } catch (_) {}

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back or to Home
      if (widget.returnAfterComplete) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (_) => false,
        );
      }
    } catch (globalError) {
      debugPrint('Unexpected error in _saveProfile: $globalError');
      // Even on global error, try to finish and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Finished with some errors: $globalError'), backgroundColor: Colors.orange),
        );
        
        // Final attempt to navigate away from spinning state
        if (widget.returnAfterComplete) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const HomePage()),
            (_) => false,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            _currentStep > 0 ? Icons.arrow_back : Icons.close,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: _currentStep > 0
              ? _previousStep
              : () => Navigator.pop(context),
        ),
        title: const Text('Complete Your Profile'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: _buildCurrentStep(),
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final stepTitles = ['Photo', 'About You', 'Interests', 'Details'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Step ${_currentStep + 1} of 4',
                style: AppTheme.bodySmall.copyWith(color: AppTheme.textSecondary),
              ),
              Text(
                stepTitles[_currentStep],
                style: AppTheme.labelMedium.copyWith(color: AppTheme.accentOrange),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / 4,
            backgroundColor: AppTheme.borderColor,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildStep0Photo();
      case 1:
        return _buildStep1AboutYou();
      case 2:
        return _buildStep2Interests();
      case 3:
        return _buildStep3Details();
      default:
        return const SizedBox();
    }
  }

  // STEP 0: Photo
  Widget _buildStep0Photo() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Text(
          'Add Your Photo',
          style: AppTheme.headingL.copyWith(color: AppTheme.primaryDark),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'A profile photo helps others recognize you \nand builds trust in the community.',
          style: AppTheme.bodyLarge.copyWith(color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundColor: AppTheme.dividerColor,
                  backgroundImage: _imageBytes != null ? MemoryImage(_imageBytes!) : null,
                  child: _imageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person, size: 60, color: AppTheme.textHint),
                            const SizedBox(height: 4),
                            Text('Tap to add', style: AppTheme.bodySmall.copyWith(color: AppTheme.textHint)),
                          ],
                        )
                      : null,
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_imageBytes != null)
          TextButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Change Photo'),
            style: AppTheme.textButtonStyle,
          )
        else
          Text(
            'Required *',
            style: AppTheme.bodySmall.copyWith(color: AppTheme.accentOrange),
          ),
      ],
    );
  }

  // STEP 1: About You
  Widget _buildStep1AboutYou() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date of Birth
        _buildSectionTitle('Date of Birth *'),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: _selectedDob ?? DateTime(DateTime.now().year - 20),
              firstDate: DateTime(DateTime.now().year - 100),
              lastDate: DateTime.now(),
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: ColorScheme.light(
                      primary: AppTheme.accentOrange,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) {
              setState(() => _selectedDob = picked);
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd,
              vertical: AppTheme.spacingMd,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _selectedDob != null
                    ? AppTheme.borderColor
                    : AppTheme.borderColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: AppTheme.textHint),
                const SizedBox(width: 12),
                Text(
                  _selectedDob != null
                      ? '${_selectedDob!.month}/${_selectedDob!.day}/${_selectedDob!.year}'
                      : 'Select your date of birth',
                  style: TextStyle(
                    color: _selectedDob != null
                        ? AppTheme.textPrimary
                        : AppTheme.textHint,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_selectedDob != null && !_isAtLeast18(_selectedDob!))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'You must be 18 or older to use this app',
              style: AppTheme.bodySmall.copyWith(color: Colors.red),
            ),
          ),
        const SizedBox(height: 24),

        // Bio
        _buildSectionTitle('About Me *'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _bioController,
          maxLines: 4,
          maxLength: 300,
          decoration: InputDecoration(
            hintText: 'Tell others a bit about yourself and what you enjoy doing...',
            hintStyle: TextStyle(color: AppTheme.textHint),
            filled: true,
            fillColor: AppTheme.dividerColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppTheme.accentOrange, width: 2),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        Text(
          '${_bioController.text.length}/300 (min 37)',
          style: AppTheme.bodySmall.copyWith(
            color: _bioController.text.length >= 37 ? Colors.green : AppTheme.textHint,
          ),
        ),
        const SizedBox(height: 24),

        // Occupation
        _buildSectionTitle('Occupation *'),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedOccupation,
          hint: 'Select your occupation',
          items: _occupationOptions,
          onChanged: (value) => setState(() => _selectedOccupation = value),
        ),
        if (_selectedOccupation == 'Other') ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _customOccupationController,
            decoration: AppTheme.buildInputDecoration(
              hintText: 'Enter your occupation',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 24),

        // Languages
        _buildSectionTitle('Languages Spoken *'),
        const SizedBox(height: 8),
        _buildMultiSelectChips(
          options: _languageOptions,
          selected: _selectedLanguages,
          onChanged: (list) => setState(() {}),
        ),
      ],
    );
  }

  // STEP 2: Interests & Preferences
  Widget _buildStep2Interests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Interests & Hobbies *'),
        Text('Select all that apply', style: AppTheme.bodySmall),
        const SizedBox(height: 12),
        _buildMultiSelectChips(
          options: _interestOptions,
          selected: _selectedInterests,
          onChanged: (list) => setState(() {}),
        ),
        const SizedBox(height: 32),

        _buildSectionTitle('Preferred Journey Types *'),
        Text(
          'Select at least 3 (${_selectedJourneyTypes.length}/3)',
          style: AppTheme.bodySmall.copyWith(
            color: _selectedJourneyTypes.length >= 3 ? Colors.green : AppTheme.textHint,
          ),
        ),
        const SizedBox(height: 12),
        _buildMultiSelectChips(
          options: _journeyTypeOptions,
          selected: _selectedJourneyTypes,
          onChanged: (list) => setState(() {}),
        ),
      ],
    );
  }

  // STEP 3: Additional Details
  Widget _buildStep3Details() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ethnicity
        _buildSectionTitle('Ethnicity *'),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedEthnicity,
          hint: 'Select ethnicity',
          items: _ethnicityOptions,
          onChanged: (value) => setState(() => _selectedEthnicity = value),
        ),
        const SizedBox(height: 24),

        // Availability
        _buildSectionTitle('Availability / Schedule *'),
        Text('When are you usually free?', style: AppTheme.bodySmall),
        const SizedBox(height: 12),
        _buildMultiSelectChips(
          options: _availabilityOptions,
          selected: _selectedAvailability,
          onChanged: (list) => setState(() {}),
        ),
        const SizedBox(height: 24),

        // Communication Style
        _buildSectionTitle('Communication Style *'),
        const SizedBox(height: 8),
        _buildDropdown(
          value: _selectedCommunicationStyle,
          hint: 'How would you describe yourself?',
          items: _communicationStyleOptions,
          onChanged: (value) => setState(() => _selectedCommunicationStyle = value),
        ),
        const SizedBox(height: 24),

        // Transportation
        _buildSectionTitle('Transportation *'),
        Text('How do you usually get around?', style: AppTheme.bodySmall),
        const SizedBox(height: 12),
        _buildMultiSelectChips(
          options: _transportationOptions,
          selected: _selectedTransportation,
          onChanged: (list) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppTheme.labelMedium.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.dividerColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppTheme.textHint)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onChanged,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (bool value) {
            setState(() {
              if (value) {
                selected.add(option);
              } else {
                selected.remove(option);
              }
            });
            onChanged(selected);
          },
          selectedColor: AppTheme.accentOrange.withValues(alpha: 0.2),
          checkmarkColor: AppTheme.accentOrange,
          labelStyle: TextStyle(
            color: isSelected ? AppTheme.accentOrange : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
          backgroundColor: AppTheme.dividerColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? AppTheme.accentOrange : AppTheme.borderColor,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: AppTheme.borderColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text('Back'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentStep > 0 ? 2 : 1,
            child: ElevatedButton(
              onPressed: _saving ? null : _nextStep,
              style: AppTheme.primaryButtonStyle.copyWith(
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(_currentStep < 3 ? 'Next' : 'Complete Profile'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSafetyTipsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        title: Row(
          children: [
            Icon(Icons.favorite, color: AppTheme.accentOrange, size: 28),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Welcome to Togetherness!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Safety Tips',
                style: AppTheme.headingS.copyWith(
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 8),
              _safetyTipItem(Icons.location_on, 'Meet in public places'),
              _safetyTipItem(Icons.people, 'Tell a friend where you\'re going'),
              _safetyTipItem(Icons.psychology, 'Trust your instincts'),
              _safetyTipItem(Icons.flag, 'Report any concerns'),
              const SizedBox(height: 16),
              Text(
                'Community Guidelines',
                style: AppTheme.headingS.copyWith(
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: 8),
              _safetyTipItem(Icons.handshake, 'Be respectful'),
              _safetyTipItem(Icons.block, 'No harassment or inappropriate behavior'),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: AppTheme.primaryButtonStyle,
              child: const Text('I Understand', style: AppTheme.buttonText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _safetyTipItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: AppTheme.bodyRegular),
          ),
        ],
      ),
    );
  }
}

/// Helper function to check if profile is complete
/// Can be called from other files
Future<bool> isProfileComplete() async {
  final prefs = await SharedPreferences.getInstance();
  // First check the simple flag
  if (prefs.getBool('profile_complete') == true) {
    return true;
  }
  // Also check Firestore as a fallback
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid != null) {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data()?['profileComplete'] == true) {
        // Sync the SharedPreferences flag
        await prefs.setBool('profile_complete', true);
        return true;
      }
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
    }
  }
  return false;
}
