import 'package:flutter_test/flutter_test.dart';
import 'package:zadachnik/core/dates.dart';
import 'package:zadachnik/core/models.dart';

void main() {
  test('dates', () {
    expect(ymd(DateTime(2026, 3, 7)), '2026-03-07');
    expect(plural(1, 'а', 'б', 'в'), 'а');
    expect(plural(3, 'а', 'б', 'в'), 'б');
    expect(plural(11, 'а', 'б', 'в'), 'в');
  });

  test('task order: open first, then by deadline', () {
    final a = {'id': 'a', 'due': '2026-01-02', 'done': false};
    final b = {'id': 'b', 'due': '2026-01-01', 'done': true};
    final c = {'id': 'c', 'due': '2026-01-03', 'done': false};
    final list = [b, c, a]..sort(compareTasks);
    expect(list.map((t) => t['id']).toList(), ['a', 'c', 'b']);
  });
}
