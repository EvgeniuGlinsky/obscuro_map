import '../domain/entities/auth_user.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthSignedOut extends AuthState {
  const AuthSignedOut();
}

final class AuthSigningIn extends AuthState {
  const AuthSigningIn();
}

final class AuthSignedIn extends AuthState {
  const AuthSignedIn(this.user);
  final AuthUser user;
}

final class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
