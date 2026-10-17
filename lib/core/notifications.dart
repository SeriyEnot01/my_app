import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'dates.dart';
import 'models.dart';
import 'store.dart';

/// Local deadline reminders on Android. The phone schedules them itself
/// (AlarmManager via flutter_local_notifications), so they arrive with the app closed
/// and no server is involved. Task titles never leave the device.
class Reminders {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static bool get supported => !kIsWeb && Platform.isAndroid;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static const NotificationDetails _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'deadlines',
      'Дедлайны',
      channelDescription: 'Напоминания в день дедлайна',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_notify',
      // task titles are hidden on a locked screen
      visibility: NotificationVisibility.private,
    ),
  );

  static Future<void> init() async {
    if (!supported) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')));
      _ready = true;
    } catch (e) {
      debugPrint('notifications init failed: $e');
    }
  }

  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final granted = await _android?.requestNotificationsPermission();
    return granted ?? await systemEnabled();
  }

  static Future<bool> systemEnabled() async {
    if (!_ready) return false;
    return await _android?.areNotificationsEnabled() ?? false;
  }

  static Future<void> showTest() async {
    if (!_ready) return;
    await _plugin.show(1, 'workflows', 'Так будет выглядеть напоминание о дедлайне.', _details);
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// Replaces all scheduled reminders. Returns how many were scheduled.
  static Future<int> reschedule(List<Item> tasks, {required bool enabled, required String time}) async {
    if (!_ready) return 0;
    final pending = await _plugin.pendingNotificationRequests();
    for (final p in pending) {
      await _plugin.cancel(p.id);
    }
    if (!enabled) return 0;
    final now = DateTime.now();
    final until = now.add(const Duration(days: 60));
    final plan = <({DateTime at, Item task, bool early})>[];
    for (final t in tasks) {
      if (isDone(t) || str(t, 'due').isEmpty) continue;
      final r = reminderAt(t, time);
      if (r.at.isAfter(now) && r.at.isBefore(until)) plan.add((at: r.at, task: t, early: r.early));
    }
    plan.sort((a, b) => a.at.compareTo(b.at));
    var n = 0;
    for (final p in plan.take(60)) {
      final tm = str(p.task, 'time');
      final body = tm.isEmpty ? str(p.task, 'title') : '${str(p.task, 'title')} · до $tm';
      await _plugin.zonedSchedule(
        _idFor(str(p.task, 'id')),
        p.early ? 'Через час дедлайн' : 'Сегодня дедлайн',
        body,
        tz.TZDateTime.from(p.at.toUtc(), tz.UTC),
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      n++;
    }
    return n;
  }

  static int _idFor(String id) {
    var h = 0;
    for (final c in id.codeUnits) {
      h = (h * 31 + c) & 0x3fffffff;
    }
    return h + 10;
  }
}

/// On the deadline day at [hhmm]; if the task has its own time, an hour before it when that is earlier.
({DateTime at, bool early}) reminderAt(Item t, String hhmm) {
  final d = parseYmd(str(t, 'due'));
  final p = hhmm.split(':');
  var at = DateTime(d.year, d.month, d.day, int.parse(p[0]), int.parse(p[1]));
  var early = false;
  final tm = str(t, 'time');
  if (tm.isNotEmpty) {
    final q = tm.split(':');
    final e = DateTime(d.year, d.month, d.day, int.parse(q[0]), int.parse(q[1])).subtract(const Duration(hours: 1));
    if (e.isBefore(at)) {
      at = e;
      early = true;
    }
  }
  return (at: at, early: early);
}

/// Per-device reminder settings; reschedules whenever tasks change.
class ReminderController extends ChangeNotifier {
  ReminderController(this._prefs, this._store) {
    enabled = _prefs.getBool('notify.enabled') ?? false;
    time = _prefs.getString('notify.time') ?? '09:00';
    _store.addListener(_onStore);
  }

  final SharedPreferences _prefs;
  final AppStore _store;
  late bool enabled;
  late String time;
  int scheduled = 0;
  String _signature = '';
  Timer? _debounce;

  void _onStore() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () => apply());
  }

  String _sign() {
    final parts = _store.tasks
        .where((t) => !isDone(t))
        .map((t) => '${t['id']}|${t['due']}|${t['time']}|${t['title']}')
        .toList()
      ..sort();
    return '$enabled|$time|${todayStr()}|${parts.join(';')}';
  }

  Future<void> apply({bool force = false}) async {
    if (!Reminders.supported) return;
    final sig = _sign();
    if (!force && sig == _signature) return;
    _signature = sig;
    try {
      scheduled = await Reminders.reschedule(_store.tasks, enabled: enabled, time: time);
    } catch (e) {
      debugPrint('reschedule failed: $e');
    }
    notifyListeners();
  }

  /// Returns false when the user refused notification permission.
  Future<bool> setEnabled(bool on) async {
    if (on) {
      final ok = await Reminders.requestPermission();
      if (!ok) return false;
    }
    enabled = on;
    await _prefs.setBool('notify.enabled', on);
    notifyListeners();
    await apply(force: true);
    return true;
  }

  Future<void> setTime(String hhmm) async {
    time = hhmm;
    await _prefs.setString('notify.time', hhmm);
    notifyListeners();
    await apply(force: true);
  }

  Future<void> clearForSignOut() async {
    _signature = '';
    await Reminders.cancelAll();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _store.removeListener(_onStore);
    super.dispose();
  }
}
