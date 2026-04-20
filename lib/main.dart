import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:obscuro_map/core/navigation/app_router.dart';
import 'package:obscuro_map/core/theme/dark_theme.dart';
import 'package:obscuro_map/core/theme/light_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/get_it/get_it.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  // SharedPreferences is async; register it manually so injectable can inject
  // it into ProgressRepository without requiring an async module.
  getIt.registerSingleton<SharedPreferences>(
    await SharedPreferences.getInstance(),
  );
  configureDependencies();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: ThemeData(
        colorScheme: const ColorScheme(
          brightness: Brightness.dark,
          primary: LightTheme.lightThemeBackground,
          onPrimary: Colors.red,
          secondary: Colors.green,
          onSecondary: Colors.yellow,
          error: Colors.pink,
          onError: Colors.blue,
          surface: DarkTheme.darkThemeBackground,
          onSurface: Colors.deepPurple,
        ),
      ),
    );
  }
}
