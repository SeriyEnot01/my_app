import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/common.dart';
import 'layout_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Panel(
                  title: 'Экран',
                  child: _Tile(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Блоки на экране',
                    subtitle: 'Включить модули и поменять их порядок',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LayoutScreen())),
                  ),
                ),
                const SizedBox(height: 16),
                const UpdatePanel(),
                if (store.configured) ...[
                  const SizedBox(height: 16),
                  Panel(
                    title: 'Аккаунт',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Tile(icon: Icons.person_outline, title: store.email.isEmpty ? 'Аккаунт' : store.email, subtitle: store.status),
                      const SizedBox(height: 6),
                      _Tile(
                        icon: Icons.sync,
                        title: 'Синхронизировать сейчас',
                        onTap: store.syncNow,
                      ),
                      const SizedBox(height: 6),
                      _Tile(
                        icon: Icons.logout,
                        title: 'Выйти',
                        color: C.overdue,
                        onTap: () => confirmLogout(context),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, this.onTap, this.color});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface2,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Icon(icon, color: color ?? C.muted),
          title: Text(title, style: TextStyle(color: color ?? C.fg)),
          subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!, style: const TextStyle(color: C.muted, fontSize: 12.5)),
          trailing: onTap == null ? null : const Icon(Icons.chevron_right, color: C.faint),
          onTap: onTap,
        ),
      );
}

/// Shared by the settings screen: sign out, asking first if some changes were not sent yet.
Future<void> confirmLogout(BuildContext context) async {
  final AppStore store = StoreScope.read(context);
  final nav = Navigator.of(context);
  var ok = await store.signOut();
  if (!ok) {
    if (!context.mounted) return;
    final force = await confirmDialog(
      context,
      'Выйти без отправки?',
      body: 'Не отправлено изменений: ${store.dirty.length}. Нет связи с сервером. Если выйти сейчас, эти изменения удалятся с этого устройства.',
      action: 'Выйти',
    );
    if (!force) return;
    ok = await store.signOut(force: true);
  }
  if (ok) nav.popUntil((r) => r.isFirst);
}

class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final u = Updater.instance;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        if (!u.platformSupported) return const SizedBox.shrink();
        final rel = u.latest;
        final busy = u.checking || u.downloading;
        return Panel(
          title: 'Обновления',
          dot: u.hasUpdate ? C.workout : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                appBuild == 0 ? 'Установлена локальная сборка' : 'Установлена сборка $appBuild',
                style: const TextStyle(color: C.muted),
              ),
              if (!u.configured) ...[
                const SizedBox(height: 6),
                const Hint('Проверка обновлений работает в сборках из GitHub Actions.'),
              ],
              if (u.hasUpdate && rel != null) ...[
                const SizedBox(height: 10),
                Text('Доступна сборка ${rel.build}', style: const TextStyle(color: C.workout, fontWeight: FontWeight.w600)),
                if (rel.notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(rel.notes, maxLines: 6, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 13)),
                ],
                if (rel.size > 0) Text('${(rel.size / 1024 / 1024).toStringAsFixed(1)} МБ', style: const TextStyle(color: C.faint, fontSize: 12)),
              ],
              if (u.downloading) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: u.progress, minHeight: 8, backgroundColor: C.surface2, color: C.workout),
                ),
                const SizedBox(height: 4),
                Text('${((u.progress ?? 0) * 100).round()}%', style: const TextStyle(color: C.muted, fontSize: 12, fontFeatures: tabular)),
              ],
              if (u.message.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(u.message, style: TextStyle(color: u.error ? C.overdue : C.muted, fontSize: 13)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton.icon(
                  onPressed: busy || !u.configured ? null : () => u.check(),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(u.checking ? 'Проверяем…' : 'Проверить обновления'),
                ),
                if (u.hasUpdate)
                  FilledButton.icon(
                    style: tealButton(),
                    onPressed: busy ? null : u.downloadAndInstall,
                    icon: const Icon(Icons.system_update_alt, size: 18),
                    label: const Text('Обновить'),
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }
}
