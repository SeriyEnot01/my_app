import 'package:flutter/material.dart';

import '../core/notifications.dart';
import '../core/scope.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class RemindersModule extends StatelessWidget {
  const RemindersModule({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Reminders.supported) {
      return Panel(title: 'Напоминания', child: Hint('Напоминания приходят только в Android-версии приложения.'));
    }
    final rc = ReminderScope.of(context);
    return Panel(
      title: 'Напоминания о дедлайнах',
      icon: Icons.notifications_active_outlined,
      tone: C.deadline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: rc.enabled,
            activeColor: C.accent,
            title: Text('Напоминать в день дедлайна'),
            subtitle: Text(
              rc.enabled ? 'Запланировано уведомлений: ${rc.scheduled}' : 'Уведомление придёт, даже если приложение закрыто',
              style: TextStyle(color: C.muted, fontSize: 13),
            ),
            onChanged: (v) async {
              final ok = await rc.setEnabled(v);
              if (!ok && context.mounted) {
                toast(context, 'Разрешите уведомления для workflows в настройках телефона.');
              }
            },
          ),
          if (rc.enabled) ...[
            SizedBox(height: 8),
            SizedBox(
              width: 240,
              child: PickerField(
                label: 'Время напоминания',
                value: rc.time,
                icon: Icons.schedule,
                onTap: () async {
                  final t = await pickTime(context, rc.time);
                  if (t != null) await rc.setTime(t);
                },
              ),
            ),
            SizedBox(height: 10),
            Hint('Если у задачи указано время, напоминание придёт за час до него.'),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(onPressed: Reminders.showTest, child: Text('Проверить')),
            ),
          ],
          SizedBox(height: 10),
          Hint('Задачи, добавленные на компьютере, попадут в напоминания после того, как вы откроете приложение на телефоне.'),
        ],
      ),
    );
  }
}
