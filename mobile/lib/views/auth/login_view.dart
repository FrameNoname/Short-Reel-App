import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import 'register_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePassword = true;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _leaveToApp() => Navigator.of(context).popUntil((r) => r.isFirst);

  Future<void> _submit() async {
    if (_busy) return;
    final auth = context.read<AuthController>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await auth.login(_username.text, _password.text);
      if (mounted) _leaveToApp();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _continueAsGuest() {
    context.read<AuthController>().continueAsGuest();
    _leaveToApp();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _error != null;
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/login_banner.jpg',
              width: double.infinity,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  const Text(
                    'AI short films, one episode at a time.',
                    style: TextStyle(color: AppColors.muted, fontSize: 15),
                  ),
                  const SizedBox(height: 28),
                  const FieldLabel('Username'),
                  TextField(
                    key: const Key('login-username'),
                    controller: _username,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      enabledBorder: hasError ? _errorBorder : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const FieldLabel('Password'),
                      const _ForgotPasswordLink(),
                    ],
                  ),
                  TextField(
                    key: const Key('login-password'),
                    controller: _password,
                    obscureText: _hidePassword,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      enabledBorder: hasError ? _errorBorder : null,
                      suffixIcon: IconButton(
                        tooltip: _hidePassword
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          _hidePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.muted,
                        ),
                        onPressed: () =>
                            setState(() => _hidePassword = !_hidePassword),
                      ),
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 12),
                    AppCard(
                      color: const Color(0x33FF6B6B),
                      borderColor: const Color(0x66FF6B6B),
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_error!)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Log in'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const RegisterView(),
                      ),
                    ),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: _continueAsGuest,
                      child: const Text(
                        'Watch free episodes without an account',
                        style: TextStyle(color: AppColors.text),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForgotPasswordLink extends StatelessWidget {
  const _ForgotPasswordLink();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('forgot-password'),
      behavior: HitTestBehavior.opaque,
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset is not ready yet.')),
      ),
      child: const SizedBox(
        height: 44,
        child: Center(
          widthFactor: 1,
          child: Text(
            'Forgot password?',
            style: TextStyle(
              color: AppColors.link,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

final _errorBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: const BorderSide(color: AppColors.danger),
);
