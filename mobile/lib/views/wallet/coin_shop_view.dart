import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class CoinShopView extends StatelessWidget {
  const CoinShopView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Coin shop')),
      body: const EmptyView(message: 'Coin shop screen'),
    );
  }
}
