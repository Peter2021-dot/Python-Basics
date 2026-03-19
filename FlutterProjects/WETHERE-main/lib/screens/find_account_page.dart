import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wethere/theme/app_theme.dart';
import 'package:wethere/screens/welcome_page.dart';
import 'verify_code_page.dart';

class FindAccountPage extends StatefulWidget {
  const FindAccountPage({super.key});

  @override
  State<FindAccountPage> createState() => _FindAccountPageState();
}

class _FindAccountPageState extends State<FindAccountPage> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
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
              Text('Find your account', style: AppTheme.headingL),
              const SizedBox(height: AppTheme.spacingMd),

              // Description
              Text(
                "We'll help you find your account. Please enter your phone number, username, or email associated with your account.",
                style: AppTheme.bodyLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXxl),

              // Input Field
              TextField(
                controller: _controller,
                decoration: AppTheme.buildInputDecoration(
                  hintText: 'Phone, username, or email',
                  prefixIcon: const Icon(Icons.search_outlined),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final input = _controller.text.trim();
                          if (input.isEmpty) return;

                          setState(() {
                            _isLoading = true;
                          });

                          // Capture navigator & messenger to avoid using `context` after awaits
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          try {
                            // Try to find user by phone, email, then username
                            final users = FirebaseFirestore.instance.collection('users');

                            QuerySnapshot<Map<String, dynamic>> snapshot;

                            // First assume phone number (starts with + or digit)
                            snapshot = await users.where('phone', isEqualTo: input).limit(1).get();

                            Map<String, dynamic>? userData;

                            if (snapshot.docs.isNotEmpty) {
                              userData = snapshot.docs.first.data();
                            } else {
                              // Try email
                              snapshot = await users.where('email', isEqualTo: input).limit(1).get();
                              if (snapshot.docs.isNotEmpty) {
                                userData = snapshot.docs.first.data();
                              } else {
                                // Try username
                                snapshot = await users.where('username', isEqualTo: input).limit(1).get();
                                if (snapshot.docs.isNotEmpty) {
                                  userData = snapshot.docs.first.data();
                                }
                              }
                            }

                            if (userData == null) {
                              // If not found in Firestore, and input looks like an email,
                              // check Firebase Auth for existing accounts.
                              if (input.contains('@')) {
                                // Show confirmation dialog and send sign-in link if user agrees.
                                final email = input;
                                final shouldSend = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Account lookup'),
                                    content: Text('Send a sign-in link to $email?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(context).pop(true),
                                        child: const Text('Send link'),
                                      ),
                                    ],
                                  ),
                                );

                                if (shouldSend == true) {
                                  if (!mounted) return;
                                  try {
                                    ActionCodeSettings acs = ActionCodeSettings(
                                      url: 'https://wethere-fed83.firebaseapp.com',
                                      handleCodeInApp: true,
                                      androidPackageName: 'com.example.wethere',
                                      androidInstallApp: true,
                                      androidMinimumVersion: '1',
                                      iOSBundleId: 'com.example.wethere',
                                    );

                                    await FirebaseAuth.instance.sendPasswordResetEmail(
                                      email: email,
                                      actionCodeSettings: acs,
                                    );

                                        if (!mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(content: Text('Sign-in link sent to $email')),
                                        );
                                  } catch (e) {
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(content: Text('Error sending sign-in link: $e')),
                                    );
                                  }
                                }

                                return;
                              }

                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('No account found for that entry.')),
                              );
                              return;
                            }

                            final phone = (userData['phone'] as String?)?.trim();
                            final email = (userData['email'] as String?)?.trim();

                            if (phone != null && phone.isNotEmpty) {
                              // Start phone verification
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: phone,
                                timeout: const Duration(seconds: 60),
                                verificationCompleted: (PhoneAuthCredential credential) async {
                                  // Auto-retrieval or instant verification
                                  await FirebaseAuth.instance.signInWithCredential(credential);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Phone number automatically verified and user signed in.')),
                                  );
                                  navigator.pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (context) => const WelcomePage()),
                                    (route) => false,
                                  );
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  if (!mounted) return;
                                  messenger.showSnackBar(
                                    SnackBar(content: Text('Phone verification failed: ${e.message}')),
                                  );
                                },
                                codeSent: (String verificationId, int? resendToken) async {
                                  if (!mounted) return;
                                  navigator.push(
                                    MaterialPageRoute(
                                      builder: (context) => VerifyCodePage(verificationId: verificationId),
                                    ),
                                  );
                                },
                                codeAutoRetrievalTimeout: (String verificationId) {
                                  // Timeout reached
                                },
                              );
                            } else if (email != null && email.isNotEmpty) {
                              // Send a sign-in link to email (similar to LoginPage)
                              try {
                                ActionCodeSettings acs = ActionCodeSettings(
                                  url: 'https://wethere-fed83.firebaseapp.com',
                                  handleCodeInApp: true,
                                  androidPackageName: 'com.example.wethere',
                                  androidInstallApp: true,
                                  androidMinimumVersion: '1',
                                  iOSBundleId: 'com.example.wethere',
                                );

                                await FirebaseAuth.instance.sendPasswordResetEmail(
                                  email: email,
                                  actionCodeSettings: acs,
                                );

                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Sign-in link sent to $email')),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error sending sign-in link: $e')),
                                );
                              }
                            } else {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('No phone or email available for this account.')),
                              );
                            }
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                            }
                          }
                        },
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Continue', style: AppTheme.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
