import 'package:flutter/widgets.dart';

/// Tells a tab's content whether its tab is the one on screen. The tabs are
/// kept alive side by side, so without this a video under another tab would
/// carry on playing.
class TabActive extends InheritedWidget {
  const TabActive({super.key, required this.active, required super.child});

  final bool active;

  /// True when there is no tab around, for a screen shown on its own.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabActive>()?.active ?? true;

  @override
  bool updateShouldNotify(TabActive oldWidget) => active != oldWidget.active;
}
