import 'package:flutter/material.dart';

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
            const Text('Log in to continue', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onLogin, child: const Text('Log in')),
          ],
        ),
      ),
    );
  }
}
