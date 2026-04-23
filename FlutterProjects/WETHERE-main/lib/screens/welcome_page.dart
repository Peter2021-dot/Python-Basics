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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingLg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern Avatar with Card
                Card(
                  elevation: 8,
                  shadowColor: AppTheme.accentOrange.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentOrange.withOpacity(0.1),
                          AppTheme.accentOrange.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      size: 100,
                      color: AppTheme.accentOrange,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),

                // Welcome text with modern typography
                Text(
                  'Welcome!',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: 36,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),

                Text(
                  'Glad you are here',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXxl),

                // Modern Button
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ).copyWith(
                      overlayColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return Colors.white.withOpacity(0.15);
                        }
                        if (states.contains(WidgetState.pressed)) {
                          return Colors.white.withOpacity(0.25);
                        }
                        return null;
                      }),
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.hovered)) {
                          return const Color(0xFFE55A2B);
                        }
                        if (states.contains(WidgetState.disabled)) {
                          return AppTheme.borderColor;
                        }
                        return AppTheme.accentOrange;
                      }),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
