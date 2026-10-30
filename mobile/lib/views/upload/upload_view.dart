import 'package:flutter/material.dart';

import '../../widgets/empty_view.dart';

class UploadView extends StatelessWidget {
  const UploadView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: const EmptyView(message: 'Upload screen'),
    );
  }
}
