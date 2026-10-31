import 'package:flutter/foundation.dart';

import '../l10n/app_language.dart';

/// Choices a person makes about how the app behaves on their device.
class SettingsController extends ChangeNotifier {
  SettingsController({this.onboarded = true});

  /// False until the person has been through the first-run slides.
  bool onboarded;

  /// Genres picked in the first-run slides, shown first in the feed.
  Set<String> favoriteGenres = const {};

  /// The language the app's own wording is shown in.
  AppLanguage language = AppLanguage.english;

  /// The speed each film starts at.
  double defaultSpeed = 1;

  /// Whether holding the right edge for 2x gives a small vibration.
  bool haptics = true;

  void completeOnboarding(Set<String> genres) {
    favoriteGenres = genres;
    onboarded = true;
    notifyListeners();
  }

  void setLanguage(AppLanguage value) {
    if (value == language) return;
    language = value;
    notifyListeners();
  }

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
