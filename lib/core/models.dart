import 'dates.dart';

/// Records are kept as plain JSON maps, exactly as the web version stores them,
/// so fields added later (or by the web app) survive a round trip.
///   task: {id, kind:'task', title, desc, due:'YYYY-MM-DD', time:'HH:MM'|'', done, created, updated}
///   plan: {id, kind:'plan', name, exercises, created, updated}
///   log:  {id, kind:'log', date, planId, planName, note, created, updated}
typedef Item = Map<String, dynamic>;

String str(Item m, String key) => (m[key] ?? '').toString();

bool isDone(Item t) => t['done'] == true;

bool isOverdue(Item t) {
  final due = str(t, 'due');
  return !isDone(t) && due.isNotEmpty && due.compareTo(todayStr()) < 0;
}

String _dueKey(Item t) => '${str(t, 'due')}${str(t, 'time').isEmpty ? '99' : str(t, 'time')}';

int compareDue(Item a, Item b) => _dueKey(a).compareTo(_dueKey(b));

/// Open tasks first, then by deadline.
int compareTasks(Item a, Item b) {
  final d = (isDone(a) ? 1 : 0) - (isDone(b) ? 1 : 0);
  return d != 0 ? d : compareDue(a, b);
}

final validId = RegExp(r'^[A-Za-z0-9_\-.~:@+]{1,80}$');
