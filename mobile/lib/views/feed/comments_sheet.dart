import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../data/app_repository.dart';
import '../../l10n/app_language.dart';
import '../../services/errors.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/empty_view.dart';
import '../../widgets/text.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<FeedController>().loadComments(widget.film.id);
    } on Object {
      // The sheet keeps showing what it has.
    }
    if (mounted) setState(() {});
  }

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

  Future<void> _send(int userId) async {
    if (_body.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<FeedController>().addComment(
        userId,
        widget.film.id,
        _body.text,
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorMessage(e))));
      return;
    }
    _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final userId = context.watch<AuthController>().user?.id;
    final all = feed.commentsOf(widget.film.id);
    final comments = all;
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
                tooltip: context.tr('Close'),
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
                          hintText: context.tr('Add a comment'),
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
                      tooltip: context.tr('Send comment'),
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
  const _CommentRow({required this.comment, this.onDelete});

  final FilmComment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.surface,
          child: Text(
            comment.username[0].toUpperCase(),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
              if (onDelete != null)
                _TextAction(
                  key: Key('comment-delete-${comment.id}'),
                  label: 'Delete',
                  onTap: onDelete!,
                ),
            ],
          ),
        ),
      ],
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
