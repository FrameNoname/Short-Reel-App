import 'package:flutter/material.dart' hide Text;

import '../theme/app_theme.dart';
import '../widgets/text.dart';

class LoginPrompt extends StatelessWidget {
  const LoginPrompt({super.key, required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, color: AppColors.primary, size: 36),
            const SizedBox(height: 12),
            const Text(
              'Log in to continue',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onLogin, child: const Text('Log in')),
          ],
        ),
      ),
    );
  }
}
