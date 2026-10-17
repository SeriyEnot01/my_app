import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const _free = '__free';

class WorkoutsModule extends StatefulWidget {
  const WorkoutsModule({super.key});

  @override
  State<WorkoutsModule> createState() => _WorkoutsModuleState();
}

class _WorkoutsModuleState extends State<WorkoutsModule> {
  int _tab = 0;
  int _seenPrefill = 0;

  // log form
  String _date = todayStr();
  String? _planId;
  bool _planTouched = false;
  final _note = TextEditingController();
  int _showLogs = 20;

  // plan form
  final _pName = TextEditingController();
  final _pEx = TextEditingController();
  String? _editingPlan;
  String? _pError;

  @override
  void dispose() {
    _note.dispose();
    _pName.dispose();
    _pEx.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.workoutPrefillTick != _seenPrefill) {
      _seenPrefill = store.workoutPrefillTick;
      if (store.workoutPrefillDate != null) {
        _date = store.workoutPrefillDate!;
        _tab = 0;
      }
    }
    return Panel(
      title: 'Тренировки',
      icon: Icons.fitness_center,
      tone: C.workout,
      trailing: SegmentedButton<int>(
        segments: [
          ButtonSegment(value: 0, label: Text('Журнал')),
          ButtonSegment(value: 1, label: Text('План')),
        ],
        selected: {_tab},
        showSelectedIcon: false,
        style: ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      ),
      child: _tab == 0 ? _logView(context) : _planView(context),
    );
  }

  // ---------------------------------------------------------------- journal
  Widget _logView(BuildContext context) {
    final store = StoreScope.of(context);
    final plans = store.plans;
    final logs = store.logs;
    final planIds = plans.map((p) => str(p, 'id')).toSet();
    if (!_planTouched || (_planId != _free && !planIds.contains(_planId))) {
      _planId = plans.isNotEmpty ? str(plans.last, 'id') : _free;
    }
    final days = logs.map((l) => str(l, 'date')).toSet();
    final now = DateTime.now();
    final d = parseYmd(_date);

    final dateField = PickerField(
      label: 'Дата',
      value: '${d.day} ${monthsGen[d.month - 1]}',
      icon: Icons.event,
      onTap: () async {
        final picked = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
        if (picked != null) setState(() => _date = ymd(picked));
      },
    );
    final planField = DropdownButtonFormField<String>(
      value: _planId,
      isExpanded: true,
      decoration: InputDecoration(labelText: 'Тренировка'),
      dropdownColor: C.surface2,
      items: [
        for (final p in plans)
          DropdownMenuItem(value: str(p, 'id'), child: Text(str(p, 'name'), overflow: TextOverflow.ellipsis)),
        DropdownMenuItem(value: _free, child: Text('Другое / свободная')),
      ],
      onChanged: (v) => setState(() {
        _planId = v;
        _planTouched = true;
      }),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // last 28 days
        Row(
          children: List.generate(28, (i) {
            final ds = ymd(addDays(now, i - 27));
            return Expanded(
              child: Tooltip(
                message: human(ds) + (days.contains(ds) ? ': тренировка' : ''),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 1.5),
                  height: 24,
                  decoration: BoxDecoration(
                    color: days.contains(ds) ? C.workout : C.surface2,
                    borderRadius: BorderRadius.circular(5),
                    border: i == 27 ? Border.all(color: C.accent) : null,
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
            Text('4 недели назад', style: TextStyle(fontSize: 11, color: C.faint)),
            Text('сегодня', style: TextStyle(fontSize: 11, color: C.faint)),
          ],
        ),
        SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          if (c.maxWidth < 420) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [dateField, SizedBox(height: 10), planField]);
          }
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 170, child: dateField),
            SizedBox(width: 10),
            Expanded(child: planField),
          ]);
        }),
        SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Заметка', hintText: 'Веса, самочувствие, что получилось', counterText: ''),
        ),
        SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: tealButton(),
            onPressed: () {
              final plan = _planId == _free ? null : store.items[_planId];
              store.put({
                'id': newId(),
                'kind': 'log',
                'date': _date,
                'planId': plan == null ? '' : _planId,
                'planName': plan == null ? 'Свободная тренировка' : str(plan, 'name'),
                'note': _note.text.trim(),
                'created': DateTime.now().millisecondsSinceEpoch,
              });
              _note.clear();
              toast(context, 'Тренировка отмечена');
            },
            child: Text('Отметить тренировку'),
          ),
        ),
        SizedBox(height: 18),
        SectionLabel('История'),
        SizedBox(height: 8),
        if (logs.isEmpty) EmptyNote('Тренировок пока нет. Выберите дату и тип, нажмите «Отметить тренировку».'),
        for (final l in logs.take(_showLogs)) _LogRow(log: l),
        if (logs.length > _showLogs)
          TextButton(onPressed: () => setState(() => _showLogs += 30), child: Text('Показать ещё (${logs.length - _showLogs})')),
      ],
    );
  }

  // ---------------------------------------------------------------- plan
  void _savePlan(BuildContext context) {
    final store = StoreScope.read(context);
    final name = _pName.text.trim();
    if (name.isEmpty) {
      setState(() => _pError = 'Дайте тренировке название.');
      return;
    }
    final base = _editingPlan != null && store.items[_editingPlan] != null
        ? store.items[_editingPlan]!
        : <String, dynamic>{'id': newId(), 'kind': 'plan', 'created': DateTime.now().millisecondsSinceEpoch};
    store.put({...base, 'name': name, 'exercises': _pEx.text.trim()});
    _resetPlanForm();
  }

  void _resetPlanForm() {
    setState(() {
      _editingPlan = null;
      _pError = null;
      _pName.clear();
      _pEx.clear();
    });
  }

  Widget _planView(BuildContext context) {
    final store = StoreScope.of(context);
    final plans = store.plans;
    final logs = store.logs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pName,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Название тренировки', hintText: 'Например, Верх тела', counterText: ''),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _pEx,
          minLines: 3,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: 'Упражнения, каждое с новой строки',
            hintText: 'Жим лёжа 4×8\nТяга штанги в наклоне 4×10\nОтжимания на брусьях 3×12',
            alignLabelWithHint: true,
          ),
        ),
        if (_pError != null) ...[
          SizedBox(height: 8),
          Text(_pError!, style: TextStyle(color: C.overdue, fontSize: 13)),
        ],
        SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton(
            style: tealButton(),
            onPressed: () => _savePlan(context),
            child: Text(_editingPlan == null ? 'Сохранить в план' : 'Сохранить изменения'),
          ),
          if (_editingPlan != null) OutlinedButton(onPressed: _resetPlanForm, child: Text('Отмена')),
        ]),
        SizedBox(height: 18),
        SectionLabel('Мой план'),
        SizedBox(height: 8),
        if (plans.isEmpty) EmptyNote('Опишите свои тренировки: название и упражнения. Потом их можно выбирать в журнале.'),
        for (final p in plans)
          _PlanCard(
            plan: p,
            lastDate: _lastDateFor(logs, str(p, 'id')),
            onEdit: () => setState(() {
              _editingPlan = str(p, 'id');
              _pName.text = str(p, 'name');
              _pEx.text = str(p, 'exercises');
              _pError = null;
            }),
          ),
      ],
    );
  }
}

/// Logs are sorted newest first, so the first match is the latest date.
String? _lastDateFor(List<Map<String, dynamic>> logs, String planId) {
  for (final l in logs) {
    if (str(l, 'planId') == planId) return str(l, 'date');
  }
  return null;
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final d = parseYmd(str(log, 'date'));
    final note = str(log, 'note');
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${two(d.day)}.${two(d.month)}', style: TextStyle(color: C.workout, fontSize: 13, fontFeatures: tabular)),
              Text(weekdaysShort[d.weekday - 1], style: TextStyle(color: C.faint, fontSize: 11.5)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(store.planName(log), style: TextStyle(fontWeight: FontWeight.w600)),
              if (note.isNotEmpty) Text(note, style: TextStyle(fontSize: 13, color: C.muted)),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: C.faint),
            tooltip: 'Удалить',
            onPressed: () async {
              if (await confirmDialog(context, 'Удалить запись о тренировке?')) store.remove(str(log, 'id'));
            },
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.lastDate, required this.onEdit});
  final Map<String, dynamic> plan;
  final String? lastDate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final ex = str(plan, 'exercises').split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: C.surface2,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 3, color: C.workout),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 8, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(str(plan, 'name'), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                          IconButton(icon: Icon(Icons.edit_outlined, size: 18, color: C.muted), tooltip: 'Изменить', onPressed: onEdit),
                          IconButton(
                            icon: Icon(Icons.close, size: 18, color: C.faint),
                            tooltip: 'Удалить',
                            onPressed: () async {
                              if (await confirmDialog(context, 'Удалить тренировку из плана?', body: str(plan, 'name'))) {
                                store.remove(str(plan, 'id'));
                              }
                            },
                          ),
                        ]),
                        if (ex.isEmpty) Hint('Без упражнений'),
                        for (var i = 0; i < ex.length; i++)
                          Padding(
                            padding: EdgeInsets.only(bottom: 2),
                            child: Text('${i + 1}. ${ex[i]}', style: TextStyle(fontSize: 13.5, color: C.muted)),
                          ),
                        SizedBox(height: 6),
                        Text(
                          lastDate == null ? 'ещё не выполнялась' : 'последняя: ${rel(lastDate!)}',
                          style: TextStyle(fontSize: 11.5, color: C.faint),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
