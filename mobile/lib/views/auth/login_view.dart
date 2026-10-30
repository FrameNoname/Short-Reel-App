import 'package:flutter/material.dart';

import 'register_view.dart';
import '../../widgets/empty_view.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(message: 'Login screen'),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const RegisterView()),
              ),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
