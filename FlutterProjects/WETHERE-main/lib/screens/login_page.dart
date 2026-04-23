import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/password_login.dart';
import 'package:wethere/screens/home_page.dart';
import 'package:wethere/screens/create_account.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? AppTheme.spacingXl * 2 : AppTheme.spacingLg,
              vertical: AppTheme.spacingLg,
            ),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Playful floating images
                Stack(
                  children: [
                    // Background circles
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/welcome_hero.png',
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 20,
                      right: 15,
                      child: Container(
                        width: 45,
                        height: 45,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withValues(alpha: 0.1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/welcome_hero.png',
                            width: 41,
                            height: 41,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 15,
                      left: 20,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.withValues(alpha: 0.1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/welcome_hero.png',
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 25,
                      right: 15,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.purple.withValues(alpha: 0.1),
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/welcome_hero.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    // Central hero card
                    Center(
                      child: ShadCard(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          child: Image.asset(
                            'assets/images/welcome_hero.png',
                            width: MediaQuery.of(context).size.width > 600 ? 180 : 140,
                            height: MediaQuery.of(context).size.width > 600 ? 130 : 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingXl),

                // App name with shadcn typography
                Text(
                  'Togetherness',
                  style: ShadTheme.of(context).textTheme.h1.copyWith(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width > 600 ? 48 : 36,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),

                // Tagline with shadcn typography
                Text(
                  'Ready to travel together?',
                  style: ShadTheme.of(context).textTheme.muted.copyWith(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 20 : 18,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(flex: 2),

                // Modern Shadcn Create Account Button
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CreateAccountPage(),
                        ),
                      );
                    },
                    child: const Text('Create Account', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Modern Shadcn Login Button with orange background
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  width: double.infinity,
                  child: ShadButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordLoginPage(),
                        ),
                      );
                    },
                    child: const Text('Log in', style: TextStyle(color: Colors.white)),
                  ),
                ),

                const Spacer(flex: 1),

                // Footer
                Text(
                  'by WeThere',
                  style: ShadTheme.of(context).textTheme.muted.copyWith(
                    color: AppTheme.textHint,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}