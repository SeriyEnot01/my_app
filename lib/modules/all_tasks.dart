import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/task_widgets.dart';

class AllTasksModule extends StatefulWidget {
  const AllTasksModule({super.key});

  @override
  State<AllTasksModule> createState() => _AllTasksModuleState();
}

class _AllTasksModuleState extends State<AllTasksModule> {
  bool _open = false;
  bool _hideDone = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.tasks..sort(compareTasks);
    final done = all.where(isDone).length;
    final list = _hideDone ? all.where((t) => !isDone(t)).toList() : all;
    return Panel(
      title: 'Все задачи',
      icon: Icons.list_alt,
      tone: C.muted,
      count: all.length,
      trailing: TextButton(onPressed: () => setState(() => _open = !_open), child: Text(_open ? 'Свернуть' : 'Показать')),
      child: !_open
          ? Hint('Задач: ${all.length}, выполнено: $done.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Checkbox(value: _hideDone, onChanged: (v) => setState(() => _hideDone = v ?? false)),
                  Text('Скрыть выполненные'),
                ]),
                SizedBox(height: 6),
                if (list.isEmpty) EmptyNote('Пока пусто.'),
                for (final t in list) TaskTile(key: ValueKey(t['id']), task: t, showDate: true),
              ],
            ),
    );
  }
}
