import 'package:flutter/foundation.dart';

/// Choices a person makes about how the app behaves on their device.
class SettingsController extends ChangeNotifier {
  /// The speed each film starts at.
  double defaultSpeed = 1;

  /// Whether holding the right edge for 2x gives a small vibration.
  bool haptics = true;

  void setDefaultSpeed(double value) {
    if (value == defaultSpeed) return;
    defaultSpeed = value;
    notifyListeners();
  }

  void setHaptics({required bool enabled}) {
    if (enabled == haptics) return;
    haptics = enabled;
    notifyListeners();
  }
}
