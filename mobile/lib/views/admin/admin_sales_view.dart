import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class AdminSalesView extends StatelessWidget {
  const AdminSalesView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin sales')),
      body: const EmptyView(message: 'Admin sales screen'),
    );
  }
}
