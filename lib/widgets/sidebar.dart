import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import 'common.dart';

/// Left rail on wide screens: brand, navigation, jump-to-block list and sync status.
class SideBar extends StatelessWidget {
  const SideBar({super.key, required this.onLayout, required this.onSettings, required this.onHome});
  final VoidCallback onLayout;
  final VoidCallback onSettings;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final layout = LayoutScope.of(context);
    final modules = layout.visible;
    final statusColor = switch (store.statusKind) {
      SyncKind.ok => C.workout,
      SyncKind.busy => C.accent,
      SyncKind.warn => C.deadline,
      SyncKind.local => C.faint,
    };
    return Container(
      width: 252,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: C.surface.withOpacity(.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/icon.png', width: 40, height: 40, errorBuilder: (_, __, ___) => const SizedBox(width: 40, height: 40)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('Задачник', style: display(18, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 26),
          _NavItem(icon: Icons.space_dashboard_outlined, label: 'Главная', selected: true, onTap: onHome),
          _NavItem(icon: Icons.dashboard_customize_outlined, label: 'Блоки на экране', onTap: onLayout),
          ListenableBuilder(
            listenable: Updater.instance,
            builder: (context, _) => _NavItem(
              icon: Icons.settings_outlined,
              label: 'Настройки',
              onTap: onSettings,
              badge: Updater.instance.hasUpdate ? 'новая версия' : null,
            ),
          ),
          const SizedBox(height: 22),
          const Padding(padding: EdgeInsets.only(left: 10, bottom: 8), child: SectionLabel('Перейти к блоку')),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final m in modules)
                  _NavItem(icon: m.icon, label: m.title, dense: true, onTap: () => store.scrollTo(m.id)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Dot(statusColor, size: 9),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(store.status.isEmpty ? 'Готово' : store.status, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5)),
                  if (store.email.isNotEmpty)
                    Text(store.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: C.faint)),
                ]),
              ),
              if (store.configured)
                IconButton(
                  icon: const Icon(Icons.sync, size: 18, color: C.muted),
                  tooltip: 'Синхронизировать',
                  onPressed: store.syncNow,
                  visualDensity: VisualDensity.compact,
                ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.icon, required this.label, required this.onTap, this.selected = false, this.dense = false, this.badge});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool dense;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? C.accent.withOpacity(.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 8 : 11),
            child: Row(children: [
              Icon(icon, size: dense ? 17 : 20, color: selected ? C.accent : C.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: dense ? 13.5 : 14.5,
                    color: selected ? C.fg : (dense ? C.muted : C.fg),
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: C.workout.withOpacity(.18), borderRadius: BorderRadius.circular(99)),
                  child: Text(badge!, style: const TextStyle(fontSize: 10.5, color: C.workout)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
