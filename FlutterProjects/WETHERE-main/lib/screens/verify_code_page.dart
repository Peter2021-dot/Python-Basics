import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/welcome_page.dart';

class VerifyCodePage extends StatefulWidget {
  final String? verificationId;

  const VerifyCodePage({super.key, this.verificationId});

  @override
  State<VerifyCodePage> createState() => _VerifyCodePageState();
}

class _VerifyCodePageState extends State<VerifyCodePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppTheme.spacingLg),

              // Title
              Text('Verify your account', style: AppTheme.headingL),
              const SizedBox(height: AppTheme.spacingMd),

              // Description
              Text(
                "Enter the code we just sent you below.",
                style: AppTheme.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              // Code Input Field
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: AppTheme.buildInputDecoration(
                  hintText: '000000',
                  prefixIcon: const Icon(Icons.security_outlined),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              // Verify Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final code = _codeController.text.trim();
                    if (code.isEmpty) return;

                    final vid = widget.verificationId;
                    if (vid == null || vid.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No verification ID available.')),
                      );
                      return;
                    }

                    try {
                      final credential = PhoneAuthProvider.credential(
                        verificationId: vid,
                        smsCode: code,
                      );

                      await FirebaseAuth.instance.signInWithCredential(credential);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phone verification successful!'),
                          backgroundColor: AppTheme.primaryDark,
                        ),
                      );

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const WelcomePage()),
                        (route) => false,
                      );
                    } on FirebaseAuthException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Verification failed: ${e.message}')),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  },
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Verify', style: AppTheme.buttonText),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),

              // Resend Code Option
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Code resent!')),
                    );
                  },
                  child: Text(
                    "Didn't receive the code? Resend",
                    style: AppTheme.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
