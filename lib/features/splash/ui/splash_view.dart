import 'package:flutter/material.dart';
import 'package:obscuro_map/core/theme/dark_theme.dart';
import 'package:obscuro_map/gen/assets.gen.dart';

class SplashView extends StatelessWidget {
  const SplashView({super.key, required this.onAnimationEnd});

  final VoidCallback onAnimationEnd;

  static const double _logoWidthFactor = 2 / 8;
  static const double _loaderSizeFactor = 1 / 12;
  static const Duration _animationDuration = Duration(milliseconds: 2500);
  static const double _logoAnimationEnd = 0.6;
  static const double _loaderAnimationStart = 0.7;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final logoWidth = screenWidth * _logoWidthFactor;
    final loaderSize = screenWidth * _loaderSizeFactor;

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

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, (1 - logoAnimation) * 60),
                    child: Opacity(
                      opacity: logoAnimation,
                      child: Assets.features.splash.appLogoPng.image(
                        width: logoWidth,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 98),
                  Opacity(
                    opacity: CurvedAnimation(
                      parent: AlwaysStoppedAnimation(value),
                      curve: const Interval(
                        _loaderAnimationStart,
                        1.0,
                        curve: Curves.linear,
                      ),
                    ).value,
                    child: SizedBox(
                      width: loaderSize,
                      height: loaderSize,
                      child: const CircularProgressIndicator(
                        strokeWidth: 6,
                        strokeAlign: 0,
                        strokeCap: StrokeCap.round,
                        color: DarkTheme.primary,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
