import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Set by GitHub Actions: --dart-define=BUILD_NUMBER=<run number> --dart-define=UPDATE_REPO=<owner/repo>.
/// Local builds have 0 / empty and never offer updates.
const appBuild = int.fromEnvironment('BUILD_NUMBER');
const updateRepo = String.fromEnvironment('UPDATE_REPO');

class ReleaseInfo {
  ReleaseInfo({required this.build, required this.notes, required this.url, required this.size});
  final int build;
  final String notes;
  final String url;
  final int size;
}

/// Checks GitHub Releases of this repository (tags "build-N", published by the workflow),
/// downloads the file for this platform and starts the installer.
class Updater extends ChangeNotifier {
  Updater._();
  static final Updater instance = Updater._();
  static const _channel = MethodChannel('zadachnik/updater');

  ReleaseInfo? latest;
  bool checking = false;
  bool downloading = false;
  double? progress;
  String message = '';
  bool error = false;

  bool get platformSupported => !kIsWeb && (Platform.isAndroid || Platform.isWindows);
  bool get configured => updateRepo.isNotEmpty;
  bool get hasUpdate => latest != null && latest!.build > appBuild && latest!.url.isNotEmpty;

  void _say(String text, {bool isError = false}) {
    message = text;
    error = isError;
    notifyListeners();
  }

  String _short(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Failed host lookup') || s.contains('TimeoutException')) {
      return 'нет связи с GitHub';
    }
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  bool _isOurFile(String name) {
    final n = name.toLowerCase();
    return Platform.isAndroid ? n.endsWith('.apk') : n.endsWith('setup.exe');
  }

  Future<void> check({bool quiet = false}) async {
    if (!platformSupported || !configured || checking || downloading) return;
    checking = true;
    if (quiet) {
      notifyListeners();
    } else {
      _say('Проверяем…');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('https://api.github.com/repos/$updateRepo/releases/latest'));
      req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      req.headers.set(HttpHeaders.userAgentHeader, 'zadachnik-app');
      final res = await req.close().timeout(const Duration(seconds: 20));
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode == 404) {
        latest = null;
        if (!quiet) {
          _say('Опубликованных версий пока нет. Если репозиторий приватный, сделайте его публичным: '
              'приложение не может читать приватные релизы.', isError: true);
        }
        return;
      }
      if (res.statusCode != 200) throw HttpException('GitHub ответил ${res.statusCode}');
      final j = jsonDecode(body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString();
      final m = RegExp(r'(\d+)$').firstMatch(tag);
      var url = '';
      var size = 0;
      for (final a in (j['assets'] as List? ?? const [])) {
        final asset = a as Map<String, dynamic>;
        if (_isOurFile((asset['name'] ?? '').toString())) {
          url = (asset['browser_download_url'] ?? '').toString();
          size = (asset['size'] as num?)?.toInt() ?? 0;
          break;
        }
      }
      latest = ReleaseInfo(
        build: m == null ? 0 : int.parse(m.group(1)!),
        notes: (j['body'] ?? '').toString().trim(),
        url: url,
        size: size,
      );
      if (hasUpdate) {
        _say('Доступна новая версия: сборка ${latest!.build}.');
      } else if (!quiet) {
        _say('У вас последняя версия.');
      }
    } catch (e) {
      if (!quiet) _say('Не удалось проверить: ${_short(e)}', isError: true);
    } finally {
      checking = false;
      client.close(force: true);
      notifyListeners();
    }
  }

  Future<void> downloadAndInstall() async {
    final rel = latest;
    if (rel == null || rel.url.isEmpty || downloading) return;
    if (Platform.isAndroid) {
      final can = await _channel.invokeMethod<bool>('canInstall') ?? true;
      if (!can) {
        await _channel.invokeMethod<void>('openInstallSettings');
        _say('Разрешите приложению workflows «Установку неизвестных приложений», вернитесь и нажмите «Обновить» ещё раз.');
        return;
      }
    }
    downloading = true;
    progress = 0;
    _say('Скачиваем…');
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}${Platform.pathSeparator}updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}${Platform.isAndroid ? 'workflows-update.apk' : 'workflows-Setup.exe'}');
      if (await file.exists()) await file.delete();

      final req = await client.getUrl(Uri.parse(rel.url));
      req.headers.set(HttpHeaders.userAgentHeader, 'zadachnik-app');
      final res = await req.close();
      if (res.statusCode != 200) throw HttpException('загрузка не удалась (${res.statusCode})');
      final total = res.contentLength > 0 ? res.contentLength : rel.size;
      var received = 0;
      final sink = file.openWrite();
      try {
        await for (final chunk in res) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final p = received / total;
            if (progress == null || p - progress! >= 0.01 || p >= 1) {
              progress = p;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.close();
      }
      progress = 1;
      if (Platform.isAndroid) {
        await _channel.invokeMethod<bool>('install', {'path': file.path});
        _say('Подтвердите установку в окне Android. Данные сохранятся.');
      } else {
        _say('Запускаем установщик, приложение перезапустится…');
        await Process.start(file.path, ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'], mode: ProcessStartMode.detached);
        await Future<void>.delayed(const Duration(milliseconds: 600));
        exit(0);
      }
    } catch (e) {
      _say('Не удалось обновить: ${_short(e)}', isError: true);
    } finally {
      downloading = false;
      client.close(force: true);
      notifyListeners();
    }
  }
}
