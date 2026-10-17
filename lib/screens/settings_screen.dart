import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/backdrop.dart';
import '../widgets/common.dart';
import 'layout_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeScope.of(context);
    final store = StoreScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Настройки')),
      body: AppBackdrop(
        child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ThemePicker(),
                SizedBox(height: 16),
                BackgroundPanel(),
                SizedBox(height: 16),
                Panel(
                  title: 'Экран',
                  child: _Tile(
                    icon: Icons.dashboard_customize_outlined,
                    title: 'Блоки на экране',
                    subtitle: 'Включить модули и поменять их порядок',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LayoutScreen())),
                  ),
                ),
                SizedBox(height: 16),
                UpdatePanel(),
                if (store.configured) ...[
                  SizedBox(height: 16),
                  Panel(
                    title: 'Аккаунт',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      _Tile(icon: Icons.person_outline, title: store.email.isEmpty ? 'Аккаунт' : store.email, subtitle: store.status),
                      SizedBox(height: 6),
                      _Tile(
                        icon: Icons.sync,
                        title: 'Синхронизировать сейчас',
                        onTap: store.syncNow,
                      ),
                      SizedBox(height: 6),
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
          subtitle: subtitle == null || subtitle!.isEmpty ? null : Text(subtitle!, style: TextStyle(color: C.muted, fontSize: 12.5)),
          trailing: onTap == null ? null : Icon(Icons.chevron_right, color: C.faint),
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
        if (!u.platformSupported) return SizedBox.shrink();
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
                style: TextStyle(color: C.muted),
              ),
              if (!u.configured) ...[
                SizedBox(height: 6),
                Hint('Проверка обновлений работает в сборках из GitHub Actions.'),
              ],
              if (u.hasUpdate && rel != null) ...[
                SizedBox(height: 10),
                Text('Доступна сборка ${rel.build}', style: TextStyle(color: C.workout, fontWeight: FontWeight.w600)),
                if (rel.notes.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(rel.notes, maxLines: 6, overflow: TextOverflow.ellipsis, style: TextStyle(color: C.muted, fontSize: 13)),
                ],
                if (rel.size > 0) Text('${(rel.size / 1024 / 1024).toStringAsFixed(1)} МБ', style: TextStyle(color: C.faint, fontSize: 12)),
              ],
              if (u.downloading) ...[
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: u.progress, minHeight: 8, backgroundColor: C.surface2, color: C.workout),
                ),
                SizedBox(height: 4),
                Text('${((u.progress ?? 0) * 100).round()}%', style: TextStyle(color: C.muted, fontSize: 12, fontFeatures: tabular)),
              ],
              if (u.message.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(u.message, style: TextStyle(color: u.error ? C.overdue : C.muted, fontSize: 13)),
              ],
              SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 10, children: [
                OutlinedButton.icon(
                  onPressed: busy || !u.configured ? null : () => u.check(),
                  icon: Icon(Icons.refresh, size: 18),
                  label: Text(u.checking ? 'Проверяем…' : 'Проверить обновления'),
                ),
                if (u.hasUpdate)
                  FilledButton.icon(
                    style: tealButton(),
                    onPressed: busy ? null : u.downloadAndInstall,
                    icon: Icon(Icons.system_update_alt, size: 18),
                    label: Text('Обновить'),
                  ),
              ]),
            ],
          ),
        );
      },
    );
  }
}


/// Theme cards: a small preview of each palette; tap to apply.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final themes = ThemeScope.of(context);
    return Panel(
      title: 'Оформление',
      icon: Icons.palette_outlined,
      tone: C.lilac,
      child: LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 620 ? 3 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final p in palettes)
              SizedBox(
                width: w,
                child: _ThemeCard(p: p, custom: themes.customBg(p.id), selected: themes.id == p.id, onTap: () => themes.select(p.id)),
              ),
          ],
        );
      }),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.p, required this.custom, required this.selected, required this.onTap});
  final AppPalette p;
  final String? custom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selected ? p.accent : p.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            height: 74,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: p.hero),
              image: custom != null
                  ? DecorationImage(image: ResizeImage(FileImage(File(custom!)), width: 360), fit: BoxFit.cover, opacity: .85)
                  : p.bgAsset != null
                      ? DecorationImage(image: ResizeImage(AssetImage(p.bgAsset!), width: 360), fit: BoxFit.cover, opacity: .85)
                      : null,
            ),
            padding: EdgeInsets.all(10),
            child: Stack(children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text('Аа', style: TextStyle(fontFamily: p.displayFont, fontSize: 22 * p.displayScale, color: p.fg, fontWeight: FontWeight.w700)),
              ),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final c in [p.accent, p.deadline, p.workout, p.lilac])
                    Container(
                      width: 12,
                      height: 12,
                      margin: EdgeInsets.only(left: 4),
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
                    ),
                ]),
              ),
              if (selected)
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    padding: EdgeInsets.all(3),
                    decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
                    child: Icon(Icons.check, size: 14, color: p.accentInk),
                  ),
                ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: TextStyle(color: p.fg, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(p.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: p.muted, fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The current theme's background: the user's own picture, blur and darkening.
class BackgroundPanel extends StatefulWidget {
  const BackgroundPanel({super.key});

  @override
  State<BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends State<BackgroundPanel> {
  bool _busy = false;

  Future<void> _pick() async {
    final themes = ThemeScope.of(context);
    setState(() => _busy = true);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
      if (bytes == null) {
        if (mounted) toast(context, 'Не удалось прочитать файл');
        return;
      }
      final ext = f.extension ?? f.name.split('.').last;
      final err = await themes.setCustomBg(bytes, ext);
      if (mounted) toast(context, err ?? 'Фон поставлен');
    } catch (e) {
      if (mounted) toast(context, 'Не удалось выбрать картинку: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themes = ThemeScope.of(context);
    final p = C.p;
    final custom = C.customBg;
    final hasPicture = custom != null || p.bgAsset != null;
    return Panel(
      title: 'Фон темы «${p.name}»',
      icon: Icons.wallpaper_outlined,
      tone: C.workout,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
          custom != null
              ? 'Стоит ваша картинка. Она хранится только на этом устройстве и никуда не отправляется.'
              : p.customHint
                  ? 'Эта тема задумана под ваш арт: выберите картинку, и она встанет фоном. Хранится только на этом устройстве.'
                  : 'Можно поставить свою картинку: она хранится только на этом устройстве и никуда не отправляется.',
          style: TextStyle(color: C.muted, fontSize: 13, height: 1.35),
        ),
        SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: _busy
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.image_outlined, size: 18),
            label: Text(custom == null ? 'Выбрать своё изображение' : 'Заменить'),
          ),
          if (custom != null)
            OutlinedButton.icon(
              onPressed: _busy ? null : () => themes.removeCustomBg(),
              icon: Icon(Icons.delete_outline, size: 18),
              label: Text(p.bgAsset != null ? 'Вернуть фон темы' : 'Убрать'),
            ),
        ]),
        if (hasPicture) ...[
          SizedBox(height: 14),
          _SliderRow(label: 'Размытие', value: themes.blur(p.id).clamp(0.0, 20.0), max: 20, onChanged: themes.setBlur),
          _SliderRow(label: 'Затемнение', value: themes.dim(p.id).clamp(0.0, .9), max: .9, onChanged: themes.setDim),
        ],
      ]),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value, required this.max, required this.onChanged});
  final String label;
  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(children: [
        SizedBox(width: 100, child: Text(label, style: TextStyle(color: C.muted, fontSize: 13))),
        Expanded(child: Slider(value: value, max: max, onChanged: onChanged, activeColor: C.accent, inactiveColor: C.line)),
      ]);
}
