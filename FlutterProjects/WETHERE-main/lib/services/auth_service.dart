import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password, String firstName, String lastName) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'createdAt': Timestamp.now(),
          'totalJourneysHosted': 0,
          'totalJourneysCompleted': 0,
          'averageRating': 0.0,
          'totalReviews': 0,
          'notificationsEnabled': true,
          'isVerified': false,
        });
      }

      return credential.user;
    } catch (e) {
      print('Error signing up: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        print('Error during Google signOut: $e');
      }
    }
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, direct Firebase popup sign-in avoids the 'clientID=NULL' error
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        final user = userCredential.user;
        
        if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
          await _createUserDocument(user);
        }
        return user;
      }
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        await _createUserDocument(user);
      }

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }


  // Sign in with Apple
  Future<User?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null && userCredential.additionalUserInfo?.isNewUser == true) {
        String? firstName = appleCredential.givenName;
        String? lastName = appleCredential.familyName;
        await _createUserDocument(user, firstName: firstName, lastName: lastName);
      }

      return user;
    } catch (e) {
      print('Error signing in with Apple: $e');
      rethrow;
    }
  }

  // Helper to create user document
  Future<void> _createUserDocument(User user, {String? firstName, String? lastName}) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'firstName': firstName ?? user.displayName?.split(' ').first ?? '',
      'lastName': lastName ?? (user.displayName != null && user.displayName!.contains(' ') ? user.displayName!.split(' ').last : ''),
      'createdAt': Timestamp.now(),
      'totalJourneysHosted': 0,
      'totalJourneysCompleted': 0,
      'averageRating': 0.0,
      'totalReviews': 0,
      'notificationsEnabled': true,
      'isVerified': false,
    }, SetOptions(merge: true));
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
    } catch (e) {
      print('Error updating profile: $e');
      rethrow;
    }
  }

  // Deactivate account
  Future<void> deactivateAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isActive': false,
        'deactivatedAt': Timestamp.now(),
      });
      await signOut();
    }
  }

  // Delete account
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      // Delete from Firestore first
      await _firestore.collection('users').doc(uid).delete();
      // Delete from Auth
      await user.delete();
    }
  }

  // Request email verification
  Future<void> requestEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Check if email is verified and update Firestore
  Future<void> checkAndUpdateEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      final updatedUser = _auth.currentUser;
      
      if (updatedUser != null && updatedUser.emailVerified) {
        await _firestore.collection('users').doc(updatedUser.uid).update({
          'isVerified': true,
          'verifiedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}

// ============================================================================
// FILE: lib/providers/journey_provider.dart (Using Provider pattern)
// ============================================================================
