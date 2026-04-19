import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:obscuro_map/core/get_it/get_it.dart';
import 'package:obscuro_map/core/navigation/routes/home_route.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_bloc.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_state.dart';
import 'package:obscuro_map/features/splash/ui/splash_view.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SplashBloc>(
          create: (ctx) => getIt<SplashBloc>(),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SplashBloc, SplashState>(
            listenWhen: (prev, state) => state is SuccessSplashState,
            listener: (ctx, state) => const HomeRoute().replace(ctx),
          ),
        ],
        child: const SplashView(),
      ),
    );
  }
}
