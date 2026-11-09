import 'package:shortreel/models/film.dart';
import 'package:shortreel/services/api_client.dart';

/// Shared by the per-feature tests.
const serverDown = ApiException(
  code: 'NETWORK',
  message: 'Cannot reach the server',
);

Film testFilm(int id, String title, {int likes = 0, String genre = ''}) => Film(
  id: id,
  title: title,
  synopsis: null,
  posterUrl: null,
  genreId: 1,
  aiToolId: 1,
  promptCredit: null,
  isAiGenerated: true,
  status: 'approved',
  likeCount: likes,
  genreName: genre,
);
