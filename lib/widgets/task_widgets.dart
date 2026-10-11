import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import 'common.dart';

typedef TaskSubmit = Future<void> Function(String title, String desc, String due, String time);

/// Used both for adding a task and for editing one.
class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    this.initial,
    this.initialDue,
    required this.onSubmit,
    this.submitLabel = 'Добавить задачу',
    this.resetAfterSubmit = true,
  });
  final Item? initial;
  final String? initialDue;
  final TaskSubmit onSubmit;
  final String submitLabel;
  final bool resetAfterSubmit;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  late String _due;
  String _time = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _title.text = t == null ? '' : str(t, 'title');
    _desc.text = t == null ? '' : str(t, 'desc');
    _due = t != null && str(t, 'due').isNotEmpty ? str(t, 'due') : (widget.initialDue ?? todayStr());
    _time = t == null ? '' : str(t, 'time');
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: parseYmd(_due),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = ymd(d));
  }

  Future<void> _pickTime() async {
    final t = await pickTime(context, _time.isEmpty ? '18:00' : _time);
    if (t != null) setState(() => _time = t);
  }

  Future<void> _submit() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Напишите, что нужно сделать.');
      return;
    }
    setState(() => _error = null);
    await widget.onSubmit(title, _desc.text.trim(), _due, _time);
    if (widget.resetAfterSubmit && mounted) {
      setState(() {
        _title.clear();
        _desc.clear();
        _time = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = parseYmd(_due);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          maxLength: 200,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Задача', hintText: 'Например, сдать отчёт по проекту', counterText: ''),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PickerField(
                label: 'Дедлайн',
                value: '${d.day} ${monthsGen[d.month - 1]}, ${weekdaysShort[d.weekday - 1].toLowerCase()}',
                icon: Icons.event,
                onTap: _pickDate,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 132,
              child: PickerField(
                label: 'Время',
                value: _time.isEmpty ? 'не указано' : _time,
                icon: Icons.schedule,
                onTap: _pickTime,
                onClear: _time.isEmpty ? null : () => setState(() => _time = ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _desc,
          minLines: 2,
          maxLines: 6,
          maxLength: 2000,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Описание', hintText: 'Детали, ссылки, что нужно подготовить', counterText: ''),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: C.overdue, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
        ),
      ],
    );
  }
}

Future<void> showTaskEditor(BuildContext context, Item task) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Изменить задачу', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TaskForm(
              initial: task,
              submitLabel: 'Сохранить',
              resetAfterSubmit: false,
              onSubmit: (title, desc, due, time) async {
                await store.put({...task, 'title': title, 'desc': desc, 'due': due, 'time': time});
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, this.showDate = false});
  final Item task;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final done = isDone(task);
    final over = isOverdue(task);
    final due = str(task, 'due');
    final time = str(task, 'time');
    final desc = str(task, 'desc');
    final chips = <Widget>[
      if (over) Tag('просрочено · ${human(due)}', color: C.overdue) else if (showDate && due.isNotEmpty) Tag(rel(due), color: C.deadline),
      if (time.isNotEmpty) Tag('до $time'),
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showTaskEditor(context, task),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 2, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: done,
                activeColor: C.accent,
                checkColor: C.accentInk,
                onChanged: (_) => store.toggleDone(task),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str(task, 'title'),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: done ? C.faint : C.fg,
                          decoration: done ? TextDecoration.lineThrough : null,
                          decorationColor: C.faint,
                        ),
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(desc, style: TextStyle(fontSize: 13.5, color: done ? C.faint : C.muted)),
                      ],
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Wrap(spacing: 6, runSpacing: 6, children: chips),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: C.faint),
                tooltip: 'Удалить',
                onPressed: () async {
                  if (await confirmDialog(context, 'Удалить задачу?', body: str(task, 'title'))) {
                    store.remove(str(task, 'id'));
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
