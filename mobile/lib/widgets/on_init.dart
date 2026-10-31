import 'package:flutter/widgets.dart';

/// Runs [run] once, right after the first frame, and shows [child].
class OnInit extends StatefulWidget {
  const OnInit({super.key, required this.run, required this.child});

  final VoidCallback run;
  final Widget child;

  @override
  State<OnInit> createState() => _OnInitState();
}

class _OnInitState extends State<OnInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.run();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
