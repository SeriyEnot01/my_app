import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import 'common.dart';

/// The top card of the main screen: greeting, today's progress ring,
/// a few live chips and a one-line "add a task for today" field.
class HeroHeader extends StatefulWidget {
  const HeroHeader({super.key, this.wide = false});
  final bool wide;

  @override
  State<HeroHeader> createState() => _HeroHeaderState();
}

class _HeroHeaderState extends State<HeroHeader> {
  final _quick = TextEditingController();

  @override
  void dispose() {
    _quick.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _quick.text.trim();
    if (title.isEmpty) return;
    final store = StoreScope.read(context);
    await store.addTask(title: title, desc: '', due: todayStr(), time: '');
    _quick.clear();
    if (mounted) toast(context, 'Добавлено на сегодня');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final layout = LayoutScope.of(context);
    final now = DateTime.now();
    final today = todayStr();
    final tasks = store.tasks;
    final todays = tasks.where((t) => str(t, 'due') == today).toList();
    final done = todays.where(isDone).length;
    final total = todays.length;
    final overdue = tasks.where(isOverdue).length;
    final soon = tasks.where((t) {
      final d = str(t, 'due');
      return !isDone(t) && d.compareTo(today) > 0 && d.compareTo(ymd(addDays(now, 3))) <= 0;
    }).length;
    final streak = layout.isOnId('routine') ? store.routineStreak() : 0;
    final weekAgo = ymd(addDays(now, -6));
    final gym = layout.isOnId('workouts')
        ? store.logs.where((l) => str(l, 'date').compareTo(weekAgo) >= 0 && str(l, 'date').compareTo(today) <= 0).length
        : -1;
    final next = layout.isOnId('schedule') ? currentOrNext(store.events) : null;
    final h = now.hour;
    final hello = h < 5 ? 'Доброй ночи' : h < 12 ? 'Доброе утро' : h < 18 ? 'Добрый день' : 'Добрый вечер';
    final progress = total == 0 ? 0.0 : done / total;

    final chips = Wrap(spacing: 8, runSpacing: 8, children: [
      if (total == 0)
        _Chip(Icons.wb_sunny_outlined, 'Сегодня без дедлайнов', C.workout)
      else if (done == total)
        _Chip(Icons.celebration_outlined, 'Всё на сегодня сделано', C.workout)
      else
        _Chip(Icons.flag_outlined, 'Осталось сегодня: ${total - done}', C.deadline),
      if (next != null)
        _Chip(
          Icons.schedule,
          next.now
              ? 'Сейчас: ${str(next.event, 'title')} до ${str(next.event, 'end')}'
              : 'Далее: ${str(next.event, 'title')} в ${str(next.event, 'start')}',
          eventColor(next.event),
        ),
      if (overdue > 0) _Chip(Icons.error_outline, 'Просрочено: $overdue', C.overdue),
      if (soon > 0) _Chip(Icons.upcoming_outlined, 'В ближайшие 3 дня: $soon', C.accent),
      if (streak > 0) _Chip(Icons.local_fire_department_outlined, 'Рутина: $streak ${plural(streak, 'день', 'дня', 'дней')} подряд', C.sun),
      if (gym >= 0) _Chip(Icons.fitness_center, 'Тренировок за неделю: $gym', C.workout),
    ]);

    final quick = TextField(
      controller: _quick,
      textCapitalization: TextCapitalization.sentences,
      onSubmitted: (_) => _add(),
      decoration: InputDecoration(
        hintText: 'Быстрая задача на сегодня, Enter — добавить',
        fillColor: C.bg.withOpacity(.55),
        prefixIcon: Icon(Icons.bolt, color: C.sun, size: 20),
        suffixIcon: IconButton(icon: Icon(Icons.arrow_upward_rounded, size: 20), tooltip: 'Добавить', onPressed: _add),
      ),
    );

    final ring = SizedBox(
      width: widget.wide ? 132 : 92,
      height: widget.wide ? 132 : 92,
      child: Stack(fit: StackFit.expand, children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: widget.wide ? 11 : 8,
          backgroundColor: Colors.white.withOpacity(.08),
          color: total > 0 && done == total ? C.workout : C.accent,
          strokeCap: StrokeCap.round,
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(total == 0 ? '—' : '$done/$total', style: display(widget.wide ? 26 : 19, weight: FontWeight.w700)),
            SizedBox(height: 2),
            Text('сегодня', style: TextStyle(fontSize: 11.5, color: C.muted)),
          ]),
        ),
      ]),
    );

    final greeting = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(hello, style: display(widget.wide ? 32 : 24, weight: FontWeight.w700)),
      SizedBox(height: 6),
      Text(
        '${now.day} ${monthsGen[now.month - 1]}, ${weekdaysFull[now.weekday]}',
        style: TextStyle(color: C.muted, fontSize: 15),
      ),
    ]);

    return Container(
      padding: EdgeInsets.all(widget.wide ? 26 : 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [for (final c in C.p.hero) C.glass ? c.withOpacity(.80) : c],
          stops: [0, .55, 1],
        ),
        border: Border.all(color: Colors.white.withOpacity(.08)),
        boxShadow: [
          BoxShadow(color: C.accent.withOpacity(.10), blurRadius: 40, offset: Offset(0, 16)),
          BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 30, offset: Offset(0, 14)),
        ],
      ),
      child: widget.wide
          ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  greeting,
                  SizedBox(height: 18),
                  chips,
                  SizedBox(height: 18),
                  ConstrainedBox(constraints: BoxConstraints(maxWidth: 560), child: quick),
                ]),
              ),
              SizedBox(width: 28),
              ring,
              SizedBox(width: 8),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [Expanded(child: greeting), SizedBox(width: 12), ring]),
              SizedBox(height: 14),
              chips,
              SizedBox(height: 14),
              quick,
            ]),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.icon, this.label, this.color);
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(.30)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, color: Color.lerp(color, C.fg, .35), fontWeight: FontWeight.w500)),
        ]),
      );
}
