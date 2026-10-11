import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';

const _monthsPrep = [
  'январе', 'феврале', 'марте', 'апреле', 'мае', 'июне',
  'июле', 'августе', 'сентябре', 'октябре', 'ноябре', 'декабре',
];

class StatsModule extends StatelessWidget {
  const StatsModule({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayStr();
    final in3 = ymd(addDays(DateTime.now(), 3));
    final tasks = store.tasks;
    final todayN = tasks.where((t) => !isDone(t) && str(t, 'due') == today).length;
    final soonN = tasks.where((t) => !isDone(t) && str(t, 'due').compareTo(today) > 0 && str(t, 'due').compareTo(in3) <= 0).length;
    final overN = tasks.where(isOverdue).length;
    final month = today.substring(0, 7);
    final gymN = store.logs.where((l) => str(l, 'date').startsWith(month)).length;
    final now = DateTime.now();
    final tiles = [
      _Tile(todayN, 'на сегодня', C.deadline),
      _Tile(soonN, 'в ближайшие 3 дня', C.fg),
      _Tile(overN, 'просрочено', overN > 0 ? C.overdue : C.fg),
      _Tile(gymN, '${plural(gymN, 'тренировка', 'тренировки', 'тренировок')} в ${_monthsPrep[now.month - 1]}', C.workout),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 560 ? 4 : 2;
      final w = (c.maxWidth - 10 * (cols - 1)) / cols;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final t in tiles) SizedBox(width: w, child: t)],
      );
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile(this.n, this.label, this.color);
  final int n;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$n', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: color, fontFeatures: tabular)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted), maxLines: 2),
          ],
        ),
      );
}
