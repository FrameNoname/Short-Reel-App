import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../models/user.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/login_prompt.dart';
import '../auth/login_view.dart';
import 'creator_dashboard_view.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  void _open(BuildContext context, Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final isCreator =
        auth.role == UserRole.creator || auth.role == UserRole.admin;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: auth.isLoggedIn
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const EmptyView(message: 'Profile screen'),
                  if (isCreator)
                    FilledButton(
                      onPressed: () =>
                          _open(context, const CreatorDashboardView()),
                      child: const Text('Creator dashboard'),
                    ),
                ],
              ),
            )
          : LoginPrompt(onLogin: () => _open(context, const LoginView())),
    );
  }
}
