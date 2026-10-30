import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const EmptyView(message: 'Search screen'),
    );
  }
}
