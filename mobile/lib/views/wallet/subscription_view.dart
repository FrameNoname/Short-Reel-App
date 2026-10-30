import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class SubscriptionView extends StatelessWidget {
  const SubscriptionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: const EmptyView(message: 'Subscription screen'),
    );
  }
}
