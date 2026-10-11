import 'dart:math';

const monthsNom = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];
const monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Indexed by DateTime.weekday (1 = Monday ... 7 = Sunday).
const weekdaysFull = ['', 'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];

String two(int n) => n.toString().padLeft(2, '0');

String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';

DateTime parseYmd(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String todayStr() => ymd(DateTime.now());

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

String human(String s) {
  final d = parseYmd(s);
  return '${d.day} ${monthsGen[d.month - 1]}';
}

String humanFull(String s) {
  final d = parseYmd(s);
  return '${d.day} ${monthsGen[d.month - 1]}, ${weekdaysFull[d.weekday]}';
}

int daysFromToday(String s) {
  final a = parseYmd(s), b = parseYmd(todayStr());
  return DateTime.utc(a.year, a.month, a.day).difference(DateTime.utc(b.year, b.month, b.day)).inDays;
}

String rel(String s) {
  switch (daysFromToday(s)) {
    case 0:
      return 'сегодня';
    case 1:
      return 'завтра';
    case 2:
      return 'послезавтра';
    case -1:
      return 'вчера';
    default:
      return human(s);
  }
}

String plural(int n, String one, String few, String many) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 10 || m100 >= 20)) return few;
  return many;
}

final _rnd = Random.secure();

/// Same shape as the web version: time in base36 + 6 random base36 chars.
String newId() {
  final t = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
  final r = List.generate(6, (_) => _rnd.nextInt(36).toRadixString(36)).join();
  return '$t$r';
}
