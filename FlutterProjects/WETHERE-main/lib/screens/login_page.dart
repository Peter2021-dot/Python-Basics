import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/password_login.dart';
import 'package:wethere/screens/home_page.dart';
import 'package:wethere/screens/create_account.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkForEmailLink();
  }

  Future<void> _checkForEmailLink() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString('emailForSignIn');
      if (savedEmail != null) {
        // Email link sign-in handling preserved for deep links
      }
    } catch (e) {
      debugPrint('Error checking email link: $e');
    }
  }

  // ignore: unused_element
  Future<void> _signInWithEmailLink(String email, String emailLink) async {
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailLink(email: email, emailLink: emailLink);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emailForSignIn');
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign-in failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingLg,
                ),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Hero image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: Image.asset(
                        'assets/images/welcome_hero.png',
                        width: 280,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingXl),

                    // App name
                    Text(
                      'Togetherness',
                      style: AppTheme.headlineXL.copyWith(
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingSm),

                    // Tagline
                    Text(
                      'Ready to travel together?',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(flex: 2),

                    // Create an account button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAccountPage(),
                            ),
                          );
                        },
                        style: AppTheme.primaryButtonStyle,
                        child: const Text(
                          'Create an account',
                          style: AppTheme.buttonText,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    // Log in button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PasswordLoginPage(),
                            ),
                          );
                        },
                        style: AppTheme.secondaryButtonStyle,
                        child: const Text(
                          'Log in',
                          style: AppTheme.buttonText,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),

                    const Spacer(flex: 1),

                    // Footer
                    Text(
                      'by WeThere',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textHint,
                        letterSpacing: 1,
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