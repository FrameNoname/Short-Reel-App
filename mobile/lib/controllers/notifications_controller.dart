import 'package:flutter/foundation.dart';

import '../data/app_repository.dart';
import '../models/app_notification.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController(this.repository);

  final AppRepository repository;

  List<AppNotification> inboxOf(int userId) =>
      repository.notificationsOf(userId);

  int unreadOf(int userId) => repository.unreadNotificationCount(userId);

  void markAllRead(int userId) {
    if (unreadOf(userId) == 0) return;
    repository.markNotificationsRead(userId);
    notifyListeners();
  }

  /// Tells the bell to look again after something may have been added.
  void refresh() => notifyListeners();
}
