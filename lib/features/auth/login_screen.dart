import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

export 'login_screen.dart' show RegisterScreen;

// ── Helpers ────────────────────────────────────────────────────────────────

/// Extracts the `error.code` field from a Dio 4xx/5xx response body.
String? _apiErrorCode(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map) return err['code'] as String?;
    }
  }
  return null;
}

// ── Login ──────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  String _loadingPhase = 'Signing in…';

  // Set when the server tells us the email is not yet verified.
  String? _unverifiedEmail;
  bool _resendLoading = false;
  bool _resendSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _loadingPhase = 'Signing in…';
      _error = null;
      _unverifiedEmail = null;
      _resendSent = false;
    });

    try {
      final api = ref.read(apiClientProvider);
      final tokens =
          await api.login(_emailCtrl.text.trim(), _passwordCtrl.text);

      setState(() => _loadingPhase = 'Setting up encryption…');
      final key = await EncryptionService.deriveKeyAsync(
          _passwordCtrl.text, tokens.userId);

      await ref.read(secureStorageProvider).saveSession(
            accessToken: tokens.accessToken,
            refreshToken: tokens.refreshToken,
            userId: tokens.userId,
            encryptionKey: EncryptionService.keyToBase64(key),
          );

      ref.read(encryptionKeyProvider.notifier).state = key;
    } catch (e) {
      if (!mounted) return;
      if (_apiErrorCode(e) == 'EMAIL_NOT_VERIFIED') {
        setState(() => _unverifiedEmail = _emailCtrl.text.trim());
      } else {
        setState(() => _error = _parseLoginError(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_unverifiedEmail == null) return;
    setState(() {
      _resendLoading = true;
      _resendSent = false;
    });
    try {
      await ref.read(apiClientProvider).resendVerification(_unverifiedEmail!);
      if (mounted) setState(() => _resendSent = true);
    } catch (_) {
      // resend failures are non-critical — silently ignore
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  String _parseLoginError(Object e) {
    debugPrint('[Login] error: $e');
    final msg = e.toString().toLowerCase();
    if (msg.contains('401') ||
        msg.contains('invalid credentials') ||
        msg.contains('invalid email or password')) {
      return 'Invalid email or password';
    }
    if (msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('refused')) {
      return 'Cannot reach server — check your connection';
    }
    return 'Sign-in failed — please try again';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SnapLogo(),
                const SizedBox(height: 32),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to your clipboard vault',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                if (_unverifiedEmail != null) ...[
                  _VerifyEmailBanner(
                    email: _unverifiedEmail!,
                    resendLoading: _resendLoading,
                    resendSent: _resendSent,
                    onResend: _resendVerification,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            const SizedBox(width: 10),
                            Text(_loadingPhase),
                          ],
                        )
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text("Don't have an account? Create one"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Register ───────────────────────────────────────────────────────────────

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  // Non-null after a successful registration — switches to the verify screen.
  String? _registeredEmail;
  bool _resendLoading = false;
  bool _resendSent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(apiClientProvider)
          .register(_emailCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        setState(() => _registeredEmail = _emailCtrl.text.trim());
      }
    } catch (e) {
      if (mounted) setState(() => _error = _parseRegisterError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendVerification() async {
    if (_registeredEmail == null) return;
    setState(() {
      _resendLoading = true;
      _resendSent = false;
    });
    try {
      await ref
          .read(apiClientProvider)
          .resendVerification(_registeredEmail!);
      if (mounted) setState(() => _resendSent = true);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  String _parseRegisterError(Object e) {
    debugPrint('[Register] error: $e');
    final msg = e.toString().toLowerCase();
    if (msg.contains('409') || msg.contains('already')) {
      return 'An account with this email already exists';
    }
    if (msg.contains('connection') ||
        msg.contains('socket') ||
        msg.contains('network') ||
        msg.contains('refused')) {
      return 'Cannot reach server — check your connection';
    }
    return 'Registration failed — please try again';
  }

  @override
  Widget build(BuildContext context) {
    // After successful registration, swap to the verify screen.
    if (_registeredEmail != null) {
      return _VerifyEmailScreen(
        email: _registeredEmail!,
        resendLoading: _resendLoading,
        resendSent: _resendSent,
        onResend: _resendVerification,
        onGoToLogin: () => context.go('/login'),
      );
    }

    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SnapLogo(),
                const SizedBox(height: 32),
                Text(
                  'Create your account',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Start clipping — free forever',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_error != null) ...[
                  _ErrorBanner(message: _error!),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  autocorrect: false,
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) return 'Minimum 8 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  decoration:
                      const InputDecoration(labelText: 'Confirm password'),
                  validator: (v) =>
                      v != _passwordCtrl.text ? 'Passwords do not match' : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create account'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Verify email — full screen (post-registration) ─────────────────────────

class _VerifyEmailScreen extends StatelessWidget {
  final String email;
  final bool resendLoading;
  final bool resendSent;
  final VoidCallback onResend;
  final VoidCallback onGoToLogin;

  const _VerifyEmailScreen({
    required this.email,
    required this.resendLoading,
    required this.resendSent,
    required this.onResend,
    required this.onGoToLogin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SnapLogo(),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.mark_email_unread_outlined,
                        size: 40, color: scheme.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Check your inbox',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a verification link to',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click the link to activate your account, then sign in.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (resendSent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 15, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Verification email sent',
                        style: TextStyle(fontSize: 13, color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              OutlinedButton(
                onPressed: resendLoading || resendSent ? null : onResend,
                child: resendLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend verification email'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onGoToLogin,
                child: const Text('Go to sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Verify email — inline banner (login screen) ────────────────────────────

class _VerifyEmailBanner extends StatelessWidget {
  final String email;
  final bool resendLoading;
  final bool resendSent;
  final VoidCallback onResend;

  const _VerifyEmailBanner({
    required this.email,
    required this.resendLoading,
    required this.resendSent,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amber = Colors.amber.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 16, color: amber),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Email not verified',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: amber),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Check your inbox for the link we sent to $email. '
            "Don't see it? Check your spam folder.",
            style: TextStyle(
                fontSize: 12,
                color: scheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 10),
          if (resendSent)
            Row(
              children: [
                Icon(Icons.check_circle_outline,
                    size: 14, color: scheme.primary),
                const SizedBox(width: 6),
                Text('Email sent',
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              ],
            )
          else
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: resendLoading ? null : onResend,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: const TextStyle(fontSize: 12),
                  side: BorderSide(color: amber.withValues(alpha: 0.6)),
                ),
                child: resendLoading
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: amber),
                      )
                    : const Text('Resend verification email'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

class _SnapLogo extends StatelessWidget {
  const _SnapLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.content_paste_rounded,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Snapit',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(letterSpacing: 1.5),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: scheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
