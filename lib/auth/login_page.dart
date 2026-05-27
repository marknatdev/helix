import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import 'auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

enum _Mode { signIn, signUp }

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (_mode == _Mode.signIn) {
        await auth.signIn(_email.text, _password.text);
      } else {
        await auth.signUp(_email.text, _password.text);
      }
    } catch (e) {
      setState(() => _error = AuthService.messageFor(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signIn = _mode == _Mode.signIn;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.construction,
                              color: AppColors.primaryFg, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('HELIX',
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  letterSpacing: 2,
                                )),
                            Text('COMMAND CENTER',
                                style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 2.5,
                                    color: AppColors.mutedFg)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text(
                      signIn ? 'Operator sign in' : 'Create operator account',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signIn
                          ? 'Authorized personnel only. Credentials verified by Firebase.'
                          : 'Register a new operator to access the command center.',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.mutedFg),
                    ),
                    const SizedBox(height: 20),
                    _FieldLabel('Email'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: const TextStyle(fontSize: 13),
                      decoration: _decoration('operator@example.com'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required.';
                        }
                        if (!v.contains('@')) return 'Enter a valid email.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Password'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      style: const TextStyle(fontSize: 13),
                      decoration: _decoration('••••••••'),
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required.';
                        }
                        if (v.length < 6) {
                          return 'Minimum 6 characters.';
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.statusSos.withValues(alpha: 0.1),
                          border: Border.all(
                              color: AppColors.statusSos
                                  .withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.statusSos, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_error!,
                                style: const TextStyle(
                                    color: AppColors.statusSos,
                                    fontSize: 12)),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.primaryFg,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryFg),
                            )
                          : Text(signIn ? 'Sign in' : 'Create account',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _mode = signIn ? _Mode.signUp : _Mode.signIn;
                                _error = null;
                              }),
                      child: Text(
                        signIn
                            ? "Need access? Create an account"
                            : 'Already have an account? Sign in',
                        style: const TextStyle(
                            color: AppColors.mutedFg, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.mutedFg, fontSize: 13),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      filled: true,
      fillColor: AppColors.background.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  // ignore: unused_element_parameter
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 10,
            letterSpacing: 1.6,
            color: AppColors.mutedFg,
            fontWeight: FontWeight.w600));
  }
}
