import 'package:flutter/widgets.dart';

import 'tab_active.dart';

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

/// Like [OnInit], and also runs again every time the tab it sits in becomes the
/// visible one, so a screen kept alive in the tab stack (Profile) re-reads what
/// was saved, bought or followed elsewhere while it was hidden.
class OnActivated extends StatefulWidget {
  const OnActivated({super.key, required this.run, required this.child});

  final VoidCallback run;
  final Widget child;

  @override
  State<OnActivated> createState() => _OnActivatedState();
}

class _OnActivatedState extends State<OnActivated> {
  bool _wasActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final active = TabActive.of(context);
    if (active && !_wasActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.run();
      });
    }
    _wasActive = active;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
