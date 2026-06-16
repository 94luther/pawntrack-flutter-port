import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Last Resort Pawnshop',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign in to PawnTrack',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: const Color(0xff64748b)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: email,
                    enabled: !loading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.mail_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    enabled: !loading,
                    obscureText: hidePassword,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip:
                            hidePassword ? 'Show password' : 'Hide password',
                        onPressed: loading
                            ? null
                            : () =>
                                setState(() => hidePassword = !hidePassword),
                        icon: Icon(hidePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                      ),
                    ),
                    onSubmitted: (_) => _login(),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: loading ? null : _login,
                    icon: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(loading ? 'Signing in...' : 'Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    final emailText = email.text.trim();
    final passwordText = password.text;
    if (emailText.isEmpty || passwordText.isEmpty) {
      setState(() => error = 'Enter both email and password.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailText,
        password: passwordText,
      );
    } on FirebaseAuthException catch (authError) {
      if (!mounted) return;
      setState(() => error = _authMessage(authError));
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          error = 'Could not sign in. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _authMessage(FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-not-found' => 'No staff account exists for that email.',
      'wrong-password' ||
      'invalid-credential' =>
        'The email or password is incorrect.',
      'user-disabled' => 'This staff account has been disabled.',
      'network-request-failed' => 'Network connection failed. Try again.',
      'too-many-requests' =>
        'Too many login attempts. Wait a moment and try again.',
      _ => error.message ?? 'Could not sign in. Try again.',
    };
  }
}
