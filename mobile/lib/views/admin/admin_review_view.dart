import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class AdminReviewView extends StatelessWidget {
  const AdminReviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin review')),
      body: const EmptyView(message: 'Admin review screen'),
    );
  }
}
