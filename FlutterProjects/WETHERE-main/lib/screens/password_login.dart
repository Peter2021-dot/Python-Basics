import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:wethere/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/find_account_page.dart';
import 'package:wethere/screens/home_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PasswordLoginPage extends StatefulWidget {
  const PasswordLoginPage({super.key});

  @override
  State<PasswordLoginPage> createState() => _PasswordLoginPageState();
}

class _PasswordLoginPageState extends State<PasswordLoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _obscurePassword = true;
  bool loading = false;

  Future<void> _handleFederatedSignIn(String provider) async {
    setState(() => loading = true);
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
          SnackBar(content: Text('Sign-in failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loginUser() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      // 🔥 Firebase login
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged in successfully!")),
      );

      // Navigate to home screen
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Login failed";

      if (e.code == 'user-not-found') {
        message = "No user found with this email";
      } else if (e.code == 'wrong-password') {
        message = "Incorrect password";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format";
      } else {
        message = e.message ?? "Something went wrong";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showComingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$provider sign-in coming soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.accentOrange.withOpacity(0.08),
              AppTheme.primaryDark.withOpacity(0.05),
              Colors.white,
              AppTheme.accentOrange.withOpacity(0.06),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width > 600 ? AppTheme.spacingXl * 2 : AppTheme.spacingLg,
              vertical: AppTheme.spacingLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back button
                IconButton(
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
                const SizedBox(height: AppTheme.spacingXl),

                // Title with ShadCN typography
                Text(
                  'Welcome Back',
                  style: ShadTheme.of(context).textTheme.h1.copyWith(
                    color: AppTheme.accentOrange,
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width > 600 ? 48 : 36,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingSm),

                Text(
                  'Enter your credentials to access your account',
                  style: ShadTheme.of(context).textTheme.muted.copyWith(
                    fontSize: MediaQuery.of(context).size.width > 600 ? 18 : 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingXl),

                // Email input in ShadCard
                ShadCard(
                  child: TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'Email',
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),

                // Password input in ShadCard
                ShadCard(
                  child: TextField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppTheme.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                  ),
                ),
              const SizedBox(height: AppTheme.spacingSm),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FindAccountPage(),
                      ),
                    );
                  },
                  style: AppTheme.textButtonStyle,
                  child: Text(
                    'Forgot password?',
                    style: AppTheme.bodyRegular.copyWith(
                      color: AppTheme.accentOrange,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

              // Login button
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(8),
                ),
                width: double.infinity,
                child: ShadButton(
                  onPressed: loading ? null : loginUser,
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Log in', style: TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(height: AppTheme.spacingLg),

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

              // Google Sign-In Button
              SizedBox(
                width: double.infinity,
                child: ShadButton.outline(
                  onPressed: () => _handleFederatedSignIn('Google'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata, size: 28),
                      const SizedBox(width: 12),
                      const Text('Continue with Google', style: TextStyle(fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Apple Sign-In Button
              if ((!kIsWeb && Platform.isIOS) || kDebugMode)
                SizedBox(
                  width: double.infinity,
                  child: ShadButton.outline(
                    onPressed: () => _handleFederatedSignIn('Apple'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.apple, size: 28),
                        const SizedBox(width: 12),
                        const Text('Continue with Apple', style: TextStyle(fontSize: 16)),
                      ],
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

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
