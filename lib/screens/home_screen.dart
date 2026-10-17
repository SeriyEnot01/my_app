import 'package:flutter/material.dart';

import '../core/scope.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/updater.dart';
import '../widgets/backdrop.dart';
import '../widgets/common.dart';
import '../widgets/hero.dart';
import '../widgets/sidebar.dart';
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
    _scroll.dispose();
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
        Scrollable.ensureVisible(ctx, duration: Duration(milliseconds: 350), curve: Curves.easeOutCubic, alignment: .05);
      }
    });
  }

  void _openLayout() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LayoutScreen()));

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SettingsScreen()));

  final _scroll = ScrollController();

  @override
  Widget build(BuildContext context) {
    ThemeScope.of(context);
    final store = StoreScope.of(context);
    final layout = LayoutScope.of(context);
    final modules = layout.visible;
    final width = MediaQuery.of(context).size.width;
    final sidebar = width >= 1180;
    final contentWidth = sidebar ? width - 268 : width;
    final twoColumns = contentWidth >= 960;

    Widget block(int i) {
      final m = modules[i];
      return Padding(
        key: _keys.putIfAbsent(m.id, () => GlobalKey()),
        padding: EdgeInsets.only(bottom: 18),
        child: m.builder(),
      );
    }

    final updateBanner = ListenableBuilder(
      listenable: Updater.instance,
      builder: (context, _) => Updater.instance.hasUpdate
          ? Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Material(
                color: Color.alphaBlend(C.workout.withOpacity(.12), C.surface),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: C.workout.withOpacity(.45)),
                ),
                child: ListTile(
                  leading: Icon(Icons.system_update_alt, color: C.workout),
                  title: Text('Доступна новая версия: сборка ${Updater.instance.latest!.build}'),
                  subtitle: Text('Нажмите, чтобы обновить', style: TextStyle(color: C.muted)),
                  onTap: _openSettings,
                ),
              ),
            )
          : SizedBox.shrink(),
    );

    // blocks keep the order from «Блоки на экране»: on wide screens they alternate left / right
    final Widget blocks = twoColumns
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < modules.length; i += 2) block(i)])),
            SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 1; i < modules.length; i += 2) block(i)])),
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < modules.length; i++) block(i)]);

    final content = RefreshIndicator(
      onRefresh: store.syncNow,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(sidebar ? 22 : 16, sidebar ? 16 : 8, sidebar ? 22 : 16, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: twoColumns ? 1360 : 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                updateBanner,
                HeroHeader(wide: width >= 760),
                SizedBox(height: 18),
                blocks,
                Center(
                  child: TextButton.icon(
                    onPressed: _openLayout,
                    icon: Icon(Icons.tune, size: 18),
                    label: Text('Настроить блоки: тренировки, рутина, заметки и другие'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (sidebar) {
      return Scaffold(
        body: AppBackdrop(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SideBar(
              onLayout: _openLayout,
              onSettings: _openSettings,
              onHome: () => _scroll.animateTo(0, duration: Duration(milliseconds: 400), curve: Curves.easeOutCubic),
            ),
            Expanded(child: content),
          ]),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/icon.png', width: 30, height: 30, errorBuilder: (_, __, ___) => SizedBox.shrink()),
          ),
          SizedBox(width: 10),
          Text('workflows', style: display(18, weight: FontWeight.w700)),
        ]),
        actions: [
          _SyncBadge(store: store, showText: width >= 640),
          ListenableBuilder(
            listenable: Updater.instance,
            builder: (context, _) => IconButton(
              icon: Badge(
                isLabelVisible: Updater.instance.hasUpdate,
                smallSize: 8,
                backgroundColor: C.workout,
                child: Icon(Icons.settings_outlined),
              ),
              tooltip: 'Настройки',
              onPressed: _openSettings,
            ),
          ),
          SizedBox(width: 4),
        ],
      ),
      body: AppBackdrop(child: content),
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
          margin: EdgeInsets.only(right: 4),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: C.line)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Dot(color, size: 7),
            if (showText) ...[
              SizedBox(width: 8),
              Text(store.status, style: TextStyle(fontSize: 12, color: C.muted)),
            ],
          ]),
        ),
      ),
    );
  }
}
