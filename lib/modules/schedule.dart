import 'dart:async';

import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/schedule.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Weekly timetable by hours: classes, meetings and other fixed things.
/// Wide block: the whole week as 7 columns. Narrow block (phone): day tabs + one column.
class ScheduleModule extends StatefulWidget {
  const ScheduleModule({super.key});

  @override
  State<ScheduleModule> createState() => _ScheduleModuleState();
}

class _ScheduleModuleState extends State<ScheduleModule> {
  late DateTime _week = mondayOf(DateTime.now());
  int _day = DateTime.now().weekday - 1; // selected day on narrow layouts
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // move the "now" line every minute
    _tick = Timer.periodic(Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _shift(int weeks) => setState(() => _week = DateTime(_week.year, _week.month, _week.day + 7 * weeks));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final events = store.events;
    final weekEnd = addDays(_week, 6);
    final parity = isoWeek(_week).isOdd ? 'нечётная' : 'чётная';
    final isThisWeek = ymd(_week) == ymd(mondayOf(DateTime.now()));
    final range = _week.month == weekEnd.month
        ? '${_week.day}–${weekEnd.day} ${monthsGen[weekEnd.month - 1]}'
        : '${_week.day} ${monthsGen[_week.month - 1]} – ${weekEnd.day} ${monthsGen[weekEnd.month - 1]}';

    return Panel(
      title: 'Расписание',
      icon: Icons.view_timeline_outlined,
      tone: C.lilac,
      trailing: IconButton.filledTonal(
        onPressed: () => showEventEditor(context, day: isThisWeek ? DateTime.now() : addDays(_week, _day)),
        icon: Icon(Icons.add, size: 20),
        tooltip: 'Добавить в расписание',
      ),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 560;
        final days = wide ? List.generate(7, (i) => addDays(_week, i)) : [addDays(_week, _day)];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              IconButton(onPressed: () => _shift(-1), icon: Icon(Icons.chevron_left), tooltip: 'Прошлая неделя'),
              Expanded(
                child: Column(children: [
                  Text(range, textAlign: TextAlign.center, style: display(14)),
                  SizedBox(height: 2),
                  Text('$parity неделя', style: TextStyle(fontSize: 12, color: C.muted)),
                ]),
              ),
              IconButton(onPressed: () => _shift(1), icon: Icon(Icons.chevron_right), tooltip: 'Следующая неделя'),
            ]),
            if (!isThisWeek)
              Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _week = mondayOf(DateTime.now());
                    _day = DateTime.now().weekday - 1;
                  }),
                  child: Text('К текущей неделе'),
                ),
              ),
            SizedBox(height: 8),
            if (!wide) _dayTabs(events),
            if (!wide) SizedBox(height: 10),
            _Timeline(days: days, events: events, showHeader: wide),
            if (events.isEmpty) ...[
              SizedBox(height: 10),
              Hint('Нажмите на пустое место в сетке или на «+», чтобы добавить пару, встречу или дело.'),
            ],
          ],
        );
      }),
    );
  }

  Widget _dayTabs(List<Item> events) {
    final today = todayStr();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final d = addDays(_week, i);
            final selected = i == _day;
            final isToday = ymd(d) == today;
            final n = eventsOn(events, d).length;
            return Padding(
              padding: EdgeInsets.only(right: 6),
              child: Material(
                color: selected ? C.accent : C.surface2,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _day = i),
                  child: Container(
                    width: 46,
                    padding: EdgeInsets.symmetric(vertical: 8),
                    decoration: isToday && !selected
                        ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: C.accent))
                        : null,
                    child: Column(children: [
                      Text(weekdaysShort[i], style: TextStyle(fontSize: 11.5, color: selected ? C.accentInk : C.muted)),
                      SizedBox(height: 2),
                      Text('${d.day}', style: TextStyle(fontWeight: FontWeight.w700, color: selected ? C.accentInk : C.fg, fontFeatures: tabular)),
                      SizedBox(height: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: n == 0 ? Colors.transparent : (selected ? C.accentInk : C.lilac),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.days, required this.events, required this.showHeader});
  final List<DateTime> days;
  final List<Item> events;
  final bool showHeader;

  static const double hourHeight = 52;
  static const double labelWidth = 42;

  @override
  Widget build(BuildContext context) {
    // visible hours: 8–20 by default, stretched to fit everything that week
    var startH = 8, endH = 20;
    for (final d in days) {
      for (final e in eventsOn(events, d)) {
        startH = startH < minutesOf(str(e, 'start')) ~/ 60 ? startH : minutesOf(str(e, 'start')) ~/ 60;
        final endM = minutesOf(str(e, 'end'));
        final eh = (endM + 59) ~/ 60;
        endH = endH > eh ? endH : eh;
      }
    }
    if (endH > 24) endH = 24;
    if (endH <= startH) endH = startH + 1;
    final hours = endH - startH;
    final height = hours * hourHeight;
    final today = todayStr();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (showHeader)
        Padding(
          padding: EdgeInsets.only(left: labelWidth, bottom: 6),
          child: Row(children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Column(children: [
                  Text(weekdaysShort[days[i].weekday - 1],
                      style: TextStyle(fontSize: 11.5, color: days[i].weekday > 5 ? C.deadline.withOpacity(.8) : C.muted)),
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: ymd(days[i]) == today ? BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(99)) : null,
                    child: Text(
                      '${days[i].day}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontFeatures: tabular,
                        color: ymd(days[i]) == today ? C.accentInk : C.fg,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      SizedBox(
        height: height + 8,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: labelWidth,
            height: height + 8,
            child: Stack(children: [
              for (var h = 0; h <= hours; h++)
                Positioned(
                  top: h * hourHeight - 7 + 4,
                  left: 0,
                  child: Text('${two(startH + h)}:00', style: TextStyle(fontSize: 10.5, color: C.faint, fontFeatures: tabular)),
                ),
            ]),
          ),
          for (final d in days)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 4),
                child: _DayColumn(day: d, events: eventsOn(events, d), startH: startH, hours: hours, isToday: ymd(d) == today),
              ),
            ),
        ]),
      ),
    ]);
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.events, required this.startH, required this.hours, required this.isToday});
  final DateTime day;
  final List<Item> events;
  final int startH;
  final int hours;
  final bool isToday;

  /// Side-by-side lanes for overlapping events.
  List<({Item e, int lane, int lanes})> _layout() {
    final out = <({Item e, int lane, int lanes})>[];
    var group = <({Item e, int lane})>[];
    var groupEnd = -1;
    void flush() {
      final lanes = group.isEmpty ? 1 : group.map((g) => g.lane).reduce((a, b) => a > b ? a : b) + 1;
      for (final g in group) {
        out.add((e: g.e, lane: g.lane, lanes: lanes));
      }
      group = [];
    }

    final laneEnds = <int>[];
    for (final e in events) {
      final s = minutesOf(str(e, 'start')), en = minutesOf(str(e, 'end'));
      if (s >= groupEnd && group.isNotEmpty) {
        flush();
        laneEnds.clear();
      }
      var lane = laneEnds.indexWhere((end) => end <= s);
      if (lane == -1) {
        lane = laneEnds.length;
        laneEnds.add(en);
      } else {
        laneEnds[lane] = en;
      }
      group.add((e: e, lane: lane));
      groupEnd = groupEnd > en ? groupEnd : en;
    }
    flush();
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const hh = _Timeline.hourHeight;
    final height = hours * hh;
    final placed = _layout();
    final now = DateTime.now();
    final nowM = now.hour * 60 + now.minute - startH * 60;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) {
          final hour = (startH + d.localPosition.dy ~/ hh).clamp(0, 23).toInt();
          showEventEditor(context, day: day, startMinutes: hour * 60);
        },
        child: Container(
          height: height,
          margin: EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: isToday ? C.accent.withOpacity(.05) : Colors.white.withOpacity(.015),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(clipBehavior: Clip.none, children: [
            for (var h = 0; h <= hours; h++)
              Positioned(top: h * hh, left: 0, right: 0, child: Container(height: 1, color: C.line.withOpacity(.6))),
            for (final p in placed)
              Builder(builder: (context) {
                final s = minutesOf(str(p.e, 'start')) - startH * 60;
                final en = minutesOf(str(p.e, 'end')) - startH * 60;
                final top = s / 60 * hh;
                var h = (en - s) / 60 * hh;
                if (h < 22) h = 22;
                if (top + h > height) h = height - top;
                if (h < 6) h = 6;
                final laneW = w / p.lanes;
                return Positioned(
                  top: top + 1,
                  left: p.lane * laneW + 1,
                  width: laneW - 2,
                  height: h - 2,
                  child: _EventTile(event: p.e, compact: laneW < 70 || h < 40),
                );
              }),
            if (isToday && nowM >= 0 && nowM <= hours * 60)
              Positioned(
                top: nowM / 60 * hh - 1,
                left: -3,
                right: 0,
                child: IgnorePointer(
                  child: Row(children: [
                    Container(width: 7, height: 7, decoration: BoxDecoration(color: C.overdue, shape: BoxShape.circle)),
                    Expanded(child: Container(height: 2, color: C.overdue)),
                  ]),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.compact});
  final Item event;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = eventColor(event);
    final place = str(event, 'place');
    return Material(
      color: Color.alphaBlend(color.withOpacity(.22), C.surface2),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showEventEditor(context, event: event),
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3))),
          padding: EdgeInsets.fromLTRB(6, 4, 4, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              str(event, 'title'),
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: C.fg, height: 1.2),
            ),
            if (!compact)
              Text(
                '${str(event, 'start')}–${str(event, 'end')}${place.isEmpty ? '' : ' · $place'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: C.muted, fontFeatures: tabular),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Add or edit a timetable entry.
Future<void> showEventEditor(BuildContext context, {Item? event, DateTime? day, int? startMinutes}) {
  final store = StoreScope.read(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _EventEditor(store: store, event: event, day: day ?? DateTime.now(), startMinutes: startMinutes),
    ),
  );
}

class _EventEditor extends StatefulWidget {
  const _EventEditor({required this.store, required this.event, required this.day, this.startMinutes});
  final AppStore store;
  final Item? event;
  final DateTime day;
  final int? startMinutes;

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  final _title = TextEditingController();
  final _place = TextEditingController();
  late bool _weekly;
  late int _weekday;
  late String _date;
  late String _parity;
  late String _start;
  late String _end;
  late int _color;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _title.text = str(e, 'title');
      _place.text = str(e, 'place');
      _weekly = str(e, 'repeat') != 'once';
      _weekday = (e['weekday'] as num?)?.toInt() ?? widget.day.weekday;
      _date = str(e, 'date').isEmpty ? ymd(widget.day) : str(e, 'date');
      _parity = str(e, 'parity').isEmpty ? 'all' : str(e, 'parity');
      _start = str(e, 'start');
      _end = str(e, 'end');
      _color = (e['color'] as num?)?.toInt() ?? 0;
    } else {
      final int s = widget.startMinutes ?? (DateTime.now().hour + 1).clamp(8, 21).toInt() * 60;
      _weekly = true;
      _weekday = widget.day.weekday;
      _date = ymd(widget.day);
      _parity = 'all';
      _start = hhmm(s);
      _end = hhmm((s + 90).clamp(0, 23 * 60 + 59).toInt());
      _color = 0;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) return setState(() => _error = 'Напишите название: например, «Матанализ» или «Встреча с командой».');
    if (minutesOf(_end) <= minutesOf(_start)) return setState(() => _error = 'Конец должен быть позже начала.');
    final Item base = widget.event ?? <String, dynamic>{'id': newId(), 'kind': 'event', 'created': DateTime.now().millisecondsSinceEpoch};
    widget.store.put({
      ...base,
      'title': title,
      'place': _place.text.trim(),
      'start': _start,
      'end': _end,
      'color': _color,
      'repeat': _weekly ? 'weekly' : 'once',
      'weekday': _weekday,
      'date': _date,
      'parity': _weekly ? _parity : 'all',
    });
    Navigator.pop(context);
  }

  Widget _segment<T>(List<(T, String)> items, T value, ValueChanged<T> onChanged) => SegmentedButton<T>(
        segments: [for (final it in items) ButtonSegment<T>(value: it.$1, label: Text(it.$2))],
        selected: {value},
        showSelectedIcon: false,
        style: ButtonStyle(visualDensity: VisualDensity.compact),
        onSelectionChanged: (s) => onChanged(s.first),
      );

  @override
  Widget build(BuildContext context) {
    final d = parseYmd(_date);
    final colors = eventColors();
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(widget.event == null ? 'Новое в расписании' : 'Изменить', style: display(17)),
        SizedBox(height: 16),
        TextField(
          controller: _title,
          autofocus: widget.event == null,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Что', hintText: 'Пара, встреча, тренировка…'),
        ),
        SizedBox(height: 10),
        TextField(
          controller: _place,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: 'Где (необязательно)', hintText: 'Ауд. 305, Zoom, офис'),
        ),
        SizedBox(height: 14),
        _segment<bool>([(true, 'Каждую неделю'), (false, 'Один раз')], _weekly, (v) => setState(() => _weekly = v)),
        SizedBox(height: 12),
        if (_weekly) ...[
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (var i = 1; i <= 7; i++)
              ChoiceChip(
                label: Text(weekdaysShort[i - 1]),
                selected: _weekday == i,
                onSelected: (_) => setState(() => _weekday = i),
                showCheckmark: false,
              ),
          ]),
          SizedBox(height: 10),
          _segment<String>([('all', 'Все недели'), ('odd', 'Нечётные'), ('even', 'Чётные')], _parity, (v) => setState(() => _parity = v)),
        ] else
          PickerField(
            label: 'Дата',
            value: '${d.day} ${monthsGen[d.month - 1]}, ${weekdaysFull[d.weekday]}',
            icon: Icons.event,
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: d, firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = ymd(picked));
            },
          ),
        SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: PickerField(
              label: 'Начало',
              value: _start,
              icon: Icons.schedule,
              onTap: () async {
                final t = await pickTime(context, _start);
                if (t == null) return;
                setState(() {
                  final len = minutesOf(_end) - minutesOf(_start);
                  _start = t;
                  if (minutesOf(_end) <= minutesOf(_start)) _end = hhmm((minutesOf(t) + (len > 0 ? len : 90)).clamp(0, 23 * 60 + 59).toInt());
                });
              },
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: PickerField(
              label: 'Конец',
              value: _end,
              icon: Icons.schedule,
              onTap: () async {
                final t = await pickTime(context, _end);
                if (t != null) setState(() => _end = t);
              },
            ),
          ),
        ]),
        SizedBox(height: 14),
        Row(children: [
          Text('Цвет', style: TextStyle(color: C.muted)),
          SizedBox(width: 12),
          for (var i = 0; i < colors.length; i++)
            GestureDetector(
              onTap: () => setState(() => _color = i),
              child: Container(
                width: 28,
                height: 28,
                margin: EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: _color == i ? C.fg : Colors.transparent, width: 2.5),
                ),
              ),
            ),
        ]),
        if (_error != null) ...[
          SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: C.overdue, fontSize: 13)),
        ],
        SizedBox(height: 16),
        Row(children: [
          FilledButton(onPressed: _save, child: Text('Сохранить')),
          Spacer(),
          if (widget.event != null)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: C.overdue),
              onPressed: () async {
                final ok = await confirmDialog(context, 'Удалить из расписания?', body: str(widget.event!, 'title'));
                if (!ok) return;
                widget.store.remove(str(widget.event!, 'id'));
                if (context.mounted) Navigator.pop(context);
              },
              icon: Icon(Icons.delete_outline, size: 18),
              label: Text('Удалить'),
            ),
        ]),
      ]),
    );
  }
}
