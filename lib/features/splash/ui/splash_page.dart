import 'package:flutter/material.dart';
import 'package:obscuro_map/gen/assets.gen.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Assets.features.splash.appLogoPng.image(),
      ),
    );
  }
}
