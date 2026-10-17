import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

const _kinds = ['task', 'plan', 'log', 'note', 'routine_item', 'routine_day', 'event'];

/// Same file format as the web version: {app, version, exported, items: [...]}.
class BackupModule extends StatefulWidget {
  const BackupModule({super.key});

  @override
  State<BackupModule> createState() => _BackupModuleState();
}

class _BackupModuleState extends State<BackupModule> {
  String _msg = '';
  bool _error = false;

  void _say(String m, {bool error = false}) => setState(() {
        _msg = m;
        _error = error;
      });

  Future<void> _export() async {
    final store = StoreScope.read(context);
    final json = JsonEncoder.withIndent(' ').convert({
      'app': 'zadachnik',
      'version': 1,
      'exported': DateTime.now().toUtc().toIso8601String(),
      'items': store.items.values.toList(),
    });
    final bytes = Uint8List.fromList(utf8.encode(json));
    final name = 'zadachnik-${todayStr()}.json';
    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить резервную копию',
        fileName: name,
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );
      if (path == null) {
        _say('Сохранение отменено.');
        return;
      }
      // on desktop the picker only returns a path; mobile writes the bytes itself
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        await File(path).writeAsBytes(bytes);
      }
      _say('Файл сохранён: $name');
    } catch (e) {
      _say('Не удалось сохранить файл: $e', error: true);
    }
  }

  Future<void> _import() async {
    final store = StoreScope.read(context);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['json'], withData: true);
      final f = res?.files.single;
      if (f == null) return;
      final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) return;
      final data = jsonDecode(utf8.decode(bytes));
      final list = (data is Map && data['items'] is List) ? data['items'] as List : [];
      var added = 0, updated = 0;
      for (final raw in list) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final id = item['id'];
        if (id is! String || !validId.hasMatch(id) || !_kinds.contains(item['kind'])) continue;
        final cur = store.items[id];
        if (cur != null && jsonEncode(cur) == jsonEncode(item)) continue;
        if (cur == null) {
          added++;
        } else {
          updated++;
        }
        await store.put(item);
      }
      _say(added + updated == 0 ? 'Всё из файла уже есть в задачнике.' : 'Загружено: новых $added, обновлено $updated.');
    } on FormatException {
      _say('Это не файл резервной копии задачника.', error: true);
    } catch (e) {
      _say('Не удалось загрузить файл: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'Резервная копия',
      icon: Icons.save_alt,
      tone: C.muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Hint(
            'Сохраните все задачи и тренировки в файл. Его можно загрузить в это приложение или на сайт: записи объединятся, дубликатов не будет.',
            color: C.muted,
          ),
          SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(onPressed: _export, icon: Icon(Icons.save_alt, size: 18), label: Text('Сохранить в файл')),
            OutlinedButton.icon(onPressed: _import, icon: Icon(Icons.upload_file, size: 18), label: Text('Загрузить из файла')),
          ]),
          if (_msg.isNotEmpty) ...[
            SizedBox(height: 10),
            Text(_msg, style: TextStyle(color: _error ? C.overdue : C.muted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}
