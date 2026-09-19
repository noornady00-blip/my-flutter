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
    apiKey: 'AIzaSyDDHGQdBbTwuVPy42Z3yyDuJvGSl67BUto',
    appId: '1:71340241385:web:6c1f63b420641009181b78',
    messagingSenderId: '71340241385',
    projectId: 'mahameek-47a1d',
    authDomain: 'mahameek-47a1d.firebaseapp.com',
    storageBucket: 'mahameek-47a1d.firebasestorage.app',
    measurementId: 'G-SZD6Q3QE8B',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJlaWDcjrUrsghoGkSMoHYhaMfLUgrlSY',
    appId: '1:71340241385:android:d5953a4274451639181b78',
    messagingSenderId: '71340241385',
    projectId: 'mahameek-47a1d',
    storageBucket: 'mahameek-47a1d.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyA-zlnAN_I9ev5V5HgBJximHMFvGTEX7Ts',
    appId: '1:71340241385:ios:2f8dbe309d9bd18d181b78',
    messagingSenderId: '71340241385',
    projectId: 'mahameek-47a1d',
    storageBucket: 'mahameek-47a1d.firebasestorage.app',
    iosBundleId: 'com.mahameek.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyA-zlnAN_I9ev5V5HgBJximHMFvGTEX7Ts',
    appId: '1:71340241385:ios:2f8dbe309d9bd18d181b78',
    messagingSenderId: '71340241385',
    projectId: 'mahameek-47a1d',
    storageBucket: 'mahameek-47a1d.firebasestorage.app',
    iosBundleId: 'com.mahameek.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDDHGQdBbTwuVPy42Z3yyDuJvGSl67BUto',
    appId: '1:71340241385:web:1d337b9bad87e42f181b78',
    messagingSenderId: '71340241385',
    projectId: 'mahameek-47a1d',
    authDomain: 'mahameek-47a1d.firebaseapp.com',
    storageBucket: 'mahameek-47a1d.firebasestorage.app',
    measurementId: 'G-2BZEJKTVHC',
  );
}
