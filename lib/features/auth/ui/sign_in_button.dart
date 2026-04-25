import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Floating "Sign in with Google" pill. Visible only when [AuthState] is
/// [AuthSignedOut]; collapses to an empty box otherwise so the surrounding
/// layout stays stable.
class SignInButton extends StatelessWidget {
  const SignInButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) => prev.runtimeType != curr.runtimeType,
      builder: (context, state) {
        switch (state) {
          case AuthSignedOut() || AuthError():
            return _SignInPill(
              onTap: () =>
                  context.read<AuthBloc>().add(const AuthSignInRequested()),
              loading: false,
            );
          case AuthSigningIn():
            return const _SignInPill(loading: true);
          case AuthInitial() || AuthSignedIn():
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _SignInPill extends StatelessWidget {
  const _SignInPill({this.onTap, required this.loading});

  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login, size: 18, color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                loading ? 'Signing in…' : 'Sign in with Google',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
