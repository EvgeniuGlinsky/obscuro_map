import 'package:flutter/material.dart';
import 'package:obscuro_map/core/theme/dark_theme.dart';
import 'package:obscuro_map/gen/assets.gen.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key, required this.onAnimationEnd});

  final VoidCallback onAnimationEnd;

  static const Duration _animationDuration = Duration(seconds: 2);
  static const double _logoAnimationEnd = 0.6;

  @override
  Widget build(BuildContext context) {
    final logoWidth = MediaQuery.of(context).size.width + 100;

    return SizedBox.expand(
      child: ColoredBox(
        color: DarkTheme.darkThemeBackground,
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: _animationDuration,
            curve: Curves.easeInOut,
            onEnd: onAnimationEnd,
            builder: (context, value, child) {
              final logoAnimation = CurvedAnimation(
                parent: AlwaysStoppedAnimation(value),
                curve: const Interval(
                  0,
                  _logoAnimationEnd,
                  curve: Curves.fastOutSlowIn,
                ),
              ).value;

              return Transform.translate(
                offset: Offset(0, (1 - logoAnimation) * 60),
                child: Opacity(
                  opacity: logoAnimation,
                  child: Assets.features.splash.appLogoPng.image(
                    width: logoWidth,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
