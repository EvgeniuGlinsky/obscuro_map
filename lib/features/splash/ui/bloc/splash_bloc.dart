import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_event.dart';
import 'package:obscuro_map/features/splash/ui/bloc/splash_state.dart';

@injectable
class SplashBloc extends Bloc<SplashEvent, SplashState> {
  SplashBloc() : super(InitialSplashState()) {
    on<OnMapLoadedSplashEvent>(_onMapLoaded);
  }

  Future<void> _onMapLoaded(
    OnMapLoadedSplashEvent event,
    Emitter<SplashState> emit,
  ) async {
    await Future<void>.delayed(const Duration(seconds: 5));

    emit(SuccessSplashState(map: event.map));
  }
}
