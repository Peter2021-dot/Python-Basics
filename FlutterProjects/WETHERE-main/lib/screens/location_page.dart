import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/welcome_page.dart';

class LocationPage extends StatefulWidget {
  final String uid;

  const LocationPage({super.key, required this.uid});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _locationController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final location = _locationController.text.trim();
    
    // Validate address format: at least some letters (city) and 5 digits (zip)
    final hasLetters = location.contains(RegExp(r'[a-zA-Z]'));
    final hasZip = location.contains(RegExp(r'\d{5}'));

    if (location.isEmpty || !hasLetters || !hasZip) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid location with city and zip code (e.g., Seattle, WA 98101)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .set({'location': location}, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving location: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Location icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Title
              Text(
                'Where are you located?',
                style: AppTheme.headingL.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),

              // Subtitle
              Text(
                'This helps you find journeys nearby',
                style: AppTheme.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              // Location input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Location',
                    style: AppTheme.labelMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  TextFormField(
                    controller: _locationController,
                    textCapitalization: TextCapitalization.words,
                    decoration: AppTheme.buildInputDecoration(
                      hintText: 'e.g., Seattle, WA 98101',
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),

              const Spacer(flex: 3),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _saveAndContinue,
                  style: AppTheme.primaryButtonStyle,
                  child: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Continue', style: AppTheme.buttonText),
                ),
              ),

              const SizedBox(height: AppTheme.spacingMd),

              // Skip option
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const WelcomePage()),
                    (route) => false,
                  );
                },
                style: AppTheme.textButtonStyle,
                child: Text(
                  'Skip for now',
                  style: AppTheme.bodyRegular.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}
