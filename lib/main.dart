import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/layout.dart';
import 'core/notifications.dart';
import 'core/scope.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'core/updater.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

// Passed at build time: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
// (GitHub Actions takes them from the repository secrets). Empty = works offline, no account.
const _rawUrl = String.fromEnvironment('SUPABASE_URL');
const _rawKey = String.fromEnvironment('SUPABASE_ANON_KEY');

/// Secrets are often pasted straight from config.js: strip quotes, commas, spaces and a trailing slash.
String _clean(String v) {
  var s = v.trim();
  s = s.replaceAll(RegExp('^[\\s"\'`]+|[\\s"\'`,;]+\$'), '');
  s = s.replaceAll(RegExp(r'/+$'), '');
  // a project URL copied with an API path: keep only https://xxxx.supabase.co
  s = s.replaceAll(RegExp(r'/(rest|auth)/v1.*$'), '');
  return s;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  var configured = false;
  final supabaseUrl = _clean(_rawUrl);
  final supabaseKey = _clean(_rawKey);
  if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      configured = true;
    } catch (e) {
      debugPrint('Supabase init failed: $e');
    }
  }
  await Reminders.init();
  final store = AppStore(prefs, configured: configured);
  final layout = LayoutController(prefs);
  final reminders = ReminderController(prefs, store);
  runApp(ZadachnikApp(store: store, layout: layout, reminders: reminders));
  await store.boot();
  await reminders.apply(force: true);
  // quiet check: shows a banner on the main screen when GitHub has a newer build
  await Updater.instance.check(quiet: true);
}

class ZadachnikApp extends StatelessWidget {
  const ZadachnikApp({super.key, required this.store, required this.layout, required this.reminders});
  final AppStore store;
  final LayoutController layout;
  final ReminderController reminders;

  @override
  Widget build(BuildContext context) {
    return StoreScope(
      store: store,
      child: LayoutScope(
        layout: layout,
        child: ReminderScope(
          controller: reminders,
          child: MaterialApp(
            title: 'Задачник',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(),
            locale: const Locale('ru'),
            supportedLocales: const [Locale('ru'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const _Root(),
          ),
        ),
      ),
    );
  }
}

class _Root extends StatefulWidget {
  const _Root();

  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  bool _wasSignedIn = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    if (store.booting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final signedIn = !store.needsAuth;
    if (_wasSignedIn && !signedIn && store.uid == null) {
      // signed out: drop this device's scheduled reminders
      ReminderScope.read(context).clearForSignOut();
    }
    _wasSignedIn = signedIn;
    return signedIn ? const HomeScreen() : const AuthScreen();
  }
}
