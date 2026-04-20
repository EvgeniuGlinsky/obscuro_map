import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/get_it/get_it.dart';
import '../bloc/location_bloc.dart';
import '../bloc/location_event.dart';
import 'home_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<LocationBloc>()..add(const LocationStarted()),
      child: const HomeView(),
    );
  }
}