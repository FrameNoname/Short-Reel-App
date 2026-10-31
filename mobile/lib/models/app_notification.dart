enum NotificationKind {
  like,
  comment,
  reply,
  follow,
  unlock,
  approved,
  rejected,
  takenDown,
}

/// One line in a person's inbox.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.kind,
    required this.createdAt,
    this.actorId,
    this.actorName = '',
    this.filmId,
    this.filmTitle = '',
    this.episodeNo,
    this.read = false,
  });

  final int id;

  /// Who the notification is for.
  final int userId;
  final NotificationKind kind;
  final DateTime createdAt;

  /// Who did it; null for messages from the app, such as a review result.
  final int? actorId;
  final String actorName;
  final int? filmId;
  final String filmTitle;
  final int? episodeNo;
  final bool read;

  bool get hasActor => actorId != null;

  AppNotification asRead() => AppNotification(
    id: id,
    userId: userId,
    kind: kind,
    createdAt: createdAt,
    actorId: actorId,
    actorName: actorName,
    filmId: filmId,
    filmTitle: filmTitle,
    episodeNo: episodeNo,
    read: true,
  );

  /// What happened, without the actor's name: "liked Salt & Signal".
  String get message => switch (kind) {
    NotificationKind.like => 'liked $filmTitle',
    NotificationKind.comment => 'commented on $filmTitle',
    NotificationKind.reply => 'replied to your comment on $filmTitle',
    NotificationKind.follow => 'started following you',
    NotificationKind.unlock => 'unlocked Episode $episodeNo of $filmTitle',
    NotificationKind.approved => '$filmTitle was approved',
    NotificationKind.rejected => '$filmTitle was rejected',
    NotificationKind.takenDown => '$filmTitle was taken down',
  };
}
