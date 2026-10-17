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
      _Tile(todayN, 'на сегодня', C.deadline, Icons.flag_outlined),
      _Tile(soonN, 'в ближайшие 3 дня', C.accent, Icons.upcoming_outlined),
      _Tile(overN, 'просрочено', overN > 0 ? C.overdue : C.muted, Icons.error_outline),
      _Tile(gymN, '${plural(gymN, 'тренировка', 'тренировки', 'тренировок')} в ${_monthsPrep[now.month - 1]}', C.workout, Icons.fitness_center),
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
  const _Tile(this.n, this.label, this.color, this.icon);
  final int n;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.alphaBlend(color.withOpacity(.14), C.surface), C.surface],
          ),
          border: Border.all(color: color.withOpacity(.22)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n', style: display(28, weight: FontWeight.w700, color: color == C.muted ? C.fg : color)),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted), maxLines: 2),
                ],
              ),
            ),
            Icon(icon, size: 20, color: color.withOpacity(.8)),
          ],
        ),
      );
}
