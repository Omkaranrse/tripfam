// File generated for project tripfam-8cb27.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBEYZCQzXtsChm26rtrH2iYKGQqxGHEU',
    appId: '1:727248616608:web:c55394d157dcec085d1dc5',
    messagingSenderId: '727248616608',
    projectId: 'tripfam-8cb27',
    authDomain: 'tripfam-8cb27.firebaseapp.com',
    storageBucket: 'tripfam-8cb27.firebasestorage.app',
    measurementId: 'G-M0FJTBZDJV',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAa2lhC64Ku-b4OltxFtiYt0OAf511zWRk',
    appId: '1:727248616608:android:45542ae4b60a0b4c5d1dc5',
    messagingSenderId: '727248616608',
    projectId: 'tripfam-8cb27',
    storageBucket: 'tripfam-8cb27.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA1JclD6MsGh4XmqYXkD50QLVIlo6vmB2I',
    appId: '1:727248616608:ios:bb5180768e5454855d1dc5',
    messagingSenderId: '727248616608',
    projectId: 'tripfam-8cb27',
    storageBucket: 'tripfam-8cb27.firebasestorage.app',
    iosBundleId: 'com.omkar.tripfam',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA1JclD6MsGh4XmqYXkD50QLVIlo6vmB2I',
    appId: '1:727248616608:ios:bb5180768e5454855d1dc5',
    messagingSenderId: '727248616608',
    projectId: 'tripfam-8cb27',
    storageBucket: 'tripfam-8cb27.firebasestorage.app',
    iosBundleId: 'com.omkar.tripfam',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBEYZCQzXtsChm26rtrH2iYKGQqxGHEU',
    appId: '1:727248616608:web:c55394d157dcec085d1dc5',
    messagingSenderId: '727248616608',
    projectId: 'tripfam-8cb27',
    authDomain: 'tripfam-8cb27.firebaseapp.com',
    storageBucket: 'tripfam-8cb27.firebasestorage.app',
    measurementId: 'G-M0FJTBZDJV',
  );
}
