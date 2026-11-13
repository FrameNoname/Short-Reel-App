// Person 2: the Film model.
import 'package:flutter_test/flutter_test.dart';
import 'package:shortreel/models/film.dart';

void main() {
  group('Film', () {
    test('reads counts with defaults and copyWith keeps the rest', () {
      final film = Film.fromJson({
        'id': 3,
        'title': 'Salt & Signal',
        'genre_id': 1,
        'ai_tool_id': 2,
        'is_ai_generated': true,
        'status': 'approved',
        'like_count': 4,
      });
      expect(film.likeCount, 4);
      expect(film.commentCount, 0);
      expect(film.genreName, '');
      final liked = film.copyWith(likeCount: 5);
      expect(liked.likeCount, 5);
      expect(liked.title, 'Salt & Signal');
    });
  });
}
