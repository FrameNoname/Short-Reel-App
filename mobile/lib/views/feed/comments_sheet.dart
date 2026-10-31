import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/feed_controller.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
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

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send(int userId) async {
    if (_body.text.trim().isEmpty) return;
    await context.read<FeedController>().addComment(
      userId,
      widget.film.id,
      _body.text,
    );
    _body.clear();
  }

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedController>();
    final userId = context.watch<AuthController>().user?.id;
    final comments = feed.repository.commentsOf(widget.film.id);
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
          const Text(
            'Comments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(
            height: 280,
            child: comments.isEmpty
                ? const EmptyView(message: 'No comments yet.')
                : ListView(
                    children: [
                      for (final comment in comments)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '@${comment.username}',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            comment.body,
                            style: const TextStyle(color: AppColors.text),
                          ),
                          trailing: comment.userId == userId
                              ? IconButton(
                                  tooltip: 'Delete comment',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () =>
                                      feed.removeComment(userId!, comment.id),
                                )
                              : null,
                        ),
                    ],
                  ),
          ),
          if (userId == null)
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const LoginView()),
              ),
              child: const Text('Log in to comment'),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('comment-input'),
                    controller: _body,
                    maxLength: 500,
                    buildCounter:
                        (
                          _, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) => null,
                    onSubmitted: (_) => _send(userId),
                    decoration: const InputDecoration(
                      hintText: 'Add a comment',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  key: const Key('comment-send'),
                  tooltip: 'Send comment',
                  icon: const Icon(Icons.send),
                  onPressed: () => _send(userId),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
