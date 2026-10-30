import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: const EmptyView(message: 'Player screen'),
    );
  }
}
