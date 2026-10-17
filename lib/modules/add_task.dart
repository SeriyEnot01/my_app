import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/task_widgets.dart';

class AddTaskModule extends StatelessWidget {
  const AddTaskModule({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Panel(
      title: 'Новая задача',
      icon: Icons.add_task,
      tone: C.accent,
      child: TaskForm(
        // a new key resets the form when the calendar asks for "task on this day"
        key: ValueKey('add-${store.prefillTick}'),
        initialDue: store.prefillDue,
        onSubmit: (title, desc, due, time) async {
          await store.addTask(title: title, desc: desc, due: due, time: time);
          store.selectDay(due);
          if (context.mounted) toast(context, 'Задача добавлена');
        },
      ),
    );
  }
}
