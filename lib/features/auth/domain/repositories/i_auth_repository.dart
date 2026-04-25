import '../entities/auth_user.dart';

abstract interface class IAuthRepository {
  /// Emits the current [AuthUser] (or `null` when signed out) and any
  /// subsequent change. Replays the latest value to new subscribers.
  Stream<AuthUser?> get user;

  /// Synchronous accessor for the currently authenticated user, if any.
  AuthUser? get currentUser;

  /// Triggers the Google Sign-In flow and returns the resulting user.
  /// Returns `null` when the user cancels the consent screen.
  /// Throws on transport / configuration errors.
  Future<AuthUser?> signInWithGoogle();

  Future<void> signOut();
}
