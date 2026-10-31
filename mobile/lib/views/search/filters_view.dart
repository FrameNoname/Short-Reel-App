import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/film_search_controller.dart';
import '../../data/film_filter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

const _genres = [
  (
    'Drama',
    Icons.theater_comedy_outlined,
    Color(0xFFFFA36B),
    Color(0xFF2B1F1C),
  ),
  ('Sci-Fi', Icons.public, Color(0xFF5CD6F2), Color(0xFF14262D)),
  ('Romance', Icons.favorite_border, Color(0xFFFF7C9C), Color(0xFF2E1A22)),
  ('Thriller', Icons.bolt, Color(0xFFFFC53D), Color(0xFF2A2415)),
  ('Fantasy', Icons.auto_awesome, Color(0xFFB9A6FF), Color(0xFF211C33)),
  ('Mystery', Icons.manage_search, Color(0xFF3DD68C), Color(0xFF16261D)),
];

const _lengths = [
  (LengthFilter.any, 'Any length', 1.0),
  (LengthFilter.under5, 'Under 5 min', 0.18),
  (LengthFilter.from5to15, '5–15 min', 0.5),
  (LengthFilter.from15to30, '15–30 min', 0.9),
];

const _tools = [
  ('Text-to-video', 'Generated from a written prompt'),
  ('Image-to-video', 'Still images brought to life'),
  ('Video-to-video', 'Existing footage restyled by AI'),
  ('Mixed', 'A blend of several AI tools'),
];

class FiltersView extends StatefulWidget {
  const FiltersView({super.key, required this.initial});

  final FilmFilter initial;

  @override
  State<FiltersView> createState() => _FiltersViewState();
}

class _FiltersViewState extends State<FiltersView> {
  late FilmFilter _filter = widget.initial;
  int? _count;

  @override
  void initState() {
    super.initState();
    _refreshCount();
  }

  Future<void> _refreshCount() async {
    final count = await context.read<FilmSearchController>().countFor(_filter);
    if (mounted) setState(() => _count = count);
  }

  void _update(FilmFilter filter) {
    setState(() => _filter = filter);
    _refreshCount();
  }

  Set<String> _toggled(Set<String> values, String value) {
    return values.contains(value)
        ? ({...values}..remove(value))
        : {...values, value};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const CloseButton(),
        centerTitle: true,
        title: const Text('Filters', style: TextStyle(fontSize: 17)),
        actions: [
          TextButton(
            onPressed: _filter.hasFilters
                ? () => _update(FilmFilter(query: _filter.query))
                : null,
            child: Text(
              'Reset',
              style: TextStyle(
                color: _filter.hasFilters ? AppColors.link : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const _SectionTitle('Genre'),
              Text(
                '${_filter.genres.length} selected',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              for (final (name, icon, color, tint) in _genres)
                _GenreTile(
                  name: name,
                  icon: icon,
                  color: color,
                  tint: tint,
                  selected: _filter.genres.contains(name),
                  onTap: () => _update(
                    _filter.copyWith(genres: _toggled(_filter.genres, name)),
                  ),
                ),
            ],
          ),
          const _SectionTitle('Episode length'),
          for (final (value, label, fill) in _lengths)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _update(_filter.copyWith(length: value)),
                child: _Choice(
                  selected: _filter.length == value,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 86,
                        child: Text(
                          label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fill,
                            minHeight: 6,
                            backgroundColor: AppColors.border,
                            color: _filter.length == value
                                ? AppColors.primary
                                : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const _SectionTitle('Made with'),
          for (final (name, description) in _tools)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _update(
                  _filter.copyWith(aiTools: _toggled(_filter.aiTools, name)),
                ),
                child: _Choice(
                  selected: _filter.aiTools.contains(name),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        description,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: FilledButton(
            onPressed: _count == 0
                ? null
                : () => Navigator.of(context).pop(_filter),
            child: Text(switch (_count) {
              null => 'Show films',
              0 => 'No films match',
              1 => 'Show 1 film',
              final n => 'Show $n films',
            }),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _GenreTile extends StatelessWidget {
  const _GenreTile({
    required this.name,
    required this.icon,
    required this.color,
    required this.tint,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final Color color;
  final Color tint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 22),
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (selected)
                const Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.child});

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: selected ? AppColors.primarySoft : AppColors.surface,
      borderColor: selected ? AppColors.primary : AppColors.border,
      child: Row(
        children: [
          Expanded(child: child),
          const SizedBox(width: 12),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 20,
            color: selected ? AppColors.primary : AppColors.muted,
          ),
        ],
      ),
    );
  }
}
