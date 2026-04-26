import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/get_it.dart';
import 'core/firebase/firebase_options.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/dark_theme.dart';
import 'features/home/data/progress_migration.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kReleaseMode) {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  await configureDependencies();

  // One-shot v1 → v2 schema migration. No-ops once the legacy keys are
  // gone, so it's safe to run on every launch.
  await getIt<ProgressMigration>().migrateLocalIfNeeded(
    getIt<SharedPreferences>(),
  );

  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: DarkTheme.primary,
          surface: DarkTheme.darkThemeBackground,
        ),
      ),
    );
  }
}
