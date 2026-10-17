import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/task_widgets.dart';

class CalendarModule extends StatefulWidget {
  const CalendarModule({super.key});

  @override
  State<CalendarModule> createState() => _CalendarModuleState();
}

class _CalendarModuleState extends State<CalendarModule> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _shift(int delta) {
    final d = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = d.year;
      _month = d.month;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final showGym = LayoutScope.of(context).isOnId('workouts');
    final today = todayStr();

    // colored marks per day
    final marks = <String, List<Color>>{};
    for (final t in store.tasks) {
      final due = str(t, 'due');
      if (due.isEmpty) continue;
      final color = isDone(t) ? C.faint : (due.compareTo(today) < 0 ? C.overdue : C.deadline);
      marks.putIfAbsent(due, () => []).add(color);
    }
    if (showGym) {
      for (final l in store.logs) {
        marks.putIfAbsent(str(l, 'date'), () => []).add(C.workout);
      }
    }

    final first = DateTime(_year, _month, 1);
    final offset = first.weekday - 1;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;
    final weeks = ((offset + daysInMonth) / 7).ceil();

    return Panel(
      title: 'Календарь',
      icon: Icons.calendar_month,
      tone: C.lilac,
      trailing: TextButton(
        onPressed: () {
          final n = DateTime.now();
          setState(() {
            _year = n.year;
            _month = n.month;
          });
          store.selectDay(today);
        },
        child: const Text('Сегодня'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left), tooltip: 'Предыдущий месяц'),
              Expanded(
                child: Text(
                  '${monthsNom[_month - 1]} $_year',
                  textAlign: TextAlign.center,
                  style: display(16),
                ),
              ),
              IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right), tooltip: 'Следующий месяц'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Center(
                  child: Text(
                    weekdaysShort[i],
                    style: TextStyle(fontSize: 11.5, color: i > 4 ? C.deadline.withOpacity(.75) : C.faint),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          for (var w = 0; w < weeks; w++)
            Row(
              children: List.generate(7, (i) {
                final d = DateTime(_year, _month, 1 - offset + w * 7 + i);
                final ds = ymd(d);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2.5),
                    child: _DayCell(
                      date: d,
                      inMonth: d.month == _month,
                      isToday: ds == today,
                      selected: ds == store.selectedDay,
                      marks: marks[ds] ?? const [],
                      onTap: () {
                        store.selectDay(ds);
                        if (d.month != _month) {
                          setState(() {
                            _year = d.year;
                            _month = d.month;
                          });
                        }
                      },
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              const _Legend(C.deadline, 'Дедлайн'),
              const _Legend(C.overdue, 'Просрочено'),
              const _Legend(C.faint, 'Выполнено'),
              if (showGym) const _Legend(C.workout, 'Тренировка'),
            ],
          ),
          const Divider(height: 28),
          _DayDetails(day: store.selectedDay, showGym: showGym),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.color, this.label);
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Dot(color),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12.5, color: C.muted)),
      ]);
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.inMonth,
    required this.isToday,
    required this.selected,
    required this.marks,
    required this.onTap,
  });
  final DateTime date;
  final bool inMonth, isToday, selected;
  final List<Color> marks;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final small = c.maxWidth < 56;
      final double height = small ? c.maxWidth * 1.05 : (c.maxWidth / 1.4).clamp(52.0, 84.0).toDouble();
      final radius = BorderRadius.circular(small ? 8 : 11);
      final bg = selected
          ? C.fg
          : isToday
              ? Color.alphaBlend(C.accent.withOpacity(.14), C.surface2)
              : inMonth
                  ? C.surface2
                  : Colors.transparent;
      final numColor = selected ? C.bg : (isToday ? C.accent : (inMonth ? C.fg : C.faint));
      final shown = marks.take(4).toList();
      return Material(
        color: bg,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: height,
            padding: EdgeInsets.all(small ? 4 : 7),
            decoration: isToday && !selected ? BoxDecoration(borderRadius: radius, border: Border.all(color: C.accent)) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: small ? 11.5 : 13,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                    color: numColor,
                    fontFeatures: tabular,
                  ),
                ),
                Opacity(
                  opacity: inMonth ? 1 : .5,
                  child: Wrap(
                    spacing: 3,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final m in shown) Dot(selected && m == C.faint ? const Color(0xFF9A9CAB) : m, size: small ? 5 : 7),
                      if (marks.length > 4)
                        Text('+${marks.length - 4}', style: TextStyle(fontSize: 9, color: selected ? const Color(0xFF555555) : C.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.day, required this.showGym});
  final String day;
  final bool showGym;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final tasks = store.tasks.where((t) => str(t, 'due') == day).toList()..sort(compareDue);
    final logs = showGym ? store.logs.where((l) => str(l, 'date') == day).toList() : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(humanFull(day), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            OutlinedButton.icon(
              onPressed: () => store.prefillTask(day),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Задача'),
            ),
            if (showGym)
              OutlinedButton.icon(
                onPressed: () => store.prefillWorkout(day),
                icon: const Icon(Icons.fitness_center, size: 18),
                label: const Text('Тренировка'),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (tasks.isEmpty && logs.isEmpty) const Hint('В этот день ничего не запланировано.'),
        for (final t in tasks)
          _MiniRow(
            color: isDone(t) ? C.faint : (isOverdue(t) ? C.overdue : C.deadline),
            title: str(t, 'title'),
            sub: [if (str(t, 'time').isNotEmpty) 'до ${str(t, 'time')}', if (str(t, 'desc').isNotEmpty) str(t, 'desc')].join(' · '),
            done: isDone(t),
            onTap: () => showTaskEditor(context, t),
          ),
        for (final l in logs) _MiniRow(color: C.workout, title: store.planName(l), sub: str(l, 'note')),
      ],
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.color, required this.title, this.sub = '', this.done = false, this.onTap});
  final Color color;
  final String title;
  final String sub;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: C.surface2,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(padding: const EdgeInsets.only(top: 6), child: Dot(color)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: done ? C.faint : C.fg,
                            decoration: done ? TextDecoration.lineThrough : null,
                            decorationColor: C.faint,
                          ),
                        ),
                        if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 12.5, color: C.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
