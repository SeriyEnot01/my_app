import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/task_widgets.dart';

class TodayModule extends StatelessWidget {
  const TodayModule({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final today = todayStr();
    final list = store.tasks.where((t) => str(t, 'due') == today || isOverdue(t)).toList()..sort(compareTasks);
    final left = list.where((t) => !isDone(t)).length;
    return Panel(
      title: 'Сегодня',
      icon: Icons.today,
      tone: C.deadline,
      count: left,
      child: list.isEmpty
          ? const EmptyNote('На сегодня дедлайнов нет. Добавьте задачу, и она появится здесь в день дедлайна.')
          : Column(children: [for (final t in list) TaskTile(key: ValueKey(t['id']), task: t)]),
    );
  }
}
