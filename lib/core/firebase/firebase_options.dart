// GENERATED FILE — do not edit by hand.
// Replace by running: flutterfire configure --project=obscuro-map
// ignore_for_file: lines_longer_than_80_chars, avoid_classes_with_only_static_members
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _notConfigured('web');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _notConfigured('android');
      case TargetPlatform.iOS:
        return _notConfigured('ios');
      default:
        return _notConfigured(defaultTargetPlatform.name);
    }
  }

  static FirebaseOptions _notConfigured(String platform) {
        return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDUIgTNd2_p9h0ni7NTxOmaaJUC_hQ_Ivw',
    appId: '1:585519962797:android:6fc160cef01af71a5d8424',
    messagingSenderId: '585519962797',
    projectId: 'obscuro-map-app',
    storageBucket: 'obscuro-map-app.firebasestorage.app',
  );

}