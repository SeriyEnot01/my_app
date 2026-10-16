import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modules/registry.dart';

/// Which blocks are shown on the main screen and in what order (per device).
class LayoutController extends ChangeNotifier {
  LayoutController(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _orderKey = 'layout.order';
  static const _enabledKey = 'layout.enabled';
  static const defaultOn = {'stats', 'all_tasks', 'workouts', 'routine', 'notes'};

  List<String> order = [];
  Set<String> enabled = {};

  void _load() {
    final ids = allModules.map((m) => m.id).toList();
    final saved = _prefs.getStringList(_orderKey) ?? const <String>[];
    // keep the saved order, drop modules that no longer exist, append new ones at the end
    order = [...saved.where(ids.contains), ...ids.where((id) => !saved.contains(id))];
    final en = _prefs.getStringList(_enabledKey);
    enabled = en == null ? {...defaultOn} : en.toSet();
  }

  bool isOn(AppModule m) => m.core || enabled.contains(m.id);

  bool isOnId(String id) {
    final m = moduleById(id);
    return m != null && isOn(m) && m.availableHere;
  }

  List<AppModule> get visible =>
      order.map(moduleById).whereType<AppModule>().where((m) => isOn(m) && m.availableHere).toList();

  void setOn(String id, bool on) {
    if (on) {
      enabled.add(id);
    } else {
      enabled.remove(id);
    }
    _save();
  }

  void move(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    final id = order.removeAt(oldIndex);
    order.insert(newIndex, id);
    _save();
  }

  void reset() {
    order = allModules.map((m) => m.id).toList();
    enabled = {...defaultOn};
    _save();
  }

  void _save() {
    _prefs.setStringList(_orderKey, order);
    _prefs.setStringList(_enabledKey, enabled.toList());
    notifyListeners();
  }
}
