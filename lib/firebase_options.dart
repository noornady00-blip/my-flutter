// File generated based on Firebase project: mahameek
// Project ID: mahameek
// App ID (Web): 1:569582253022:web:81eebd33088b7557b2634f

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
    apiKey: 'AIzaSyCiT_J4qrT0eLDkL8_oWVoUCuuBJU7FYpE',
    appId: '1:527214852381:web:a1bef1aa11775e549349f4',
    messagingSenderId: '527214852381',
    projectId: 'mahameek-30c70',
    authDomain: 'mahameek-30c70.firebaseapp.com',
    storageBucket: 'mahameek-30c70.firebasestorage.app',
    measurementId: 'G-HKF1ZBMN9P',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyADXC4ls6GxJaXqGSyosY4_tw57Xe1unZM',
    appId: '1:527214852381:android:2f8f96da08e27aac9349f4',
    messagingSenderId: '527214852381',
    projectId: 'mahameek-30c70',
    storageBucket: 'mahameek-30c70.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBndL3wGpz9GC6W97u0QnndKptsLFQbBKs',
    appId: '1:527214852381:ios:07017c37b7d26e079349f4',
    messagingSenderId: '527214852381',
    projectId: 'mahameek-30c70',
    storageBucket: 'mahameek-30c70.firebasestorage.app',
    iosBundleId: 'com.mahameek.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyBndL3wGpz9GC6W97u0QnndKptsLFQbBKs',
    appId: '1:527214852381:ios:07017c37b7d26e079349f4',
    messagingSenderId: '527214852381',
    projectId: 'mahameek-30c70',
    storageBucket: 'mahameek-30c70.firebasestorage.app',
    iosBundleId: 'com.mahameek.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCiT_J4qrT0eLDkL8_oWVoUCuuBJU7FYpE',
    appId: '1:527214852381:web:869bec887b1039c09349f4',
    messagingSenderId: '527214852381',
    projectId: 'mahameek-30c70',
    authDomain: 'mahameek-30c70.firebaseapp.com',
    storageBucket: 'mahameek-30c70.firebasestorage.app',
    measurementId: 'G-8WGB5K0JGY',
  );
}
