import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../l10n/app_language.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

const _passwordRule = 'At least 8 characters, with a letter and a number.';

class RegisterView extends StatefulWidget {
  const RegisterView({super.key});

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _usernameError;
  bool _passwordInvalid = false;
  bool _confirmInvalid = false;
  bool _hidePassword = true;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool _isStrong(String password) =>
      password.length >= 8 &&
      password.contains(RegExp('[A-Za-z]')) &&
      password.contains(RegExp('[0-9]'));

  Future<void> _submit() async {
    final passwordInvalid = !_isStrong(_password.text);
    final confirmInvalid = _password.text != _confirm.text;
    final usernameError = _username.text.trim().isEmpty
        ? 'Choose a username.'
        : null;
    setState(() {
      _usernameError = usernameError;
      _passwordInvalid = passwordInvalid;
      _confirmInvalid = confirmInvalid;
    });
    if (passwordInvalid || confirmInvalid || usernameError != null) return;

    if (_busy) return;
    final auth = context.read<AuthController>();
    setState(() => _busy = true);
    try {
      await auth.register(_username.text, _password.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      if (mounted) setState(() => _usernameError = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppBrand(),
            const SizedBox(height: 14),
            const Text(
              'Create your account',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Watch and unlock AI short films.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            const FieldLabel('Username'),
            TextField(
              key: const Key('register-username'),
              controller: _username,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: context.tr('Choose a username'),
                enabledBorder: _usernameError == null ? null : _invalidBorder,
              ),
            ),
            if (_usernameError != null) FieldError(_usernameError!),
            const SizedBox(height: 14),
            const FieldLabel('Password'),
            TextField(
              key: const Key('register-password'),
              controller: _password,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: context.tr('Create a password'),
                enabledBorder: _passwordInvalid ? _invalidBorder : null,
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
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
            if (_passwordInvalid)
              const FieldError(_passwordRule)
            else
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  _passwordRule,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            const FieldLabel('Confirm password'),
            TextField(
              key: const Key('register-confirm'),
              controller: _confirm,
              obscureText: _hidePassword,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: context.tr('Type it again'),
                enabledBorder: _confirmInvalid ? _invalidBorder : null,
              ),
            ),
            if (_confirmInvalid) const FieldError("Passwords don't match."),
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
                  : const Text('Create account'),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: AppColors.muted),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Log in',
                    style: TextStyle(color: AppColors.link),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final _invalidBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(14),
  borderSide: const BorderSide(color: AppColors.danger),
);
