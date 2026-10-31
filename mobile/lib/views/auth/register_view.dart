import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

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
  UserRole _role = UserRole.viewer;
  String? _usernameError;
  bool _passwordInvalid = false;
  bool _confirmInvalid = false;

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

    final auth = context.read<AuthController>();
    try {
      await auth.register(_username.text, _password.text, _role);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on ApiException catch (e) {
      setState(() => _usernameError = e.message);
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
              'Watch, unlock and upload AI short films.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            const FieldLabel('I want to'),
            Row(
              children: [
                Expanded(
                  child: _RoleCard(
                    icon: Icons.play_circle_outline,
                    title: 'Watch',
                    subtitle: 'Viewer',
                    selected: _role == UserRole.viewer,
                    onTap: () => setState(() => _role = UserRole.viewer),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RoleCard(
                    icon: Icons.upload_outlined,
                    title: 'Create',
                    subtitle: 'Creator',
                    selected: _role == UserRole.creator,
                    onTap: () => setState(() => _role = UserRole.creator),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const FieldLabel('Username'),
            TextField(
              key: const Key('register-username'),
              controller: _username,
              decoration: InputDecoration(
                hintText: 'Choose a username',
                enabledBorder: _usernameError == null ? null : _invalidBorder,
              ),
            ),
            if (_usernameError != null) FieldError(_usernameError!),
            const SizedBox(height: 14),
            const FieldLabel('Password'),
            TextField(
              key: const Key('register-password'),
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Create a password',
                enabledBorder: _passwordInvalid ? _invalidBorder : null,
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
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Type it again',
                enabledBorder: _confirmInvalid ? _invalidBorder : null,
              ),
            ),
            if (_confirmInvalid) const FieldError("Passwords don't match."),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submit,
              child: const Text('Create account'),
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

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderColor: selected ? AppColors.primary : AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
