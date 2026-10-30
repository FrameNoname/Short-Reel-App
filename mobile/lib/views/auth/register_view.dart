import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: const EmptyView(message: 'Register screen'),
    );
  }
}
