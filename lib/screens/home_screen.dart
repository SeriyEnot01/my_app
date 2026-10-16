import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/common.dart';
import 'layout_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final Map<String, GlobalKey> _keys = {};
  AppStore? _store;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = StoreScope.read(context);
    if (!identical(s, _store)) {
      _store?.scrollRequest.removeListener(_onScrollRequest);
      _store = s;
      s.scrollRequest.addListener(_onScrollRequest);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store?.scrollRequest.removeListener(_onScrollRequest);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _store?.syncNow();
    }
  }

  void _onScrollRequest() {
    final id = _store?.scrollRequest.value;
    if (id == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[id]?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: .05);
      }
    });
  }

  void _openLayout() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LayoutScreen()));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final layout = LayoutScope.of(context);
    final modules = layout.visible;
    final now = DateTime.now();
    final wide = MediaQuery.of(context).size.width >= 640;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Задачник', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
            Text(
              '${now.day} ${monthsGen[now.month - 1]}, ${weekdaysFull[now.weekday]}',
              style: const TextStyle(fontSize: 12.5, color: C.muted),
            ),
          ],
        ),
        actions: [
          _SyncBadge(store: store, showText: wide),
          ListenableBuilder(
            listenable: Updater.instance,
            builder: (context, _) => IconButton(
              icon: Badge(
                isLabelVisible: Updater.instance.hasUpdate,
                smallSize: 8,
                backgroundColor: C.workout,
                child: const Icon(Icons.settings_outlined),
              ),
              tooltip: 'Настройки',
              onPressed: _openSettings,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: store.syncNow,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListenableBuilder(
                    listenable: Updater.instance,
                    builder: (context, _) => Updater.instance.hasUpdate
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Material(
                              color: Color.alphaBlend(C.workout.withOpacity(.12), C.surface),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: C.workout.withOpacity(.45)),
                              ),
                              child: ListTile(
                                leading: const Icon(Icons.system_update_alt, color: C.workout),
                                title: Text('Доступна новая версия: сборка ${Updater.instance.latest!.build}'),
                                subtitle: const Text('Нажмите, чтобы обновить', style: TextStyle(color: C.muted)),
                                onTap: _openSettings,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  for (final m in modules)
                    Padding(
                      key: _keys.putIfAbsent(m.id, () => GlobalKey()),
                      padding: const EdgeInsets.only(bottom: 16),
                      child: m.builder(),
                    ),
                  TextButton.icon(
                    onPressed: _openLayout,
                    icon: const Icon(Icons.tune, size: 18),
                    label: const Text('Настроить блоки: тренировки, талисман и другие'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.store, required this.showText});
  final AppStore store;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final color = switch (store.statusKind) {
      SyncKind.ok => C.workout,
      SyncKind.busy => C.accent,
      SyncKind.warn => C.deadline,
      SyncKind.local => C.faint,
    };
    return Tooltip(
      message: store.status.isEmpty ? 'Синхронизация' : store.status,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: store.syncNow,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: showText ? 10 : 8, vertical: 6),
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Dot(color, size: 7),
            if (showText) ...[
              const SizedBox(width: 8),
              Text(store.status, style: const TextStyle(fontSize: 12, color: C.muted)),
            ],
          ]),
        ),
      ),
    );
  }
}
