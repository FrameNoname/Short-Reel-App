import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../../data/app_repository.dart';
import '../../l10n/app_language.dart';
import '../../models/film.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/text.dart';

enum StatMetric {
  views('Views', AppColors.primary),
  likes('Likes', AppColors.danger),
  coins('Coins', AppColors.gold);

  const StatMetric(this.label, this.color);

  final String label;
  final Color color;

  int of(DailyStat day) => switch (this) {
    views => day.views,
    likes => day.likes,
    coins => day.coins,
  };
}

enum StatPeriod {
  week(7),
  month(30);

  const StatPeriod(this.days);

  final int days;
}

/// A channel's numbers over time: pick what to look at and for how long, see
/// the total, how it moved, and a bar for each day.
class PerformanceCard extends StatefulWidget {
  const PerformanceCard({super.key, required this.stats});

  /// At least twice the longest period, oldest day first, so every period has
  /// an earlier one to be compared with.
  final List<DailyStat> stats;

  @override
  State<PerformanceCard> createState() => _PerformanceCardState();
}

class _PerformanceCardState extends State<PerformanceCard> {
  StatMetric _metric = StatMetric.views;
  StatPeriod _period = StatPeriod.week;
  int? _selected;

  List<int> _values(int from, int to) => [
    for (final day in widget.stats.sublist(from, to)) _metric.of(day),
  ];

  @override
  Widget build(BuildContext context) {
    final stats = widget.stats;
    final days = _period.days;
    final end = stats.length;
    final current = _values(end - days, end);
    final previous = _values(end - 2 * days, end - days);
    final total = current.fold(0, (a, b) => a + b);
    final before = previous.fold(0, (a, b) => a + b);
    final selected = _selected ?? current.length - 1;
    final shown = stats[end - days + selected];
    final isToday = selected == current.length - 1;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Performance',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              _PeriodToggle(
                period: _period,
                onChanged: (value) => setState(() {
                  _period = value;
                  _selected = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final metric in StatMetric.values)
                _MetricChip(
                  metric: metric,
                  selected: metric == _metric,
                  onTap: () => setState(() => _metric = metric),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 10,
            children: [
              Text(
                compactCount(total),
                key: const Key('stat-total'),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: _metric.color,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _Delta(now: total, before: before, days: days),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            key: const Key('stat-selected'),
            isToday
                ? 'Today · ${compactCount(_metric.of(shown))}'
                : '${shortDate(shown.day)} · ${compactCount(_metric.of(shown))}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (total == 0)
            const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'No data yet. Views, likes and coins show up here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            )
          else
            _BarChart(
              key: const Key('stat-chart'),
              values: current,
              labels: [
                for (final day in stats.sublist(end - days))
                  context.tr(shortDate(day.day)),
              ],
              color: _metric.color,
              selected: selected,
              onSelect: (index) => setState(() => _selected = index),
            ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({required this.period, required this.onChanged});

  final StatPeriod period;
  final ValueChanged<StatPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final option in StatPeriod.values)
          GestureDetector(
            key: Key('period-${option.days}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(option),
            child: Container(
              height: 44,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: option == period
                      ? AppColors.primarySoft
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: option == period
                        ? AppColors.primary
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  '${option.days} days',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: option == period ? AppColors.text : AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.metric,
    required this.selected,
    required this.onTap,
  });

  final StatMetric metric;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: metric.label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        key: Key('metric-${metric.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? metric.color.withValues(alpha: 0.18)
                : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? metric.color : AppColors.border,
            ),
          ),
          child: Text(
            metric.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.text : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// How the total moved since the period before it.
class _Delta extends StatelessWidget {
  const _Delta({required this.now, required this.before, required this.days});

  final int now;
  final int before;
  final int days;

  @override
  Widget build(BuildContext context) {
    if (before == 0) {
      return Text(
        now == 0 ? 'No change' : 'New',
        style: const TextStyle(color: AppColors.muted, fontSize: 12),
      );
    }
    final percent = ((now - before) / before * 100).round();
    final up = percent >= 0;
    final color = up ? AppColors.green : AppColors.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
          color: color,
          size: 22,
        ),
        Text(
          '${percent.abs()}%',
          key: const Key('stat-delta'),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'vs previous $days days',
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ],
    );
  }
}

/// One bar a day, drawn by hand. A tap picks the bar nearest the finger.
class _BarChart extends StatelessWidget {
  const _BarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.color,
    required this.selected,
    required this.onSelect,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          'Bar chart, ${values.length} days, total '
          '${values.fold(0, (a, b) => a + b)}',
      child: SizedBox(
        height: 170,
        width: double.infinity,
        child: LayoutBuilder(
          builder: (context, box) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => onSelect(
              _BarChartPainter.indexAt(
                d.localPosition.dx,
                box.maxWidth,
                values.length,
              ),
            ),
            onHorizontalDragUpdate: (d) => onSelect(
              _BarChartPainter.indexAt(
                d.localPosition.dx,
                box.maxWidth,
                values.length,
              ),
            ),
            child: CustomPaint(
              painter: _BarChartPainter(
                values: values,
                labels: labels,
                color: color,
                selected: selected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of a chart's scale for [max]; exposed so tests can check it.
@visibleForTesting
int niceChartMax(int max) => _BarChartPainter.niceMax(max);

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({
    required this.values,
    required this.labels,
    required this.color,
    required this.selected,
  });

  final List<int> values;
  final List<String> labels;
  final Color color;
  final int selected;

  static const _padLeft = 34.0;
  static const _padBottom = 20.0;
  static const _padTop = 6.0;

  static int indexAt(double dx, double width, int count) {
    final slot = (width - _padLeft) / count;
    return ((dx - _padLeft) / slot).floor().clamp(0, count - 1);
  }

  /// The top of the scale: 1, 2 or 5 times a power of ten.
  static int niceMax(int max) {
    if (max <= 1) return 1;
    final magnitude = math.pow(10, (math.log(max) / math.ln10).floor()).toInt();
    final steps = max / magnitude;
    final nice = steps <= 1
        ? 1
        : steps <= 2
        ? 2
        : steps <= 5
        ? 5
        : 10;
    return nice * magnitude;
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.center => anchor.dx - painter.width / 2,
      _ => anchor.dx,
    };
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final chartWidth = size.width - _padLeft;
    final chartHeight = size.height - _padBottom - _padTop;
    final top = niceMax(values.fold(0, math.max));

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (final t in const [0.0, 0.5, 1.0]) {
      final y = _padTop + chartHeight * (1 - t);
      canvas.drawLine(Offset(_padLeft, y), Offset(size.width, y), grid);
      _text(
        canvas,
        compactCount((top * t).round()),
        Offset(_padLeft - 6, y),
        align: TextAlign.right,
      );
    }

    final slot = chartWidth / values.length;
    final barWidth = math.max(slot * 0.6, 3.0);
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final height = value == 0
          ? 0.0
          : math.max(chartHeight * value / top, 2.0);
      final x = _padLeft + slot * i + (slot - barWidth) / 2;
      final bar = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, _padTop + chartHeight - height, barWidth, height),
        topLeft: const Radius.circular(3),
        topRight: const Radius.circular(3),
      );
      canvas.drawRRect(
        bar,
        Paint()..color = i == selected ? color : color.withValues(alpha: 0.45),
      );
    }

    final labelY = size.height - _padBottom / 2 + 2;
    _text(canvas, labels.first, Offset(_padLeft, labelY));
    _text(
      canvas,
      labels[labels.length ~/ 2],
      Offset(_padLeft + chartWidth / 2, labelY),
      align: TextAlign.center,
    );
    _text(
      canvas,
      labels.last,
      Offset(size.width, labelY),
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.color != color ||
      old.labels != labels;
}

/// The channel's films side by side, ranked by how often they were watched.
class TopFilmsCard extends StatelessWidget {
  const TopFilmsCard({super.key, required this.films, required this.coinsOf});

  final List<Film> films;
  final int Function(Film film) coinsOf;

  @override
  Widget build(BuildContext context) {
    final ranked = [...films]
      ..sort((a, b) => b.viewCount.compareTo(a.viewCount));
    final top = ranked.take(5).toList();
    final most = top.isEmpty ? 1 : math.max(top.first.viewCount, 1);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top films',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Published films are ranked here.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final (i, film) in top.indexed)
            Padding(
              key: Key('top-film-${film.id}'),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: i == 0 ? AppColors.gold : AppColors.muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          film.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${compactCount(film.viewCount)} views',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: film.viewCount / most,
                              minHeight: 6,
                              backgroundColor: AppColors.border,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${coinsOf(film)} coins',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
