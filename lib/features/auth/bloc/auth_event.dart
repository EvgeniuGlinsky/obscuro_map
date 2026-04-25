import '../domain/entities/auth_user.dart';

sealed class AuthEvent {
  const AuthEvent();
}

/// Subscribes to the auth-state stream. Should be added once at startup.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthSignInRequested extends AuthEvent {
  const AuthSignInRequested();
}

final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

/// Internal event emitted when the underlying auth stream pushes a change.
final class AuthUserChanged extends AuthEvent {
  const AuthUserChanged(this.user);
  final AuthUser? user;
}
