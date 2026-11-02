import 'package:flutter/material.dart' hide Text;
import 'package:provider/provider.dart';

import '../../controllers/feed_controller.dart';
import '../../controllers/settings_controller.dart';
import '../../data/lookups.dart';
import '../../theme/app_theme.dart';
import '../../widgets/text.dart';

/// Three short slides shown the first time the app opens: what it is, how
/// episodes are paid for, and which genres to show first.
class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView> {
  static const _slides = [
    (
      Icons.play_circle_rounded,
      'Watch AI short films',
      'Swipe through vertical films made with AI, one episode at a time.',
    ),
    (
      Icons.toll_rounded,
      'Unlock with coins or Plus',
      'Early episodes are free. Unlock the rest with coins, or get Plus to '
          'watch everything.',
    ),
    (
      Icons.favorite_rounded,
      'Pick what you like',
      'Choose a few genres and we will show them first.',
    ),
  ];

  final _pages = PageController();
  final _genres = <String>{};
  int _page = 0;

  bool get _isLast => _page == _slides.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish({required bool withGenres}) {
    final chosen = withGenres ? {..._genres} : <String>{};
    context.read<FeedController>().preferGenres(chosen);
    context.read<SettingsController>().completeOnboarding(chosen);
  }

  void _next() {
    if (_isLast) {
      _finish(withGenres: true);
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 56,
                child: _isLast
                    ? null
                    : TextButton(
                        key: const Key('onboarding-skip'),
                        onPressed: () => _finish(withGenres: false),
                        child: const Text(
                          'Skip',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final (icon, title, body) = _slides[i];
                  return _Slide(
                    icon: icon,
                    title: title,
                    body: body,
                    child: i == _slides.length - 1
                        ? _GenrePicker(
                            selected: _genres,
                            onToggle: (genre) => setState(() {
                              if (!_genres.remove(genre)) _genres.add(genre);
                            }),
                          )
                        : null,
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
              child: FilledButton(
                key: Key(_isLast ? 'onboarding-start' : 'onboarding-next'),
                onPressed: _next,
                child: Text(_isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.icon,
    required this.title,
    required this.body,
    this.child,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 26),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFF3A2F7A), AppColors.primarySoft],
              ),
              boxShadow: const [
                BoxShadow(color: Color(0x557554F5), blurRadius: 40),
              ],
            ),
            child: Icon(icon, size: 62, color: AppColors.link),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted, height: 1.4),
          ),
          if (child != null) ...[const SizedBox(height: 22), child!],
        ],
      ),
    );
  }
}

class _GenrePicker extends StatelessWidget {
  const _GenrePicker({required this.selected, required this.onToggle});

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final genre in genreNames)
          Semantics(
            button: true,
            selected: selected.contains(genre),
            label: genre,
            excludeSemantics: true,
            onTap: () => onToggle(genre),
            child: GestureDetector(
              key: Key('genre-$genre'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onToggle(genre),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: selected.contains(genre)
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected.contains(genre)
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  genre,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected.contains(genre)
                        ? Colors.white
                        : AppColors.text,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
