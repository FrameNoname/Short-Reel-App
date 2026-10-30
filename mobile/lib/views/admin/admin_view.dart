import 'package:flutter/material.dart';

import 'admin_review_view.dart';
import 'admin_sales_view.dart';
import '../../widgets/empty_view.dart';

class AdminView extends StatelessWidget {
  const AdminView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyView(message: 'Admin screen'),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminReviewView(),
                ),
              ),
              child: const Text('Admin review'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AdminSalesView()),
              ),
              child: const Text('Admin sales'),
            ),
          ],
        ),
      ),
    );
  }
}
