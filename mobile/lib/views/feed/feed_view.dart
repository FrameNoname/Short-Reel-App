import 'package:flutter/material.dart';

import '../player/player_view.dart';
import '../../widgets/empty_view.dart';

class FeedView extends StatelessWidget {
  const FeedView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(message: 'Feed screen'),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlayerView()),
              ),
              child: const Text('Open player'),
            ),
          ],
        ),
      ),
    );
  }
}
