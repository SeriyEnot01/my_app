import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/money.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/money_widgets.dart';

/// Every expense and income the user types in, by month: totals, categories, list.
/// Regular payments from the «Регулярные платежи» block can be counted in the month's totals.
class ExpensesModule extends StatefulWidget {
  const ExpensesModule({super.key});

  @override
  State<ExpensesModule> createState() => _ExpensesModuleState();
}

class _ExpensesModuleState extends State<ExpensesModule> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _show = 15;

  void _shift(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
        _show = 15;
      });

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = currencyOf(store);
    final prefix = '${_month.year}-${two(_month.month)}-';
    final list = store.txns.where((t) => str(t, 'date').startsWith(prefix)).toList();
    final bills = store.bills.where((b) => billInMonth(b, _month.year, _month.month)).toList();
    final withBills = (store.items['profile']?['ledgerBills'] as bool?) ?? true;
    final countBills = withBills && bills.isNotEmpty;

    var spent = 0.0, earned = 0.0, billsOut = 0.0, billsIn = 0.0;
    final byCat = <String, double>{};
    for (final t in list) {
      final a = amountOf(t);
      if (isIncome(t)) {
        earned += a;
      } else {
        spent += a;
        final c = catOf(t).name;
        byCat[c] = (byCat[c] ?? 0) + a;
      }
    }
    if (countBills) {
      for (final b in bills) {
        if (isIncome(b)) {
          billsIn += amountOf(b);
        } else {
          billsOut += amountOf(b);
        }
      }
      if (billsOut > 0) byCat['Регулярные платежи'] = billsOut;
    }
    final totalOut = spent + billsOut, totalIn = earned + billsIn;
    final cats = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;

    return Panel(
      title: 'Расходы и доходы',
      icon: Icons.account_balance_wallet_outlined,
      tone: C.workout,
      trailing: CurrencyButton(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(tooltip: 'Предыдущий месяц', icon: Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
          Expanded(
            child: Text(
              '${monthsNom[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: display(16, weight: FontWeight.w700),
            ),
          ),
          IconButton(tooltip: 'Следующий месяц', icon: Icon(Icons.chevron_right), onPressed: () => _shift(1)),
        ]),
        if (!isCurrent)
          Center(
            child: TextButton(
              onPressed: () => setState(() => _month = DateTime(now.year, now.month)),
              child: Text('К текущему месяцу'),
            ),
          ),
        SizedBox(height: 8),
        MoneyStats(children: [
          MoneyStat(label: 'Потрачено', value: money(totalOut, cur), color: C.deadline),
          MoneyStat(label: 'Получено', value: money(totalIn, cur), color: C.workout),
          MoneyStat(
            label: 'Итог месяца',
            value: money(totalIn - totalOut, cur, sign: totalIn - totalOut > 0),
            color: totalIn >= totalOut ? C.accent : C.overdue,
          ),
        ]),
        if (store.bills.isNotEmpty) ...[
          SizedBox(height: 4),
          Row(children: [
            Switch(
              value: withBills,
              onChanged: (v) => store.setProfile('ledgerBills', v),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                countBills
                    ? 'Учитывать регулярные платежи: ${money(billsOut, cur)}${billsIn > 0 ? ', поступления ${money(billsIn, cur)}' : ''}'
                    : 'Учитывать регулярные платежи',
                style: TextStyle(color: C.muted, fontSize: 13),
              ),
            ),
          ]),
        ],
        if (cats.isNotEmpty) ...[
          SizedBox(height: 14),
          SectionLabel('На что ушло'),
          SizedBox(height: 8),
          for (final e in cats.take(8)) _CatBar(name: e.key, value: e.value, total: totalOut, currency: cur),
        ],
        SizedBox(height: 16),
        SectionLabel('Добавить'),
        SizedBox(height: 8),
        TxnForm(store: store, initialDate: isCurrent ? null : ymd(DateTime(_month.year, _month.month, 1))),
        SizedBox(height: 16),
        SectionLabel(list.isEmpty ? 'Записи' : 'Записи · ${list.length}'),
        SizedBox(height: 8),
        if (list.isEmpty)
          EmptyNote('За этот месяц записей нет. Введите сумму выше: расход, например покупку, или доход.', icon: Icons.receipt_long_outlined)
        else ...[
          ..._grouped(context, list.take(_show).toList(), cur),
          if (list.length > _show)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _show += 30),
                child: Text('Показать ещё ${list.length - _show}'),
              ),
            ),
        ],
      ]),
    );
  }

  List<Widget> _grouped(BuildContext context, List<Item> items, String cur) {
    final out = <Widget>[];
    String? day;
    for (final t in items) {
      final d = str(t, 'date');
      if (d != day) {
        day = d;
        final dayItems = items.where((x) => str(x, 'date') == d);
        final daySpent = dayItems.where((x) => !isIncome(x)).fold<double>(0, (s, x) => s + amountOf(x));
        out.add(Padding(
          padding: EdgeInsets.fromLTRB(2, out.isEmpty ? 0 : 10, 2, 6),
          child: Row(children: [
            Expanded(child: Text(_dayTitle(d), style: TextStyle(color: C.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
            if (daySpent > 0) Text(money(-daySpent, cur), style: TextStyle(color: C.faint, fontSize: 12.5, fontFeatures: tabular)),
          ]),
        ));
      }
      out.add(_TxnTile(txn: t, currency: cur));
    }
    return out;
  }

  String _dayTitle(String d) {
    final n = daysFromToday(d);
    if (n == 0) return 'Сегодня';
    if (n == -1) return 'Вчера';
    return humanFull(d);
  }
}

class _CatBar extends StatelessWidget {
  const _CatBar({required this.name, required this.value, required this.total, required this.currency});
  final String name;
  final double value;
  final double total;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final cat = expenseCats.firstWhere((c) => c.name == name, orElse: () => MoneyCat(name, Icons.event_repeat_outlined, 4));
    final color = catColor(cat);
    final share = total <= 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(cat.icon, size: 16, color: color),
          SizedBox(width: 8),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.fg, fontSize: 13.5))),
          Text('${(share * 100).round()}%', style: TextStyle(color: C.faint, fontSize: 12, fontFeatures: tabular)),
          SizedBox(width: 10),
          Text(money(value, currency), style: TextStyle(color: C.fg, fontSize: 13.5, fontWeight: FontWeight.w600, fontFeatures: tabular)),
        ]),
        SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: share, minHeight: 6, backgroundColor: C.line.withOpacity(.6), color: color),
        ),
      ]),
    );
  }
}

class _TxnTile extends StatelessWidget {
  const _TxnTile({required this.txn, required this.currency});
  final Item txn;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final income = isIncome(txn);
    final cat = catOf(txn);
    final color = catColor(cat);
    final note = str(txn, 'note');
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: C.bg.withOpacity(.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: C.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _edit(context, store),
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 9, 12, 9),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(10)),
              child: Icon(cat.icon, size: 17, color: color),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat.name, style: TextStyle(color: C.fg, fontSize: 14, fontWeight: FontWeight.w500)),
                if (note.isNotEmpty) Text(note, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
            Text(
              money(income ? amountOf(txn) : -amountOf(txn), currency, sign: income),
              style: TextStyle(color: income ? C.workout : C.fg, fontWeight: FontWeight.w700, fontFeatures: tabular),
            ),
          ]),
        ),
      ),
    );
  }

  void _edit(BuildContext context, AppStore store) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Запись', style: display(18, weight: FontWeight.w700)),
              SizedBox(height: 14),
              TxnForm(store: store, txn: txn, onDone: () => Navigator.of(ctx).pop()),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Amount, expense/income, category, date and a note. Adds a new entry or edits [txn].
class TxnForm extends StatefulWidget {
  const TxnForm({super.key, required this.store, this.txn, this.initialDate, this.onDone});
  final AppStore store;
  final Item? txn;
  final String? initialDate;
  final VoidCallback? onDone;

  @override
  State<TxnForm> createState() => _TxnFormState();
}

class _TxnFormState extends State<TxnForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _amountFocus = FocusNode();
  bool _income = false;
  String _cat = expenseCats.first.name;
  late String _date;
  String? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.txn;
    _date = widget.initialDate ?? todayStr();
    if (t != null) {
      final a = amountOf(t);
      _amount.text = a == a.roundToDouble() ? a.toInt().toString() : a.toStringAsFixed(2).replaceAll('.', ',');
      _note.text = str(t, 'note');
      _income = isIncome(t);
      _cat = catOf(t).name;
      _date = str(t, 'date').isEmpty ? _date : str(t, 'date');
    }
  }

  @override
  void didUpdateWidget(TxnForm old) {
    super.didUpdateWidget(old);
    // the month switcher changed: new entries go to that month unless a date was picked by hand
    if (widget.txn == null && old.initialDate != widget.initialDate) _date = widget.initialDate ?? todayStr();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  List<MoneyCat> get _cats => _income ? incomeCats : expenseCats;

  Future<void> _save() async {
    final amount = parseAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Введите сумму числом, например 350 или 1 250,50.');
      return;
    }
    final old = widget.txn;
    final note = _note.text.trim();
    await widget.store.put({
      ...?old,
      'id': old?['id'] ?? newId(),
      'kind': 'txn',
      'date': _date,
      'amount': amount,
      'type': _income ? 'income' : 'expense',
      'cat': _cat,
      'note': note.length > 200 ? note.substring(0, 200) : note,
      'created': old?['created'] ?? DateTime.now().millisecondsSinceEpoch,
    });
    if (!mounted) return;
    if (old == null) {
      _amount.clear();
      _note.clear();
      setState(() => _error = null);
      toast(context, '${_income ? 'Доход' : 'Расход'} ${money(amount, currencyOf(widget.store))} записан');
      _amountFocus.requestFocus();
    }
    widget.onDone?.call();
  }

  Future<void> _delete() async {
    final t = widget.txn;
    if (t == null) return;
    final ok = await confirmDialog(context, 'Удалить запись?');
    if (!ok) return;
    await widget.store.remove(t['id'] as String);
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final cur = currencyOf(widget.store);
    final editing = widget.txn != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MoneyTypeSwitch(
        income: _income,
        onChanged: (v) => setState(() {
          _income = v;
          _cat = _cats.first.name;
        }),
      ),
      SizedBox(height: 12),
      Row(children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _amount,
            focusNode: _amountFocus,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _save(),
            decoration: InputDecoration(labelText: 'Сумма', suffixText: cur),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: PickerField(
            label: 'Дата',
            value: rel(_date),
            icon: Icons.event_outlined,
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: parseYmd(_date), firstDate: DateTime(2020), lastDate: DateTime(2100));
              if (picked != null) setState(() => _date = ymd(picked));
            },
          ),
        ),
      ]),
      SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final c in _cats)
          ChoiceChip(
            label: Text(c.name),
            avatar: Icon(c.icon, size: 16, color: _cat == c.name ? catColor(c) : C.muted),
            selected: _cat == c.name,
            showCheckmark: false,
            onSelected: (_) => setState(() => _cat = c.name),
            selectedColor: catColor(c).withOpacity(.18),
            backgroundColor: C.bg.withOpacity(.5),
            side: BorderSide(color: _cat == c.name ? catColor(c).withOpacity(.6) : C.line),
            labelStyle: TextStyle(color: _cat == c.name ? C.fg : C.muted, fontSize: 13),
          ),
      ]),
      SizedBox(height: 10),
      TextField(
        controller: _note,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(labelText: 'Комментарий (необязательно)', hintText: 'Например, «обед с Машей»'),
      ),
      if (_error != null) ...[
        SizedBox(height: 8),
        Text(_error!, style: TextStyle(color: C.overdue, fontSize: 13.5)),
      ],
      SizedBox(height: 12),
      Row(children: [
        if (editing)
          TextButton.icon(
            onPressed: _delete,
            icon: Icon(Icons.delete_outline, size: 18, color: C.overdue),
            label: Text('Удалить', style: TextStyle(color: C.overdue)),
          ),
        Spacer(),
        FilledButton.icon(
          onPressed: _save,
          icon: Icon(editing ? Icons.check : Icons.add, size: 18),
          label: Text(editing ? 'Сохранить' : 'Записать'),
          style: _income ? tealButton() : null,
        ),
      ]),
    ]);
  }
}
