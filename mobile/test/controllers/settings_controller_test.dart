// Person 1: SettingsController (device settings).
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/controllers/settings_controller.dart';

void main() {
  group('SettingsController', () {
    test('starts at normal speed with haptics on', () {
      final settings = SettingsController();
      expect(settings.defaultSpeed, 1);
      expect(settings.haptics, isTrue);
    });

    test('notifies only when a value really changes', () {
      final settings = SettingsController();
      var notified = 0;
      settings.addListener(() => notified++);

      settings.setDefaultSpeed(1);
      settings.setHaptics(enabled: true);
      expect(notified, 0);

      settings.setDefaultSpeed(1.5);
      settings.setHaptics(enabled: false);
      expect(settings.defaultSpeed, 1.5);
      expect(settings.haptics, isFalse);
      expect(notified, 2);
    });
  });
}
