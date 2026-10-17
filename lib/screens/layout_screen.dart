import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/theme.dart';
import '../modules/registry.dart';

/// Turn blocks on/off and drag them into the order you like. Saved per device.
class LayoutScreen extends StatelessWidget {
  const LayoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeScope.of(context);
    final layout = LayoutScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Блоки на экране'),
        actions: [TextButton(onPressed: layout.reset, child: Text('Сбросить'))],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Text(
              'Отметьте нужные блоки и перетащите их за ручку справа, чтобы поменять порядок. '
              'Добавление задач, календарь, «Сегодня» и «Ближайшие 3 дня» есть всегда, но их тоже можно двигать.',
              style: TextStyle(color: C.muted, height: 1.4),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: layout.order.length,
              onReorder: layout.move,
              itemBuilder: (context, i) {
                final m = moduleById(layout.order[i])!;
                final available = m.availableHere;
                final on = layout.isOn(m) && available;
                return Padding(
                  key: ValueKey(m.id),
                  padding: EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: C.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.line)),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      contentPadding: EdgeInsets.only(left: 8, right: 4),
                      leading: m.core
                          ? Tooltip(
                              message: 'Всегда на экране',
                              child: SizedBox(width: 40, child: Icon(Icons.lock_outline, color: C.faint, size: 20)),
                            )
                          : Checkbox(
                              value: on,
                              onChanged: available ? (v) => layout.setOn(m.id, v ?? false) : null,
                            ),
                      title: Row(children: [
                        Icon(m.icon, size: 18, color: on ? C.accent : C.muted),
                        SizedBox(width: 8),
                        Flexible(child: Text(m.title, style: TextStyle(color: available ? C.fg : C.faint))),
                      ]),
                      subtitle: Text(
                        available ? m.description : '${m.description}. Только в Android-версии.',
                        style: TextStyle(color: C.muted, fontSize: 12.5),
                      ),
                      onTap: m.core || !available ? null : () => layout.setOn(m.id, !on),
                      trailing: ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(Icons.drag_handle, color: C.muted),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
