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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: Padding(
          padding: const EdgeInsets.all(6),
          child: IconButton.filled(
            tooltip: 'Back',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0x66000000),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ),
      body: FilmPage(film: film),
    );
  }
}
