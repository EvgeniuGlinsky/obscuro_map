import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:obscuro_map/core/get_it/get_it.dart';
import 'package:obscuro_map/core/navigation/routes/home_route.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_bloc.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_state.dart';
import 'package:obscuro_map/features/splash/ui/splash_view.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final map = TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      retinaMode: RetinaMode.isHighDensity(context),
      userAgentPackageName: 'com.obscuro.map.app',
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<SplashBloc>(
          create: (context) => getIt<SplashBloc>(),
        ),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<SplashBloc, SplashState>(
            listenWhen: (_, state) => state is SuccessSplashState,
            listener: (_, state) =>
                _onSuccessState(context, state as SuccessSplashState),
          ),
        ],
        child: BlocBuilder<SplashBloc, SplashState>(
          builder: (context, state) {
            return SplashView(map: map);
          },
        ),
      ),
    );
  }

  void _onSuccessState(BuildContext context, SuccessSplashState state) {
    HomeRoute($extra: state.map).replace(context);
  }
}
