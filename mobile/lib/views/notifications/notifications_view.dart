import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/notifications_controller.dart';
import '../../models/app_notification.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';
import '../player/player_view.dart';
import '../profile/creator_dashboard_view.dart';
import '../profile/creator_profile_view.dart';

/// The bell in a top bar, with a count of what has not been seen yet.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthController>().user?.id;
    if (userId == null) return const SizedBox.shrink();
    final unread = context.watch<NotificationsController>().unreadOf(userId);
    return Semantics(
      button: true,
      label: unread == 0 ? 'Notifications' : 'Notifications, $unread new',
      excludeSemantics: true,
      onTap: () => _open(context),
      child: GestureDetector(
        key: const Key('notification-bell'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_rounded, size: 26),
              if (unread > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    key: const Key('notification-badge'),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const NotificationsView()));
  }
}

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  /// What was new when the page opened; it keeps its highlight even though
  /// the bell is cleared straight away.
  late final Set<int> _newIds;

  @override
  void initState() {
    super.initState();
    final userId = context.read<AuthController>().user!.id;
    final controller = context.read<NotificationsController>();
    _newIds = {
      for (final n in controller.inboxOf(userId))
        if (!n.read) n.id,
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) controller.markAllRead(userId);
    });
  }

  void _open(AppNotification item) {
    final repository = context.read<NotificationsController>().repository;
    switch (item.kind) {
      case NotificationKind.follow:
        openCreatorProfile(context, item.actorId!);
      case NotificationKind.approved ||
          NotificationKind.rejected ||
          NotificationKind.takenDown:
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreatorDashboardView()),
        );
      case _:
        final film = repository.filmById(item.filmId ?? -1);
        if (film == null) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => PlayerView(film: film)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthController>().user!.id;
    final items = context.watch<NotificationsController>().inboxOf(userId);
    final fresh = items.where((n) => _newIds.contains(n.id)).toList();
    final earlier = items.where((n) => !_newIds.contains(n.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notifications yet.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (fresh.isNotEmpty) ...[
                  const _Header('New'),
                  for (final item in fresh)
                    _Row(item: item, isNew: true, onTap: () => _open(item)),
                ],
                if (earlier.isNotEmpty) ...[
                  const _Header('Earlier'),
                  for (final item in earlier)
                    _Row(item: item, isNew: false, onTap: () => _open(item)),
                ],
              ],
            ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.isNew, required this.onTap});

  final AppNotification item;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('notification-${item.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        color: isNew ? AppColors.primarySoft : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(item: item),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.hasActor)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '@${item.actorName}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          TextSpan(text: ' ${item.message}'),
                        ],
                      ),
                    )
                  else
                    Text(
                      item.message,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    timeAgo(item.createdAt),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isNew)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6),
                child: Container(
                  key: Key('notification-new-${item.id}'),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.item});

  final AppNotification item;

  (IconData, Color) get _badge => switch (item.kind) {
    NotificationKind.like => (Icons.favorite_rounded, AppColors.danger),
    NotificationKind.comment ||
    NotificationKind.reply => (Icons.sms_rounded, AppColors.link),
    NotificationKind.follow => (Icons.person_add_rounded, AppColors.primary),
    NotificationKind.unlock => (Icons.lock_open_rounded, AppColors.gold),
    NotificationKind.approved => (Icons.check_circle_rounded, AppColors.green),
    NotificationKind.rejected => (Icons.cancel_rounded, AppColors.danger),
    NotificationKind.takenDown => (Icons.flag_rounded, AppColors.danger),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _badge;
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceHigh,
            child: item.hasActor
                ? Text(
                    item.actorName[0].toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  )
                : Icon(icon, color: color),
          ),
          if (item.hasActor)
            Positioned(
              right: -4,
              bottom: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
                child: Icon(icon, size: 12, color: color),
              ),
            ),
        ],
      ),
    );
  }
}
