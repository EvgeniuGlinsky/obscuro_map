import 'package:flutter/material.dart';
import 'package:obscuro_map/core/navigation/app_router.dart';
import 'package:obscuro_map/core/theme/dark_theme.dart';
import 'package:obscuro_map/core/theme/light_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
