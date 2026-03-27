import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/join_page.dart';
import 'package:wethere/services/auth_service.dart';
import 'package:wethere/screens/password_login.dart';
import 'package:wethere/screens/home_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  Future<void> _handleFederatedSignUp(String provider) async {
    setState(() => _isLoading = true);
    try {
      final user = provider == 'Google' 
          ? await _authService.signInWithGoogle()
          : await _authService.signInWithApple();
      
      if (user != null && mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-up failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-up coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.onSurface, width: 1.5),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface,
              size: 18,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Create an account',
          style: AppTheme.headingM.copyWith(color: Theme.of(context).colorScheme.primary),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spacingMd),

              Text(
                'Choose how you\'d like to sign up',
                style: AppTheme.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // Continue with Google
                ShadButton(
                  onPressed: () => _handleFederatedSignUp('Google'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata, size: 28),
                      const SizedBox(width: 12),
                      const Text('Continue with Google', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Continue with Apple
                if ((!kIsWeb && Platform.isIOS) || kDebugMode)
                  ShadButton.outline(
                    onPressed: () => _handleFederatedSignUp('Apple'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apple, size: 28),
                        const SizedBox(width: 12),
                        const Text('Continue with Apple', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                  ),
                const SizedBox(height: AppTheme.spacingMd),

                // Or Continue with Email
                ShadButton.outline(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const JoinIntroPage()),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email_outlined),
                      const SizedBox(width: 12),
                      const Text('Sign up with Email', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Divider
              Row(
                children: [
                  Expanded(
                    child: Container(height: 1, color: AppTheme.borderColor),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                    ),
                    child: Text('or', style: AppTheme.bodySmall),
                  ),
                  Expanded(
                    child: Container(height: 1, color: AppTheme.borderColor),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Already have an account?
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Already have an account? ",
                    style: AppTheme.bodyRegular,
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordLoginPage(),
                        ),
                      );
                    },
                    style: AppTheme.textButtonStyle,
                    child: Text(
                      'Log in',
                      style: AppTheme.bodyRegular.copyWith(
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingLg),
            ],
          ),
        ),
      ),
    );
  }
}