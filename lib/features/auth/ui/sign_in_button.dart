import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/design_tokens.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

/// Floating "Войти через Google" pill, exactly as specified in the
/// design handoff (`new_design/README.md`). Visible only when [AuthState]
/// is [AuthSignedOut] / [AuthError]; collapses to an empty box otherwise.
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : onTap,
      child: Container(
        padding: kSignInPillPadding,
        decoration: BoxDecoration(
          color: kSignInPillBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: kSignInPillBorder),
          boxShadow: kSignInPillShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const _GoogleGlyph(size: 18),
            const SizedBox(width: 10),
            Text(
              loading ? 'Входим…' : 'Войти через Google',
              style: const TextStyle(
                color: kColorTextDark,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  // The four-colour Google "G" mark, taken verbatim from the
  // `GooglePill` SVG in the design hand-off (`new_design/Obscuro Map
  // Design.html`). Inlined as a string so the asset is in-source — no
  // extra runtime asset loading on every sign-in screen build.
  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 18 18">'
      '<path d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 01-1.796 2.716v2.259h2.908c1.702-1.567 2.684-3.875 2.684-6.615z" fill="#4285F4"/>'
      '<path d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 009 18z" fill="#34A853"/>'
      '<path d="M3.964 10.71A5.41 5.41 0 013.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 000 9c0 1.452.348 2.827.957 4.042l3.007-2.332z" fill="#FBBC05"/>'
      '<path d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 00.957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z" fill="#EA4335"/>'
      '</svg>';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _svg,
      width: size,
      height: size,
    );
  }
}
