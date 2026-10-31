import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../data/app_repository.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/empty_view.dart';
import '../auth/login_view.dart';

void showCommentsSheet(BuildContext context, Film film) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CommentsSheet(film: film),
  );
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.film});

  final Film film;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _body = TextEditingController();
  final _focus = FocusNode();

  /// The top-level comment a new comment will answer, or null.
  FilmComment? _replyTo;

  @override
  void dispose() {
    _body.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _logIn() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const LoginView()));
  }

  void _startReply(FilmComment comment) {
    // Replies stay one level deep, so answering a reply answers its parent.
    final repository = context.read<FeedController>().repository;
    final parent = comment.parentId == null
        ? comment
        : repository
              .commentsOf(widget.film.id)
              .firstWhere(
                (c) => c.id == comment.parentId,
                orElse: () => comment,
              );
    setState(() => _replyTo = parent);
    _focus.requestFocus();
  }

  Future<void> _send(int userId) async {
    if (_body.text.trim().isEmpty) return;
    await context.read<FeedController>().addComment(
      userId,
      widget.film.id,
      _body.text,
      parentId: _replyTo?.id,
    );
    _body.clear();
    if (mounted) setState(() => _replyTo = null);
  }

  /// Top-level comments, each followed by its replies in the order written.
  List<FilmComment> _threaded(List<FilmComment> all) {
    final replies = <int, List<FilmComment>>{};
    for (final c in all.where((c) => c.isReply)) {
      replies.putIfAbsent(c.parentId!, () => []).insert(0, c);
    }
    return [
      for (final top in all.where((c) => !c.isReply)) ...[
        top,
        ...?replies[top.id],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final userId = context.watch<AuthController>().user?.id;
    final repository = feed.repository;
    final all = repository.commentsOf(widget.film.id);
    final comments = _threaded(all);
    // The comment being answered may have been deleted meanwhile.
    final replyTo = all.any((c) => c.id == _replyTo?.id) ? _replyTo : null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        0,
        18,
        14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Comments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              Text(
                '${all.length}',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          SizedBox(
            height: 300,
            child: comments.isEmpty
                ? const EmptyView(message: 'No comments yet. Say something.')
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 4),
                    itemCount: comments.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final comment = comments[i];
                      return _CommentRow(
                        comment: comment,
                        likes: repository.commentLikeCount(comment.id),
                        liked:
                            userId != null &&
                            repository.isCommentLiked(userId, comment.id),
                        onLike: () => userId == null
                            ? _logIn()
                            : feed.toggleCommentLike(userId, comment.id),
                        onReply: () =>
                            userId == null ? _logIn() : _startReply(comment),
                        onDelete: comment.userId == userId
                            ? () => feed.removeComment(userId!, comment.id)
                            : null,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          if (userId == null)
            OutlinedButton(
              onPressed: _logIn,
              child: const Text('Log in to comment'),
            )
          else ...[
            if (replyTo != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to @${replyTo.username}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('reply-cancel'),
                      tooltip: 'Cancel reply',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _replyTo = null),
                    ),
                  ],
                ),
              ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _body,
              builder: (_, value, _) {
                final canSend = value.text.trim().isNotEmpty;
                return Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('comment-input'),
                        controller: _body,
                        focusNode: _focus,
                        maxLength: 500,
                        textInputAction: TextInputAction.send,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              required maxLength,
                            }) => null,
                        onSubmitted: (_) => _send(userId),
                        decoration: InputDecoration(
                          hintText: replyTo == null
                              ? 'Add a comment'
                              : 'Reply to @${replyTo.username}',
                          filled: true,
                          fillColor: AppColors.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          border: _pill,
                          enabledBorder: _pill,
                          focusedBorder: _pill,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      key: const Key('comment-send'),
                      tooltip: 'Send comment',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: canSend
                            ? AppColors.primary
                            : AppColors.surface,
                        foregroundColor: canSend
                            ? Colors.white
                            : AppColors.muted,
                      ),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      onPressed: canSend ? () => _send(userId) : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

final _pill = OutlineInputBorder(
  borderRadius: BorderRadius.circular(26),
  borderSide: BorderSide.none,
);

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.likes,
    required this.liked,
    required this.onLike,
    required this.onReply,
    this.onDelete,
  });

  final FilmComment comment;
  final int likes;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isReply = comment.isReply;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 44 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 13 : 17,
            backgroundColor: AppColors.surface,
            child: Text(
              comment.username[0].toUpperCase(),
              style: TextStyle(
                fontSize: isReply ? 12 : 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@${comment.username}',
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: const TextStyle(color: AppColors.text, height: 1.3),
                ),
                Row(
                  children: [
                    _TextAction(
                      key: Key('comment-reply-${comment.id}'),
                      label: 'Reply',
                      onTap: onReply,
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 16),
                      _TextAction(
                        key: Key('comment-delete-${comment.id}'),
                        label: 'Delete',
                        onTap: onDelete!,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: liked ? 'Unlike comment' : 'Like comment',
            excludeSemantics: true,
            onTap: onLike,
            child: GestureDetector(
              key: Key('comment-like-${comment.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onLike,
              child: SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: liked ? AppColors.danger : AppColors.muted,
                    ),
                    if (likes > 0)
                      Text(
                        compactCount(likes),
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small text button that still has a 44 px tall touch target.
class _TextAction extends StatelessWidget {
  const _TextAction({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        height: 44,
        child: Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
