import 'package:flutter/material.dart';

class AiLabelBadge extends StatelessWidget {
  const AiLabelBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return const Chip(
      label: Text('AI generated'),
      visualDensity: VisualDensity.compact,
    );
  }
}
