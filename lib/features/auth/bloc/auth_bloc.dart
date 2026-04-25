import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../domain/repositories/i_auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthStarted>(_onStarted);
    on<AuthSignInRequested>(_onSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthUserChanged>(_onUserChanged);
  }

  final IAuthRepository _repository;
  StreamSubscription<void>? _userSub;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final current = _repository.currentUser;
    emit(current != null ? AuthSignedIn(current) : const AuthSignedOut());
    await _userSub?.cancel();
    _userSub = _repository.user.listen((user) => add(AuthUserChanged(user)));
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    emit(user != null ? AuthSignedIn(user) : const AuthSignedOut());
  }

  Future<void> _onSignInRequested(
    AuthSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    if (state is AuthSigningIn) return;
    emit(const AuthSigningIn());
    try {
      final user = await _repository.signInWithGoogle();
      if (user == null) {
        // User cancelled — fall back to signed-out so the button reappears.
        emit(const AuthSignedOut());
      }
      // Success path: authStateChanges will push AuthUserChanged shortly.
    } on Exception catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Google sign-in failed',
      );
      emit(AuthError(e.toString()));
      emit(const AuthSignedOut());
    }
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.signOut();
    } on Exception catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(
        e,
        st,
        reason: 'Sign-out failed',
      );
    }
  }

  @override
  Future<void> close() async {
    await _userSub?.cancel();
    return super.close();
  }
}
