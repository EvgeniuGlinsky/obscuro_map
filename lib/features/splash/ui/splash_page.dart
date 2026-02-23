import 'package:flutter/material.dart';
import 'package:obscuro_map/core/theme/dark_theme.dart';
import 'package:obscuro_map/gen/assets.gen.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DarkTheme.darkThemeBackground,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeInOut,
          builder: (context, value, child) {
            final logoAnimation = CurvedAnimation(
              parent: AlwaysStoppedAnimation(value),
              curve: const Interval(0, 0.6, curve: Curves.fastOutSlowIn),
            ).value;

            return Column(
              mainAxisAlignment: .center,
              children: [
                Transform.translate(
                  offset: Offset(0, (1 - logoAnimation) * 60),
                  child: Opacity(
                    opacity: logoAnimation,
                    child: Assets.features.splash.appLogoPng.image(),
                  ),
                ),

                const SizedBox(height: 98),

                Opacity(
                  opacity: CurvedAnimation(
                    parent: AlwaysStoppedAnimation(value),
                    curve: const Interval(0.7, 1.0, curve: Curves.linear),
                  ).value,
                  child: const CircularProgressIndicator(
                    strokeWidth: 6,
                    strokeAlign: 0,
                    strokeCap: .round,
                    color: DarkTheme.primary,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
