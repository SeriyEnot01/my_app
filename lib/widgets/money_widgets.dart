import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/scope.dart';
import '../core/theme.dart';

/// Currency switch in a money block's header. Saved in the synced profile.
class CurrencyButton extends StatelessWidget {
  const CurrencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final cur = currencyOf(store);
    return PopupMenuButton<String>(
      tooltip: 'Валюта',
      initialValue: cur,
      onSelected: (c) => store.setProfile('currency', c),
      itemBuilder: (_) => [
        for (final c in currencies) PopupMenuItem(value: c, child: Text(c, style: TextStyle(color: C.fg))),
      ],
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: C.bg.withOpacity(.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(cur, style: TextStyle(color: C.fg, fontWeight: FontWeight.w600)),
          Icon(Icons.expand_more, size: 16, color: C.muted),
        ]),
      ),
    );
  }
}

/// A small figure with a caption: «Расходы  12 300 ₽».
class MoneyStat extends StatelessWidget {
  const MoneyStat({super.key, required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: color.withOpacity(.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.22)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: C.muted, fontSize: 12)),
          SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: display(17, weight: FontWeight.w700, color: color).copyWith(fontFeatures: tabular)),
          ),
        ]),
      );
}

/// Row of [MoneyStat]s that wraps on narrow screens.
class MoneyStats extends StatelessWidget {
  const MoneyStats({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 420 ? children.length : 2;
        final w = (c.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

/// «Расход / Доход» switch.
class MoneyTypeSwitch extends StatelessWidget {
  const MoneyTypeSwitch({super.key, required this.income, required this.onChanged, this.expenseLabel = 'Расход', this.incomeLabel = 'Доход'});
  final bool income;
  final ValueChanged<bool> onChanged;
  final String expenseLabel;
  final String incomeLabel;

  @override
  Widget build(BuildContext context) => SegmentedButton<bool>(
        segments: [
          ButtonSegment(value: false, label: Text(expenseLabel), icon: Icon(Icons.north_east, size: 16)),
          ButtonSegment(value: true, label: Text(incomeLabel), icon: Icon(Icons.south_west, size: 16)),
        ],
        selected: {income},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: (income ? C.workout : C.deadline).withOpacity(.18),
          selectedForegroundColor: income ? C.workout : C.deadline,
          foregroundColor: C.muted,
          side: BorderSide(color: C.line),
        ),
      );
}
