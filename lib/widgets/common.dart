import 'package:flutter/material.dart';

import '../core/theme.dart';

class Dot extends StatelessWidget {
  const Dot(this.color, {super.key, this.size = 8});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// The rounded card every block lives in.
class Panel extends StatelessWidget {
  const Panel({super.key, this.title, this.dot, this.count, this.trailing, required this.child});
  final String? title;
  final Color? dot;
  final int? count;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.line),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null || trailing != null) ...[
            Row(
              children: [
                if (dot != null) ...[Dot(dot!), const SizedBox(width: 10)],
                if (title != null)
                  Flexible(
                    child: Text(title!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                if (count != null) ...[const SizedBox(width: 8), CountPill(count!)],
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class CountPill extends StatelessWidget {
  const CountPill(this.n, {super.key});
  final int n;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(999)),
        child: Text('$n', style: const TextStyle(fontSize: 12, color: C.muted, fontFeatures: tabular)),
      );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color?.withOpacity(.45) ?? C.line),
        ),
        child: Text(text, style: TextStyle(fontSize: 11.5, color: color ?? C.muted, fontFeatures: tabular)),
      );
}

class EmptyNote extends StatelessWidget {
  const EmptyNote(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: C.line),
        ),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontSize: 14)),
      );
}

class Hint extends StatelessWidget {
  const Hint(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: color ?? C.faint, fontSize: 13, height: 1.4));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11.5, letterSpacing: 1, color: C.muted, fontWeight: FontWeight.w500),
      );
}

/// A tappable field that looks like a text input (date / time pickers).
class PickerField extends StatelessWidget {
  const PickerField({super.key, required this.label, required this.value, required this.icon, required this.onTap, this.onClear});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: onClear != null
              ? IconButton(icon: const Icon(Icons.close, size: 18), tooltip: 'Очистить', onPressed: onClear)
              : Icon(icon, size: 18, color: C.muted),
        ),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFeatures: tabular)),
      ),
    );
  }
}

ButtonStyle tealButton() => FilledButton.styleFrom(backgroundColor: C.workout, foregroundColor: C.workoutInk);

Future<bool> confirmDialog(BuildContext context, String title, {String? body, String action = 'Удалить'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 18)),
      content: body == null ? null : Text(body, style: const TextStyle(color: C.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.overdue, foregroundColor: C.bg),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
}

Future<String?> pickTime(BuildContext context, String current) async {
  TimeOfDay initial = const TimeOfDay(hour: 9, minute: 0);
  if (current.contains(':')) {
    final p = current.split(':');
    initial = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }
  final t = await showTimePicker(
    context: context,
    initialTime: initial,
    builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
