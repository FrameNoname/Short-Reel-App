import 'package:flutter/material.dart';

import '../../models/film.dart';
import '../feed/film_page.dart';

class PlayerView extends StatelessWidget {
  const PlayerView({super.key, required this.film});

  final Film film;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: FilmPage(film: film),
    );
  }
}
