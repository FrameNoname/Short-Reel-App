import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class CreatorDashboardView extends StatelessWidget {
  const CreatorDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Creator dashboard')),
      body: const EmptyView(message: 'Creator dashboard screen'),
    );
  }
}
