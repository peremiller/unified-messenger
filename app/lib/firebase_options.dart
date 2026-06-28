// PLACEHOLDER — regenerate with: flutterfire configure
//
// This file ships with non-functional placeholder values so the project
// compiles before you've created a Firebase project. Running
// `flutterfire configure` (after `dart pub global activate flutterfire_cli`)
// overwrites it with real values for your project. Until then, PushService
// initialization fails gracefully and the app runs without push.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _placeholder;
      case TargetPlatform.iOS:
        return _placeholder;
      default:
        throw UnsupportedError(
            'No Firebase options for $defaultTargetPlatform. '
            'Run `flutterfire configure`.');
    }
  }

  // Obviously-fake values; replaced by flutterfire configure.
  static const FirebaseOptions _placeholder = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
  );

  // Web needs authDomain in addition; still placeholder until flutterfire configure.
  static const FirebaseOptions _web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'REPLACE_ME',
    authDomain: 'REPLACE_ME.firebaseapp.com',
  );
}
