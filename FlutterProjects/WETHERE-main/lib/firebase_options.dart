// File: firebase_options.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase configuration for all platforms
/// Supports: Web, Android, iOS, macOS, Windows
///
/// To add Firebase products (Firestore, Storage, Auth, etc):
/// 1. Visit: https://firebase.google.com/docs/web/setup#available-libraries
/// 2. Add required imports at the top of main.dart:
///    - Firestore: import 'package:cloud_firestore/cloud_firestore.dart';
///    - Storage: import 'package:firebase_storage/firebase_storage.dart';
///    - Auth: import 'package:firebase_auth/firebase_auth.dart';
///    - Real-time Database: import 'package:firebase_database/firebase_database.dart';
/// 3. Initialize instances in your app
///
/// Current configuration includes: Authentication, Firestore, Storage
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux is not supported yet.');
      default:
        throw UnsupportedError('Unknown platform: $defaultTargetPlatform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyDisiFJh75qT6sJnonjJquVSjMbuTtGjQU",
    appId: "1:370087424389:web:577d4940077e98c79594ec",
    messagingSenderId: "370087424389",
    projectId: "wethere-fed83",
    authDomain: "wethere-fed83.firebaseapp.com",
    storageBucket: "wethere-fed83.firebasestorage.app",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyDlrDmP3z53ZEtpdUCb8bkt1y5fyuOTFbE",
    appId: "1:370087424389:android:b04612051cea039c9594ec",
    messagingSenderId: "370087424389",
    projectId: "wethere-fed83",
    storageBucket: "wethere-fed83.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "YOUR_IOS_API_KEY",
    appId: "YOUR_IOS_APP_ID",
    messagingSenderId: "YOUR_SENDER_ID",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    iosBundleId: "com.example.yourapp",
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "YOUR_MACOS_API_KEY",
    appId: "YOUR_MACOS_APP_ID",
    messagingSenderId: "YOUR_SENDER_ID",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    iosBundleId: "com.example.yourapp",
  );

  // Windows options
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: "AIzaSyDisiFJh75qT6sJnonjJquVSjMbuTtGjQU",
    appId: "1:370087424389:web:e4b6ea54b8b01dc59594ec",
    messagingSenderId: "370087424389",
    projectId: "wethere-fed83",
    storageBucket: "wethere-fed83.firebasestorage.app",
  );
}
