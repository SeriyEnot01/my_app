import 'package:flutter/material.dart';

import 'dates.dart';
import 'models.dart';
import 'theme.dart';

/// Timetable entries (kind 'event'):
///   {id, kind:'event', title, place, start:'HH:MM', end:'HH:MM', color:0..5,
///    repeat:'weekly'|'once', weekday:1..7 (weekly), date:'YYYY-MM-DD' (once),
///    parity:'all'|'odd'|'even' (weekly: every week / odd ISO weeks / even ISO weeks), created, updated}

/// ISO-8601 week number (weeks start on Monday, week 1 contains the first Thursday).
int isoWeek(DateTime d) {
  final date = DateTime.utc(d.year, d.month, d.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final jan1 = DateTime.utc(thursday.year, 1, 1);
  return thursday.difference(jan1).inDays ~/ 7 + 1;
}

DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));

bool occursOn(Item e, DateTime day) {
  if (str(e, 'repeat') == 'once') return str(e, 'date') == ymd(day);
  if ((e['weekday'] ?? 0) != day.weekday) return false;
  final parity = str(e, 'parity');
  if (parity == 'odd') return isoWeek(day).isOdd;
  if (parity == 'even') return isoWeek(day).isEven;
  return true;
}

int minutesOf(String hhmm) {
  final p = hhmm.split(':');
  if (p.length != 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

String hhmm(int minutes) => '${two(minutes ~/ 60)}:${two(minutes % 60)}';

/// Events on a day, sorted by start time.
List<Item> eventsOn(Iterable<Item> events, DateTime day) =>
    events.where((e) => occursOn(e, day)).toList()..sort((a, b) => minutesOf(str(a, 'start')).compareTo(minutesOf(str(b, 'start'))));

List<Color> eventColors() => [C.accent, C.workout, C.deadline, C.lilac, C.sun, C.overdue];

Color eventColor(Item e) {
  final list = eventColors();
  final i = (e['color'] as num?)?.toInt() ?? 0;
  return list[i.clamp(0, list.length - 1)];
}

/// The event happening now, or the next one later today.
({Item event, bool now})? currentOrNext(Iterable<Item> events) {
  final now = DateTime.now();
  final m = now.hour * 60 + now.minute;
  for (final e in eventsOn(events, now)) {
    final s = minutesOf(str(e, 'start')), en = minutesOf(str(e, 'end'));
    if (s <= m && m < en) return (event: e, now: true);
    if (s > m) return (event: e, now: false);
  }
  return null;
}
