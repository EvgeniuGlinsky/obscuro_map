import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import '../domain/entities/auth_user.dart';
import '../domain/repositories/i_auth_repository.dart';

@Singleton(as: IAuthRepository)
class FirebaseAuthRepository implements IAuthRepository {
  FirebaseAuthRepository();

  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<AuthUser?> get user => _auth.authStateChanges().map(_mapUser);

  @override
  AuthUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Future<AuthUser?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = fb.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return _mapUser(result.user);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  AuthUser? _mapUser(fb.User? u) {
    if (u == null) return null;
    return AuthUser(
      uid: u.uid,
      email: u.email,
      displayName: u.displayName,
      photoUrl: u.photoURL,
    );
  }
}
