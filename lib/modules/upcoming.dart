import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/task_widgets.dart';

class UpcomingModule extends StatelessWidget {
  const UpcomingModule({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tasks = store.tasks;
    var open = 0;
    final groups = <Widget>[];
    for (var i = 1; i <= 3; i++) {
      final ds = ymd(addDays(DateTime.now(), i));
      final list = tasks.where((t) => str(t, 'due') == ds).toList()..sort(compareTasks);
      open += list.where((t) => !isDone(t)).length;
      groups.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8, top: 2),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                  text: rel(ds).toUpperCase(),
                  style: const TextStyle(fontSize: 12, letterSpacing: 1, color: C.muted, fontWeight: FontWeight.w500),
                ),
                TextSpan(text: '   ${humanFull(ds)}', style: const TextStyle(fontSize: 12.5, color: C.faint)),
              ])),
            ),
            if (list.isEmpty)
              const Padding(padding: EdgeInsets.only(left: 2, bottom: 6), child: Hint('Свободно'))
            else
              for (final t in list) TaskTile(key: ValueKey(t['id']), task: t),
          ],
        ),
      ));
    }
    return Panel(
      title: 'Ближайшие 3 дня',
      icon: Icons.upcoming_outlined,
      tone: C.accent,
      count: open,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: groups),
    );
  }
}
