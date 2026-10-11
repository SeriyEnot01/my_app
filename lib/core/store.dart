import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException, HandshakeException;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'crypto.dart';
import 'dates.dart';
import 'models.dart';

enum SyncKind { ok, busy, warn, local }

class AuthFailure implements Exception {
  AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// All tasks, plans and workout logs, plus account and sync state.
/// Same data model, table and encryption as the web version, so both see the same records.
class AppStore extends ChangeNotifier {
  AppStore(this._prefs, {required this.configured});

  final SharedPreferences _prefs;
  final bool configured;
  static const _secure = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _localKey = 'zadachnik.local';
  static const _lastKey = 'zadachnik.last';

  SupabaseClient get _sb => Supabase.instance.client;

  // ---- account / screen state
  bool booting = true;
  bool needsAuth = false;
  String authHint = '';
  String? lastEmail;
  String? uid;
  String email = '';
  RecordCipher? _cipher;

  // ---- data
  Map<String, Item> items = {};
  Map<String, int> dirty = {};
  String? lastPull;
  int _seq = 0;

  // ---- sync status
  String status = '';
  SyncKind statusKind = SyncKind.local;
  bool _syncing = false, _again = false;
  Timer? _debounce, _periodic;

  // ---- shared UI state between modules
  String selectedDay = todayStr();
  String? prefillDue;
  int prefillTick = 0;
  String? workoutPrefillDate;
  int workoutPrefillTick = 0;
  final ValueNotifier<String?> scrollRequest = ValueNotifier<String?>(null);

  // ================= derived views
  List<Item> _ofKind(String k) => items.values.where((x) => x['kind'] == k).toList();
  List<Item> get tasks => _ofKind('task');
  List<Item> get plans => _ofKind('plan')..sort((a, b) => ((a['created'] ?? 0) as num).compareTo((b['created'] ?? 0) as num));
  List<Item> get logs => _ofKind('log')
    ..sort((a, b) {
      final d = str(b, 'date').compareTo(str(a, 'date'));
      return d != 0 ? d : ((b['created'] ?? 0) as num).compareTo((a['created'] ?? 0) as num);
    });

  String planName(Item log) {
    final p = items[str(log, 'planId')];
    if (p != null && p['kind'] == 'plan') return str(p, 'name');
    final n = str(log, 'planName');
    return n.isEmpty ? 'Тренировка' : n;
  }

  // ================= UI helpers
  void selectDay(String day) {
    selectedDay = day;
    notifyListeners();
  }

  void prefillTask(String day) {
    prefillDue = day;
    prefillTick++;
    notifyListeners();
    _requestScroll('add_task');
  }

  void prefillWorkout(String day) {
    workoutPrefillDate = day;
    workoutPrefillTick++;
    notifyListeners();
    _requestScroll('workouts');
  }

  void _requestScroll(String moduleId) {
    scrollRequest.value = null;
    scrollRequest.value = moduleId;
  }

  // ================= mutations
  Future<void> put(Item item) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final copy = Map<String, dynamic>.from(item);
    copy['updated'] = now;
    final id = copy['id'] as String;
    items[id] = copy;
    dirty[id] = ++_seq + now;
    _saveLocal();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> remove(String id) async {
    items.remove(id);
    dirty[id] = ++_seq + DateTime.now().millisecondsSinceEpoch;
    _saveLocal();
    notifyListeners();
    _scheduleSync();
  }

  Future<void> addTask({required String title, required String desc, required String due, required String time}) =>
      put({
        'id': newId(),
        'kind': 'task',
        'title': title,
        'desc': desc,
        'due': due,
        'time': time,
        'done': false,
        'created': DateTime.now().millisecondsSinceEpoch,
      });

  Future<void> toggleDone(Item task) => put({...task, 'done': !isDone(task)});

  // ================= local cache
  String get _cacheKey => uid != null ? 'zadachnik.u.$uid' : _localKey;

  void _loadLocal() {
    items = {};
    dirty = {};
    lastPull = null;
    final raw = _prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final it = (j['items'] as Map?) ?? {};
      items = it.map((k, v) => MapEntry(k as String, Map<String, dynamic>.from(v as Map)));
      final d = (j['dirty'] as Map?) ?? {};
      dirty = d.map((k, v) => MapEntry(k as String, (v as num).toInt()));
      lastPull = j['lastPull'] as String?;
    } catch (e) {
      debugPrint('cache read failed: $e');
    }
  }

  void _saveLocal() {
    _prefs.setString(_cacheKey, jsonEncode({'items': items, 'dirty': dirty, 'lastPull': lastPull}));
  }

  // ================= boot / accounts
  Future<void> boot() async {
    if (!configured) {
      _loadLocal();
      booting = false;
      _setStatus('Только на этом устройстве', SyncKind.local);
      return;
    }
    Map<String, dynamic>? last;
    try {
      final s = _prefs.getString(_lastKey);
      if (s != null) last = jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {}
    final session = _sb.auth.currentSession;
    final id = session?.user.id ?? last?['uid'] as String?;
    final em = session?.user.email ?? last?['email'] as String?;
    if (id != null) {
      final key = await _readKey(id);
      if (key != null) {
        booting = false;
        await _startUser(id, em ?? '', key);
        return;
      }
    }
    lastEmail = em;
    authHint = session != null ? 'Введите пароль, чтобы расшифровать задачи на этом устройстве.' : '';
    needsAuth = true;
    booting = false;
    notifyListeners();
  }

  Future<List<int>?> _readKey(String id) async {
    try {
      final v = await _secure.read(key: 'enc.$id');
      return v == null ? null : base64Decode(v);
    } catch (e) {
      debugPrint('key read failed: $e');
      return null;
    }
  }

  Future<void> _startUser(String id, String mail, List<int> key) async {
    uid = id;
    email = mail;
    _cipher = RecordCipher(key);
    await _prefs.setString(_lastKey, jsonEncode({'uid': id, 'email': mail}));
    _loadLocal();
    needsAuth = false;
    authHint = '';
    notifyListeners();
    _periodic?.cancel();
    _periodic = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    unawaited(syncNow());
  }

  Future<void> signIn(String mail, String password) async {
    final keys = await deriveKeys(mail, password);
    try {
      final res = await _sb.auth.signInWithPassword(email: mail.trim(), password: keys.authPassword);
      final user = res.user;
      if (user == null) throw AuthFailure('Не удалось войти. Попробуйте ещё раз.');
      await _secure.write(key: 'enc.${user.id}', value: base64Encode(keys.encKey));
      await _startUser(user.id, user.email ?? mail.trim(), keys.encKey);
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('confirm')) throw AuthFailure('Почта ещё не подтверждена. Откройте письмо от Supabase и перейдите по ссылке.');
      if (m.contains('invalid')) {
        throw AuthFailure('Неверная почта или пароль. Проверьте раскладку, заглавные буквы и пробелы.');
      }
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      if (_isNetwork(e)) throw AuthFailure('Нет связи с сервером. Проверьте интернет.');
      throw AuthFailure('Не получилось войти: $e');
    }
  }

  /// Returns true when signed in right away, false when the email must be confirmed first.
  Future<bool> signUp(String mail, String password) async {
    final keys = await deriveKeys(mail, password);
    try {
      final res = await _sb.auth.signUp(email: mail.trim(), password: keys.authPassword);
      final user = res.user;
      if (res.session != null && user != null) {
        await _secure.write(key: 'enc.${user.id}', value: base64Encode(keys.encKey));
        await _startUser(user.id, user.email ?? mail.trim(), keys.encKey);
        return true;
      }
      return false;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('registered') || m.contains('exists')) throw AuthFailure('Такой аккаунт уже есть. Войдите.');
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      if (_isNetwork(e)) throw AuthFailure('Нет связи с сервером. Проверьте интернет.');
      throw AuthFailure('Не получилось создать аккаунт: $e');
    }
  }

  /// Returns false (and does nothing) when unsent changes exist and [force] is false.
  Future<bool> signOut({bool force = false}) async {
    if (dirty.isNotEmpty && !force) {
      await syncNow();
      if (dirty.isNotEmpty) return false;
    }
    _periodic?.cancel();
    try {
      await _sb.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
    if (uid != null) {
      try {
        await _secure.delete(key: 'enc.$uid');
      } catch (_) {}
      await _prefs.remove(_cacheKey);
    }
    await _prefs.remove(_lastKey);
    lastEmail = email;
    uid = null;
    email = '';
    _cipher = null;
    items = {};
    dirty = {};
    lastPull = null;
    needsAuth = true;
    authHint = '';
    notifyListeners();
    return true;
  }

  // ================= sync
  void _setStatus(String text, SyncKind kind) {
    status = text;
    statusKind = kind;
    notifyListeners();
  }

  void _idleStatus() {
    if (!configured) return _setStatus('Только на этом устройстве', SyncKind.local);
    _setStatus(dirty.isEmpty ? 'Синхронизировано' : 'Ждёт отправки: ${dirty.length}', dirty.isEmpty ? SyncKind.ok : SyncKind.warn);
  }

  void _scheduleSync([Duration delay = const Duration(milliseconds: 700)]) {
    if (!configured) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  bool _isNetwork(Object e) {
    if (e is SocketException || e is TimeoutException || e is HandshakeException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection refused') ||
        s.contains('Connection reset') ||
        s.contains('Network is unreachable');
  }

  bool _isAuthError(Object e) {
    if (e is AuthException) return true;
    if (e is PostgrestException) {
      return e.code == 'PGRST301' || e.code == 'PGRST303' || e.code == '401' || e.message.contains('JWT');
    }
    return false;
  }

  Future<void> syncNow() async {
    if (!configured || uid == null || _cipher == null || needsAuth) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      _setStatus('Синхронизация…', SyncKind.busy);
      await _push();
      await _pull();
      _saveLocal();
      _idleStatus();
    } catch (e) {
      if (_isAuthError(e)) {
        lastEmail = email;
        authHint = 'Сессия закончилась. Войдите снова, задачи на этом устройстве сохранены.';
        needsAuth = true;
        _setStatus('Войдите снова', SyncKind.warn);
      } else if (_isNetwork(e)) {
        _setStatus(dirty.isEmpty ? 'Нет сети' : 'Нет сети, изменения отправятся позже', SyncKind.warn);
      } else {
        debugPrint('sync failed: $e');
        _setStatus('Не удалось синхронизировать, повторим позже', SyncKind.warn);
      }
    } finally {
      _syncing = false;
      if (_again) {
        _again = false;
        _scheduleSync(const Duration(milliseconds: 300));
      }
    }
  }

  Future<void> _push() async {
    final ids = dirty.keys.toList();
    for (var i = 0; i < ids.length; i += 200) {
      final chunk = ids.sublist(i, min(i + 200, ids.length));
      final marks = {for (final id in chunk) id: dirty[id]};
      final rows = <Map<String, dynamic>>[];
      for (final id in chunk) {
        final item = items[id];
        if (item != null) {
          final enc = await _cipher!.encrypt(item, id);
          rows.add({'id': id, 'user_id': uid, 'deleted': false, 'iv': enc.iv, 'data': enc.data});
        } else {
          rows.add({'id': id, 'user_id': uid, 'deleted': true, 'iv': null, 'data': null});
        }
      }
      await _sb.from('items').upsert(rows, onConflict: 'user_id,id');
      for (final id in chunk) {
        if (dirty[id] == marks[id]) dirty.remove(id);
      }
      _saveLocal();
    }
  }

  Future<void> _pull() async {
    var maxSeen = lastPull;
    var from = 0;
    const page = 1000;
    var bad = 0;
    // re-read a minute before the last seen change so nothing committed late is missed
    final since = lastPull == null ? null : DateTime.parse(lastPull!).toUtc().subtract(const Duration(seconds: 60)).toIso8601String();
    while (true) {
      var query = _sb.from('items').select('id,iv,data,deleted,updated_at');
      if (since != null) query = query.gt('updated_at', since);
      final List<Map<String, dynamic>> rows = await query.order('updated_at', ascending: true).range(from, from + page - 1);
      for (final row in rows) {
        final id = row['id'] as String;
        final up = row['updated_at'] as String;
        if (maxSeen == null || up.compareTo(maxSeen) > 0) maxSeen = up;
        if (dirty.containsKey(id)) continue;
        if (row['deleted'] == true) {
          items.remove(id);
          continue;
        }
        try {
          items[id] = await _cipher!.decrypt(row['iv'] as String, row['data'] as String, id);
        } catch (_) {
          bad++;
        }
      }
      if (rows.length < page) break;
      from += page;
    }
    lastPull = maxSeen;
    if (bad > 0) debugPrint('$bad records could not be decrypted with this password');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _periodic?.cancel();
    scrollRequest.dispose();
    super.dispose();
  }
}
