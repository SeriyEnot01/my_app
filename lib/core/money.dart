import 'package:flutter/material.dart';

import 'dates.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';

/// Money records (amounts are entered by the user, nothing is connected to a bank):
///   bill: {id, kind:'bill', title, amount, type:'expense'|'income', period:'month'|'year',
///          day:1..31, month:1..12 (year only), paid:['2026-10' | '2026', ...], note, created, updated}
///   txn:  {id, kind:'txn', date:'YYYY-MM-DD', amount, type:'expense'|'income', cat, note, created, updated}
/// Preferences live in the synced profile record: currency, ledgerBills (include bills in month totals).

const currencies = ['₽', '\$', '€', '₸', '₴', 'Br', '£', '¥'];

String currencyOf(AppStore store) {
  final c = str(store.items['profile'] ?? <String, dynamic>{}, 'currency');
  return c.isEmpty ? '₽' : c;
}

/// Parses "1 500,50", "1500.5", "1,500" → 1500.5. Null when it is not a positive amount.
double? parseAmount(String raw) {
  var s = raw.replaceAll(RegExp(r'[\s  ₽$€₸₴£¥]'), '').replaceAll('Br', '');
  if (s.isEmpty) return null;
  // both separators: the comma groups thousands ("1,500.50"); a lone comma is the decimal mark
  if (s.contains(',') && s.contains('.')) {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceAll(',', '.');
  }
  final v = double.tryParse(s);
  if (v == null || v <= 0 || v >= 1e10 || v.isNaN) return null;
  return (v * 100).round() / 100;
}

double amountOf(Item m) => ((m['amount'] ?? 0) as num).toDouble();

bool isIncome(Item m) => str(m, 'type') == 'income';

/// 1234567.5 → "1 234 567,50 ₽"; whole numbers without kopecks.
String money(num v, String currency, {bool sign = false}) {
  final neg = v < 0;
  final abs = v.abs();
  final whole = abs.truncate();
  final cents = ((abs - whole) * 100).round();
  final digits = whole.toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(' ');
    b.write(digits[i]);
  }
  var out = b.toString();
  if (cents > 0) out += ',${two(cents)}';
  final prefix = neg ? '−' : (sign ? '+' : '');
  return '$prefix$out $currency';
}

int daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

// ---------------------------------------------------------------- regular payments

bool billYearly(Item b) => str(b, 'period') == 'year';

int _int(Item m, String k, int def) => (m[k] as num?)?.toInt() ?? def;

/// The bill's date inside the period that contains [ref].
DateTime billDateIn(Item b, int year, int month) {
  final m = billYearly(b) ? _int(b, 'month', 1).clamp(1, 12).toInt() : month;
  final d = _int(b, 'day', 1).clamp(1, 31).toInt();
  return DateTime(year, m, d.clamp(1, daysInMonth(year, m)).toInt());
}

String periodKey(Item b, DateTime d) => billYearly(b) ? '${d.year}' : '${d.year}-${two(d.month)}';

bool isPaidFor(Item b, DateTime d) => ((b['paid'] as List?) ?? const []).contains(periodKey(b, d));

/// Next date that still needs attention: the current period's date if it is not marked yet
/// (it may already be in the past = overdue), otherwise the next period's date.
({DateTime date, bool overdue}) billNext(Item b, DateTime today) {
  final t = DateTime(today.year, today.month, today.day);
  var d = billDateIn(b, t.year, t.month);
  if (isPaidFor(b, d)) {
    d = billYearly(b) ? billDateIn(b, t.year + 1, 1) : billDateIn(b, t.month == 12 ? t.year + 1 : t.year, t.month == 12 ? 1 : t.month + 1);
    return (date: d, overdue: false);
  }
  return (date: d, overdue: d.isBefore(t));
}

/// Does the bill fall into this calendar month?
bool billInMonth(Item b, int year, int month) => !billYearly(b) || _int(b, 'month', 1) == month;

/// Monthly equivalent: yearly amounts divided by 12.
double billPerMonth(Item b) => billYearly(b) ? amountOf(b) / 12 : amountOf(b);

// ---------------------------------------------------------------- categories

class MoneyCat {
  const MoneyCat(this.name, this.icon, this.tone);
  final String name;
  final IconData icon;
  /// index into [catColors]
  final int tone;
}

const expenseCats = [
  MoneyCat('Продукты', Icons.shopping_basket_outlined, 0),
  MoneyCat('Кафе', Icons.restaurant_outlined, 1),
  MoneyCat('Транспорт', Icons.directions_bus_outlined, 2),
  MoneyCat('Дом', Icons.home_outlined, 3),
  MoneyCat('Связь и подписки', Icons.wifi_outlined, 4),
  MoneyCat('Здоровье', Icons.healing_outlined, 5),
  MoneyCat('Одежда', Icons.checkroom_outlined, 3),
  MoneyCat('Развлечения', Icons.sports_esports_outlined, 1),
  MoneyCat('Учёба', Icons.school_outlined, 2),
  MoneyCat('Подарки', Icons.card_giftcard_outlined, 4),
  MoneyCat('Другое', Icons.more_horiz, 6),
];

const incomeCats = [
  MoneyCat('Зарплата', Icons.work_outline, 0),
  MoneyCat('Подработка', Icons.handyman_outlined, 2),
  MoneyCat('Стипендия', Icons.school_outlined, 3),
  MoneyCat('Подарок', Icons.card_giftcard_outlined, 4),
  MoneyCat('Возврат', Icons.replay_outlined, 1),
  MoneyCat('Другое', Icons.more_horiz, 6),
];

List<Color> catColors() => [C.workout, C.deadline, C.accent, C.lilac, C.sun, C.overdue, C.muted];

MoneyCat catOf(Item t) {
  final list = isIncome(t) ? incomeCats : expenseCats;
  final name = str(t, 'cat');
  for (final c in list) {
    if (c.name == name) return c;
  }
  return list.last;
}

Color catColor(MoneyCat c) {
  final list = catColors();
  return list[c.tone.clamp(0, list.length - 1).toInt()];
}
