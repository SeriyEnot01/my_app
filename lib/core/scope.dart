import 'package:flutter/widgets.dart';

import 'layout.dart';
import 'notifications.dart';
import 'store.dart';
import 'theme.dart';

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  /// Rebuilds the caller when data changes.
  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  /// For callbacks: no rebuild subscription.
  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}

class LayoutScope extends InheritedNotifier<LayoutController> {
  const LayoutScope({super.key, required LayoutController layout, required super.child}) : super(notifier: layout);

  static LayoutController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<LayoutScope>()!.notifier!;
}

class ReminderScope extends InheritedNotifier<ReminderController> {
  const ReminderScope({super.key, required ReminderController controller, required super.child}) : super(notifier: controller);

  static ReminderController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ReminderScope>()!.notifier!;

  static ReminderController read(BuildContext context) => context.getInheritedWidgetOfExactType<ReminderScope>()!.notifier!;
}

class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child}) : super(notifier: controller);

  /// Call in a screen's build so it repaints in the new colours when the theme changes.
  static ThemeController of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ThemeScope>()!.notifier!;
}
