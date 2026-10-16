import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Quick undated notes, like "Saved Messages" in Telegram:
/// type and send, newest at the top, pin the important ones, search, copy.
class NotesModule extends StatefulWidget {
  const NotesModule({super.key});

  @override
  State<NotesModule> createState() => _NotesModuleState();
}

class _NotesModuleState extends State<NotesModule> {
  final _input = TextEditingController();
  final _search = TextEditingController();
  String _query = '';
  int _show = 20;

  @override
  void dispose() {
    _input.dispose();
    _search.dispose();
    super.dispose();
  }

  void _send(AppStore store) {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    store.put({
      'id': newId(),
      'kind': 'note',
      'text': text,
      'pinned': false,
      'created': DateTime.now().millisecondsSinceEpoch,
    });
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.notes;
    final q = _query.trim().toLowerCase();
    final list = q.isEmpty ? all : all.where((n) => str(n, 'text').toLowerCase().contains(q)).toList();

    return Panel(
      title: 'Заметки',
      count: all.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 6,
                  maxLength: 5000,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Мысль, ссылка, список покупок…', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => _send(store),
                icon: const Icon(Icons.send_rounded),
                tooltip: 'Сохранить заметку',
              ),
            ],
          ),
          if (all.length > 5) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Поиск по заметкам',
                prefixIcon: const Icon(Icons.search, size: 20, color: C.muted),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Очистить поиск',
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (all.isEmpty)
            const EmptyNote('Здесь будут заметки без даты: идеи, ссылки, списки. Напишите что-нибудь и нажмите ➤.')
          else if (list.isEmpty)
            const Hint('Ничего не нашлось.')
          else ...[
            for (final n in list.take(_show)) _NoteBubble(key: ValueKey(n['id']), note: n),
            if (list.length > _show)
              TextButton(onPressed: () => setState(() => _show += 30), child: Text('Показать ещё (${list.length - _show})')),
          ],
        ],
      ),
    );
  }
}

String _stamp(num ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms.toInt());
  final now = DateTime.now();
  final time = '${two(d.hour)}:${two(d.minute)}';
  if (ymd(d) == ymd(now)) return 'сегодня, $time';
  if (ymd(d) == ymd(addDays(now, -1))) return 'вчера, $time';
  final date = '${d.day} ${monthsGen[d.month - 1]}${d.year != now.year ? ' ${d.year}' : ''}';
  return '$date, $time';
}

class _NoteBubble extends StatelessWidget {
  const _NoteBubble({super.key, required this.note});
  final Item note;

  Future<void> _edit(BuildContext context, AppStore store) async {
    final c = TextEditingController(text: str(note, 'text'));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Изменить заметку', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              TextField(
                controller: c,
                autofocus: true,
                minLines: 3,
                maxLines: 12,
                maxLength: 5000,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(counterText: ''),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: () {
                    final t = c.text.trim();
                    if (t.isNotEmpty) store.put({...note, 'text': t});
                    Navigator.pop(ctx);
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    c.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final pinned = note['pinned'] == true;
    final created = (note['created'] ?? 0) as num;
    final updated = (note['updated'] ?? created) as num;
    final edited = updated - created > 60000;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: C.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: pinned ? BorderSide(color: C.accent.withOpacity(.5)) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _edit(context, store),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (pinned)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Icon(Icons.push_pin, size: 13, color: C.accent),
                            SizedBox(width: 4),
                            Text('Закреплено', style: TextStyle(fontSize: 11.5, color: C.accent)),
                          ]),
                        ),
                      Text(str(note, 'text'), style: const TextStyle(fontSize: 14.5, height: 1.4)),
                      const SizedBox(height: 6),
                      Text(
                        _stamp(created) + (edited ? ' · изменено' : ''),
                        style: const TextStyle(fontSize: 11.5, color: C.faint, fontFeatures: tabular),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: C.muted),
                  tooltip: 'Действия',
                  onSelected: (v) async {
                    switch (v) {
                      case 'pin':
                        store.put({...note, 'pinned': !pinned});
                      case 'copy':
                        await Clipboard.setData(ClipboardData(text: str(note, 'text')));
                        if (context.mounted) toast(context, 'Скопировано');
                      case 'edit':
                        await _edit(context, store);
                      case 'delete':
                        if (await confirmDialog(context, 'Удалить заметку?')) store.remove(str(note, 'id'));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'pin', child: Text(pinned ? 'Открепить' : 'Закрепить')),
                    const PopupMenuItem(value: 'copy', child: Text('Копировать')),
                    const PopupMenuItem(value: 'edit', child: Text('Изменить')),
                    const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
