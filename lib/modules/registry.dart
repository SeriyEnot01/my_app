import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'add_task.dart';
import 'all_tasks.dart';
import 'backup.dart';
import 'calendar.dart';
import 'mascot.dart';
import 'notes.dart';
import 'reminders.dart';
import 'routine.dart';
import 'schedule.dart';
import 'stats.dart';
import 'today.dart';
import 'upcoming.dart';
import 'workouts.dart';

/// A block on the main screen.
///
/// To add a new module:
///   1. create lib/modules/my_module.dart with a widget (wrap it in Panel from widgets/common.dart);
///   2. add one AppModule(...) entry to [allModules] below.
/// It then shows up in «Блоки на экране» with a checkbox and can be dragged into place.
class AppModule {
  const AppModule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
    this.core = false,
    this.androidOnly = false,
  });

  /// Stable id, saved in settings. Never rename an existing one.
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Widget Function() builder;

  /// Core blocks are always on; they can still be moved.
  final bool core;
  final bool androidOnly;

  bool get availableHere => !androidOnly || (!kIsWeb && Platform.isAndroid);
}

final List<AppModule> allModules = [
  AppModule(
    id: 'add_task',
    title: 'Новая задача',
    description: 'Добавление задачи с дедлайном и описанием',
    icon: Icons.add_task,
    core: true,
    builder: () => AddTaskModule(),
  ),
  AppModule(
    id: 'today',
    title: 'Сегодня',
    description: 'Задачи с дедлайном на сегодня и просроченные',
    icon: Icons.today,
    core: true,
    builder: () => TodayModule(),
  ),
  AppModule(
    id: 'upcoming',
    title: 'Ближайшие 3 дня',
    description: 'Задачи на завтра, послезавтра и следующий день',
    icon: Icons.upcoming,
    core: true,
    builder: () => UpcomingModule(),
  ),
  AppModule(
    id: 'calendar',
    title: 'Календарь',
    description: 'Месяц с цветными отметками дедлайнов и тренировок',
    icon: Icons.calendar_month,
    core: true,
    builder: () => CalendarModule(),
  ),
  AppModule(
    id: 'schedule',
    title: 'Расписание',
    description: 'По часам на неделю: пары, встречи, дела; чётные и нечётные недели',
    icon: Icons.view_timeline_outlined,
    builder: () => ScheduleModule(),
  ),
  AppModule(
    id: 'stats',
    title: 'Сводка',
    description: 'Сколько задач сегодня, на 3 дня, просрочено и тренировок за месяц',
    icon: Icons.insights,
    builder: () => StatsModule(),
  ),
  AppModule(
    id: 'all_tasks',
    title: 'Все задачи',
    description: 'Полный список задач',
    icon: Icons.list_alt,
    builder: () => AllTasksModule(),
  ),
  AppModule(
    id: 'workouts',
    title: 'Тренировки',
    description: 'План тренировок и журнал по датам',
    icon: Icons.fitness_center,
    builder: () => WorkoutsModule(),
  ),
  AppModule(
    id: 'routine',
    title: 'Утренняя рутина',
    description: 'Список дел на каждое утро: отмечайте шаги, серия дней подряд',
    icon: Icons.wb_twilight,
    builder: () => RoutineModule(),
  ),
  AppModule(
    id: 'notes',
    title: 'Заметки',
    description: 'Быстрые заметки без даты, как «Избранное» в Telegram',
    icon: Icons.sticky_note_2_outlined,
    builder: () => NotesModule(),
  ),
  AppModule(
    id: 'mascot',
    title: 'Талисман',
    description: 'Ваша гифка и подбадривающие сообщения',
    icon: Icons.emoji_emotions_outlined,
    builder: () => MascotModule(),
  ),
  AppModule(
    id: 'reminders',
    title: 'Напоминания',
    description: 'Уведомления в день дедлайна',
    icon: Icons.notifications_active_outlined,
    androidOnly: true,
    builder: () => RemindersModule(),
  ),
  AppModule(
    id: 'backup',
    title: 'Резервная копия',
    description: 'Сохранение задач в файл и загрузка из файла',
    icon: Icons.save_alt,
    builder: () => BackupModule(),
  ),
];

AppModule? moduleById(String id) {
  for (final m in allModules) {
    if (m.id == id) return m;
  }
  return null;
}
