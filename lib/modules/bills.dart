import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/money_widgets.dart';

/// Regular payments and incomes: subscriptions, rent, phone, salary, stipend.
/// Each has a day of the month (or a date once a year) and an amount the user types in.
/// A tick marks this period as paid / received, and the item moves to its next date.
class BillsModule extends StatelessWidget {
  const BillsModule({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = currencyOf(store);
    final today = DateTime.now();
    final bills = store.bills;
    final rows = [for (final b in bills) (bill: b, next: billNext(b, today))]
      ..sort((a, b) {
        final o = (b.next.overdue ? 1 : 0) - (a.next.overdue ? 1 : 0);
        return o != 0 ? o : a.next.date.compareTo(b.next.date);
      });

    var outMonth = 0.0, inMonth = 0.0;
    for (final b in bills) {
      if (isIncome(b)) {
        inMonth += billPerMonth(b);
      } else {
        outMonth += billPerMonth(b);
      }
    }
    final hasYearly = bills.any(billYearly);

    return Panel(
      title: 'Регулярные платежи',
      icon: Icons.event_repeat_outlined,
      tone: C.sun,
      count: bills.isEmpty ? null : bills.length,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        CurrencyButton(),
        SizedBox(width: 4),
        IconButton(
          tooltip: 'Добавить',
          icon: Icon(Icons.add_circle_outline, color: C.sun),
          onPressed: () => showBillEditor(context, store),
        ),
      ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (bills.isEmpty)
          EmptyNote(
            'Подписки, аренда, связь, кредит, а ещё зарплата или стипендия: всё, что повторяется каждый месяц или раз в год. '
            'Нажмите «+», укажите сумму и число.',
            icon: Icons.event_repeat_outlined,
          )
        else ...[
          MoneyStats(children: [
            MoneyStat(label: 'Платежи в месяц', value: money(outMonth, cur), color: C.deadline),
            if (inMonth > 0) MoneyStat(label: 'Поступления в месяц', value: money(inMonth, cur), color: C.workout),
            if (inMonth > 0)
              MoneyStat(
                label: 'Остаётся',
                value: money(inMonth - outMonth, cur),
                color: inMonth >= outMonth ? C.accent : C.overdue,
              ),
          ]),
          if (hasYearly) ...[
            SizedBox(height: 6),
            Hint('Годовые платежи посчитаны как 1/12 в месяц.'),
          ],
          SizedBox(height: 12),
          for (final r in rows) _BillTile(bill: r.bill, next: r.next, currency: cur),
        ],
      ]),
    );
  }
}

class _BillTile extends StatelessWidget {
  const _BillTile({required this.bill, required this.next, required this.currency});
  final Item bill;
  final ({DateTime date, bool overdue}) next;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final income = isIncome(bill);
    final tone = income ? C.workout : C.deadline;
    final dateStr = ymd(next.date);
    final days = daysFromToday(dateStr);
    final when = next.overdue
        ? (income ? 'ожидалось ${human(dateStr)}' : 'не оплачено с ${human(dateStr)}')
        : days == 0
            ? 'сегодня'
            : days == 1
                ? 'завтра'
                : days < 31
                    ? 'через $days ${plural(days, 'день', 'дня', 'дней')}, ${human(dateStr)}'
                    : human(dateStr);
    final period = billYearly(bill)
        ? 'раз в год, ${(bill['day'] as num?)?.toInt() ?? 1} ${monthsGen[((bill['month'] as num?)?.toInt() ?? 1).clamp(1, 12).toInt() - 1]}'
        : 'каждый месяц, ${(bill['day'] as num?)?.toInt() ?? 1} числа';
    final urgent = !income && (next.overdue || days <= 2);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: C.bg.withOpacity(.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: next.overdue && !income ? C.overdue.withOpacity(.5) : C.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showBillEditor(context, store, bill: bill),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: tone.withOpacity(.14), borderRadius: BorderRadius.circular(11)),
              child: Icon(income ? Icons.south_west : Icons.north_east, size: 18, color: tone),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(str(bill, 'title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.fg, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(
                  '$when · $period',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: next.overdue && !income ? C.overdue : (urgent ? C.deadline : C.muted), fontSize: 12.5),
                ),
              ]),
            ),
            SizedBox(width: 8),
            Text(
              money(amountOf(bill), currency, sign: income),
              style: TextStyle(color: income ? C.workout : C.fg, fontWeight: FontWeight.w700, fontFeatures: tabular),
            ),
            IconButton(
              tooltip: income ? 'Получено' : 'Оплачено',
              icon: Icon(Icons.check_circle_outline, color: C.faint),
              onPressed: () async {
                await _markDone(store, bill, next.date);
                if (context.mounted) toast(context, income ? 'Отмечено как полученное' : 'Отмечено как оплаченное');
              },
            ),
          ]),
        ),
      ),
    );
  }
}

Future<void> _markDone(AppStore store, Item bill, DateTime date) {
  final paid = [...((bill['paid'] as List?) ?? const []).map((e) => e.toString())];
  final key = periodKey(bill, date);
  if (!paid.contains(key)) paid.add(key);
  paid.sort();
  // the last two years are enough
  final keep = paid.length > 24 ? paid.sublist(paid.length - 24) : paid;
  return store.put({...bill, 'paid': keep});
}

Future<void> showBillEditor(BuildContext context, AppStore store, {Item? bill}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _BillEditor(store: store, bill: bill),
    ),
  );
}

class _BillEditor extends StatefulWidget {
  const _BillEditor({required this.store, this.bill});
  final AppStore store;
  final Item? bill;

  @override
  State<_BillEditor> createState() => _BillEditorState();
}

class _BillEditorState extends State<_BillEditor> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  bool _income = false;
  bool _yearly = false;
  int _day = DateTime.now().day;
  int _month = DateTime.now().month;
  String? _error;

  @override
  void initState() {
    super.initState();
    final b = widget.bill;
    if (b != null) {
      _title.text = str(b, 'title');
      final a = amountOf(b);
      _amount.text = a == a.roundToDouble() ? a.toInt().toString() : a.toStringAsFixed(2).replaceAll('.', ',');
      _income = isIncome(b);
      _yearly = billYearly(b);
      _day = ((b['day'] as num?)?.toInt() ?? 1).clamp(1, 31).toInt();
      _month = ((b['month'] as num?)?.toInt() ?? 1).clamp(1, 12).toInt();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final amount = parseAmount(_amount.text);
    if (title.isEmpty) {
      setState(() => _error = 'Назовите платёж, например «Интернет» или «Зарплата».');
      return;
    }
    if (amount == null) {
      setState(() => _error = 'Введите сумму числом, например 799 или 1 250,50.');
      return;
    }
    final old = widget.bill;
    await widget.store.put({
      ...?old,
      'id': old?['id'] ?? newId(),
      'kind': 'bill',
      'title': title.length > 80 ? title.substring(0, 80) : title,
      'amount': amount,
      'type': _income ? 'income' : 'expense',
      'period': _yearly ? 'year' : 'month',
      'day': _day,
      'month': _month,
      'paid': old?['paid'] ?? <String>[],
      'created': old?['created'] ?? DateTime.now().millisecondsSinceEpoch,
    });
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final b = widget.bill;
    if (b == null) return;
    final ok = await confirmDialog(context, 'Удалить «${str(b, 'title')}»?');
    if (!ok) return;
    await widget.store.remove(b['id'] as String);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.bill != null;
    final maxDay = _yearly ? daysInMonth(2024, _month) : 31;
    if (_day > maxDay) _day = maxDay;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(editing ? 'Регулярный платёж' : 'Новый регулярный платёж', style: display(18, weight: FontWeight.w700)),
          SizedBox(height: 14),
          MoneyTypeSwitch(
            income: _income,
            expenseLabel: 'Платёж',
            incomeLabel: 'Поступление',
            onChanged: (v) => setState(() => _income = v),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Название', hintText: _income ? 'Зарплата, стипендия…' : 'Интернет, аренда, подписка…'),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Сумма', suffixText: currencyOf(widget.store)),
          ),
          SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(value: false, label: Text('Каждый месяц')),
              ButtonSegment(value: true, label: Text('Раз в год')),
            ],
            selected: {_yearly},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _yearly = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.accent.withOpacity(.16),
              selectedForegroundColor: C.accent,
              foregroundColor: C.muted,
              side: BorderSide(color: C.line),
            ),
          ),
          SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _day,
                isExpanded: true,
                dropdownColor: C.surface2,
                menuMaxHeight: 320,
                decoration: InputDecoration(labelText: 'Число'),
                items: [for (var d = 1; d <= maxDay; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                onChanged: (v) => setState(() => _day = v ?? _day),
              ),
            ),
            if (_yearly) ...[
              SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  value: _month,
                  isExpanded: true,
                  dropdownColor: C.surface2,
                  menuMaxHeight: 320,
                  decoration: InputDecoration(labelText: 'Месяц'),
                  items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(monthsNom[m - 1]))],
                  onChanged: (v) => setState(() => _month = v ?? _month),
                ),
              ),
            ],
          ]),
          if (!_yearly && _day > 28) ...[
            SizedBox(height: 6),
            Hint('В коротких месяцах дата сдвинется на последний день.'),
          ],
          if (_error != null) ...[
            SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: C.overdue, fontSize: 13.5)),
          ],
          SizedBox(height: 16),
          Row(children: [
            if (editing)
              TextButton.icon(
                onPressed: _delete,
                icon: Icon(Icons.delete_outline, size: 18, color: C.overdue),
                label: Text('Удалить', style: TextStyle(color: C.overdue)),
              ),
            Spacer(),
            FilledButton(onPressed: _save, child: Text(editing ? 'Сохранить' : 'Добавить')),
          ]),
        ]),
      ),
    );
  }
}
