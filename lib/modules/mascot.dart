import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/dates.dart';
import '../core/models.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Shows the user's own GIF (picked on this device), or assets/mascot.gif if the
/// repository has one, plus a short message based on today's tasks.
class MascotModule extends StatefulWidget {
  const MascotModule({super.key});

  @override
  State<MascotModule> createState() => _MascotModuleState();
}

class _MascotModuleState extends State<MascotModule> {
  File? _custom;
  int _version = 0;
  String _msg = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<File> _target() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}${Platform.pathSeparator}mascot_image');
  }

  Future<void> _load() async {
    try {
      final f = await _target();
      final exists = await f.exists();
      if (mounted) setState(() => _custom = exists ? f : null);
    } catch (_) {}
  }

  Future<void> _pick() async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image);
      final file = res?.files.single;
      if (file == null) return;
      if (file.size > 15 * 1024 * 1024) {
        setState(() => _msg = 'Файл больше 15 МБ, выберите поменьше.');
        return;
      }
      final target = await _target();
      if (file.path != null) {
        await File(file.path!).copy(target.path);
      } else if (file.bytes != null) {
        await target.writeAsBytes(file.bytes!);
      } else {
        return;
      }
      await FileImage(target).evict();
      setState(() {
        _custom = target;
        _version++;
        _msg = '';
      });
    } catch (e) {
      setState(() => _msg = 'Не удалось сохранить картинку: $e');
    }
  }

  Future<void> _reset() async {
    try {
      final t = await _target();
      if (await t.exists()) {
        await FileImage(t).evict();
        await t.delete();
      }
    } catch (_) {}
    setState(() {
      _custom = null;
      _version++;
    });
  }

  Widget _placeholder() => const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.image_outlined, size: 34, color: C.faint),
            SizedBox(height: 8),
            Text('Здесь будет ваша гифка', textAlign: TextAlign.center, style: TextStyle(color: C.faint, fontSize: 12.5)),
          ]),
        ),
      );

  Widget _frame(double size) {
    final img = _custom != null
        ? Image.file(_custom!, key: ValueKey('c$_version'), fit: BoxFit.cover, gaplessPlayback: true, errorBuilder: (_, __, ___) => _placeholder())
        : Image.asset('assets/mascot.gif', fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: C.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: img,
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = DateTime.now().hour;
    final hello = h < 5 ? 'Доброй ночи!' : h < 12 ? 'Доброе утро!' : h < 18 ? 'Добрый день!' : 'Добрый вечер!';
    final today = todayStr();
    final tasks = store.tasks;
    final todays = tasks.where((t) => str(t, 'due') == today).toList();
    final left = todays.where((t) => !isDone(t)).length;
    final over = tasks.where(isOverdue).length;
    final String line;
    if (over > 0) {
      line = 'Есть просроченные задачи: $over. Давай закроем хотя бы одну.';
    } else if (left > 0) {
      line = 'Сегодня $left ${plural(left, 'дедлайн', 'дедлайна', 'дедлайнов')}. Ты справишься!';
    } else if (todays.isNotEmpty) {
      line = 'Всё на сегодня сделано. Горжусь тобой!';
    } else {
      line = 'Сегодня дедлайнов нет. Самое время для тренировки.';
    }
    final weekAgo = ymd(addDays(DateTime.now(), -6));
    final w = store.logs.where((l) => str(l, 'date').compareTo(weekAgo) >= 0 && str(l, 'date').compareTo(today) <= 0).length;
    final sub = w > 0 ? 'Тренировок за 7 дней: $w.' : 'За неделю пока без тренировок.';

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hello, style: display(18)),
        const SizedBox(height: 4),
        Text(line, style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 13, color: C.muted)),
      ]),
    );
    final buttons = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      OutlinedButton(onPressed: _pick, child: const Text('Выбрать гифку')),
      if (_custom != null) OutlinedButton(onPressed: _reset, child: const Text('Убрать')),
      if (_msg.isNotEmpty) Text(_msg, style: const TextStyle(color: C.overdue, fontSize: 12.5)),
    ]);

    return Panel(
      child: LayoutBuilder(builder: (context, c) {
        if (c.maxWidth >= 520) {
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            _frame(190),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bubble, const SizedBox(height: 14), buttons])),
          ]);
        }
        final size = c.maxWidth.clamp(0.0, 300.0).toDouble();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: _frame(size)),
          const SizedBox(height: 14),
          bubble,
          const SizedBox(height: 12),
          buttons,
        ]);
      }),
    );
  }
}
