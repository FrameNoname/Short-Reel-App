import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../widgets/login_prompt.dart';
import '../auth/login_view.dart';
import 'coin_shop_view.dart';
import 'subscription_view.dart';

class WalletView extends StatelessWidget {
  const WalletView({super.key});

  void _open(BuildContext context, Widget view) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => view));
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthController>().isLoggedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: isLoggedIn
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Demo wallet: no real money is used'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _open(context, const CoinShopView()),
                    child: const Text('Coin shop'),
                  ),
                  FilledButton(
                    onPressed: () => _open(context, const SubscriptionView()),
                    child: const Text('Subscription'),
                  ),
                ],
              ),
            )
          : LoginPrompt(onLogin: () => _open(context, const LoginView())),
    );
  }
}
