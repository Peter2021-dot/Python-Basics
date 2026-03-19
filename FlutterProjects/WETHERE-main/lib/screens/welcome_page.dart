import 'package:flutter/material.dart';
import 'package:wethere/theme/app_theme.dart';
import 'home_page.dart';

class WelcomePage extends StatelessWidget {
  final String? firstName;
  final String? lastName;
  final String? phone;

  const WelcomePage({
    super.key,
    this.firstName,
    this.lastName,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with shadow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentOrange.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 100,
                  color: AppTheme.accentOrange,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Welcome text
              Text('Welcome!', style: AppTheme.headlineXL),
              const SizedBox(height: AppTheme.spacingSm),

              Text(
                'Glad you are here',
                style: AppTheme.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              // Get Started Button - Now goes directly to Feed
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(),
                      ),
                      (route) => false,
                    );
                  },
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Get Started', style: AppTheme.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
