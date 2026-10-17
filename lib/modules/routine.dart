import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Morning routine: the same checklist every day. Ticks are stored per day
/// ('routine-YYYY-MM-DD'), so tomorrow starts clean and history stays.
class RoutineModule extends StatefulWidget {
  const RoutineModule({super.key});

  @override
  State<RoutineModule> createState() => _RoutineModuleState();
}

class _RoutineModuleState extends State<RoutineModule> {
  bool _editing = false;
  final _newStep = TextEditingController();

  @override
  void dispose() {
    _newStep.dispose();
    super.dispose();
  }

  Set<String> _doneOn(AppStore store, String date) {
    final d = store.routineDay(date);
    final list = d?['done'];
    return list is List ? list.map((e) => e.toString()).toSet() : <String>{};
  }

  bool _completeOn(AppStore store, String date) => store.routineDay(date)?['complete'] == true;

  void _toggle(AppStore store, String stepId, List<Item> steps) {
    final today = todayStr();
    final done = _doneOn(store, today);
    if (!done.remove(stepId)) done.add(stepId);
    final ids = steps.map((s) => str(s, 'id')).toSet();
    final kept = done.where(ids.contains).toList();
    store.put({
      ...?store.routineDay(today),
      'id': 'routine-$today',
      'kind': 'routine_day',
      'date': today,
      'done': kept,
      'complete': ids.isNotEmpty && kept.length == ids.length,
    });
  }

  void _addStep(AppStore store, List<Item> steps) {
    final title = _newStep.text.trim();
    if (title.isEmpty) return;
    final maxOrder = steps.isEmpty ? 0 : steps.map((s) => (s['order'] ?? 0) as num).reduce((a, b) => a > b ? a : b);
    store.put({
      'id': newId(),
      'kind': 'routine_item',
      'title': title,
      'order': maxOrder + 1,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    _newStep.clear();
  }

  void _reorder(AppStore store, List<Item> steps, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final list = [...steps];
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex, moved);
    for (var i = 0; i < list.length; i++) {
      if ((list[i]['order'] ?? -1) != i) store.put({...list[i], 'order': i});
    }
  }

  Future<void> _rename(BuildContext context, AppStore store, Item step) async {
    final c = TextEditingController(text: str(step, 'title'));
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Изменить шаг', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text('Сохранить')),
        ],
      ),
    );
    c.dispose();
    if (title != null && title.trim().isNotEmpty) store.put({...step, 'title': title.trim()});
  }

  int _streak(AppStore store) {
    var day = DateTime.now();
    // today still in progress does not break the streak
    if (!_completeOn(store, ymd(day))) day = addDays(day, -1);
    var n = 0;
    while (_completeOn(store, ymd(day)) && n < 3650) {
      n++;
      day = addDays(day, -1);
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final steps = store.routineSteps;
    final today = todayStr();
    final done = _doneOn(store, today);
    final doneCount = steps.where((s) => done.contains(str(s, 'id'))).length;
    final total = steps.length;
    final streak = _streak(store);

    return Panel(
      title: 'Утренняя рутина',
      icon: Icons.wb_twilight,
      tone: C.sun,
      trailing: TextButton.icon(
        onPressed: () => setState(() => _editing = !_editing),
        icon: Icon(_editing ? Icons.check : Icons.edit_outlined, size: 18),
        label: Text(_editing ? 'Готово' : 'Изменить'),
      ),
      child: _editing ? _editor(context, store, steps) : _checklist(store, steps, done, doneCount, total, streak),
    );
  }

  Widget _checklist(AppStore store, List<Item> steps, Set<String> done, int doneCount, int total, int streak) {
    if (steps.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EmptyNote('Составьте список того, что делаете каждое утро: стакан воды, зарядка, душ, план на день…'),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: () => setState(() => _editing = true), child: Text('Составить рутину')),
        ),
      ]);
    }
    final now = DateTime.now();
    final all = doneCount == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text('$doneCount из $total', style: TextStyle(fontWeight: FontWeight.w600, fontFeatures: tabular)),
          Spacer(),
          if (streak > 0)
            Text(
              'Серия: $streak ${plural(streak, 'день', 'дня', 'дней')}',
              style: TextStyle(color: C.accent, fontSize: 13),
            ),
        ]),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : doneCount / total,
            minHeight: 8,
            backgroundColor: C.surface2,
            color: all ? C.workout : C.accent,
          ),
        ),
        SizedBox(height: 12),
        for (final s in steps)
          Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Material(
              color: C.surface2,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _toggle(store, str(s, 'id'), steps),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(4, 2, 12, 2),
                  child: Row(children: [
                    Checkbox(
                      value: done.contains(str(s, 'id')),
                      activeColor: C.accent,
                      checkColor: C.accentInk,
                      onChanged: (_) => _toggle(store, str(s, 'id'), steps),
                    ),
                    Expanded(
                      child: Text(
                        str(s, 'title'),
                        style: TextStyle(
                          color: done.contains(str(s, 'id')) ? C.faint : C.fg,
                          decoration: done.contains(str(s, 'id')) ? TextDecoration.lineThrough : null,
                          decorationColor: C.faint,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        if (all) ...[
          SizedBox(height: 6),
          Text('Утро прошло по плану. Отличное начало дня!', style: TextStyle(color: C.workout)),
        ],
        SizedBox(height: 14),
        // last 14 days: full = everything done, faint = partly done
        Row(
          children: List.generate(14, (i) {
            final ds = ymd(addDays(now, i - 13));
            final day = store.routineDay(ds);
            final complete = day?['complete'] == true;
            final partial = !complete && day?['done'] is List && (day!['done'] as List).isNotEmpty;
            return Expanded(
              child: Tooltip(
                message: human(ds) + (complete ? ': всё сделано' : partial ? ': частично' : ''),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 1.5),
                  height: 18,
                  decoration: BoxDecoration(
                    color: complete ? C.accent : (partial ? C.accent.withOpacity(.35) : C.surface2),
                    borderRadius: BorderRadius.circular(4),
                    border: i == 13 ? Border.all(color: C.fg.withOpacity(.6)) : null,
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('2 недели назад', style: TextStyle(fontSize: 11, color: C.faint)),
            Text('сегодня', style: TextStyle(fontSize: 11, color: C.faint)),
          ],
        ),
      ],
    );
  }

  Widget _editor(BuildContext context, AppStore store, List<Item> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (steps.isNotEmpty) ...[
          Hint('Перетащите за ручку, чтобы поменять порядок. Нажмите на шаг, чтобы переименовать.'),
          SizedBox(height: 8),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: steps.length,
            onReorder: (o, n) => _reorder(store, steps, o, n),
            itemBuilder: (context, i) {
              final s = steps[i];
              return Padding(
                key: ValueKey(str(s, 'id')),
                padding: EdgeInsets.only(bottom: 6),
                child: Material(
                  color: C.surface2,
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.only(left: 4, right: 4),
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: Padding(padding: EdgeInsets.all(8), child: Icon(Icons.drag_handle, color: C.muted)),
                    ),
                    title: Text(str(s, 'title')),
                    onTap: () => _rename(context, store, s),
                    trailing: IconButton(
                      icon: Icon(Icons.close, size: 18, color: C.faint),
                      tooltip: 'Удалить шаг',
                      onPressed: () async {
                        if (await confirmDialog(context, 'Удалить шаг из рутины?', body: str(s, 'title'))) {
                          store.remove(str(s, 'id'));
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 8),
        ],
        Row(children: [
          Expanded(
            child: TextField(
              controller: _newStep,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: 'Новый шаг', hintText: 'Например, стакан воды', counterText: ''),
              onSubmitted: (_) => _addStep(store, steps),
            ),
          ),
          SizedBox(width: 8),
          IconButton.filled(
            onPressed: () => _addStep(store, steps),
            icon: Icon(Icons.add),
            tooltip: 'Добавить шаг',
          ),
        ]),
      ],
    );
  }
}
