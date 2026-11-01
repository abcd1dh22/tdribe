import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'telegram.dart';

class Store extends ChangeNotifier {
  static const _ss = FlutterSecureStorage();
  List<CloudFile> files = [];
  String token = '', channel = '';
  bool autoBackup = true, lockOn = false, locked = false;
  String? pinHash, themeKey;
  int? backupMsgId, lastBackup;
  String? upName;
  final upProgress = ValueNotifier<double>(0);
  bool _backingUp = false, _skip = false;
  Timer? _t;

  bool get uploading => upName != null;
  bool get configured => token.isNotEmpty && channel.isNotEmpty;
  Telegram get tg => Telegram(token, channel);
  ThemeMode get themeMode =>
      themeKey == 'dark' ? ThemeMode.dark : (themeKey == 'light' ? ThemeMode.light : ThemeMode.system);

  Future<void> load() async {
    token = await _ss.read(key: 'token') ?? '';
    channel = await _ss.read(key: 'channel') ?? '';
    autoBackup = (await _ss.read(key: 'auto')) != '0';
    pinHash = await _ss.read(key: 'pin');
    lockOn = (await _ss.read(key: 'lock')) == '1' && pinHash != null;
    locked = lockOn;
    themeKey = await _ss.read(key: 'theme');
    try {
      final f = await _indexFile();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        files = _parse(m);
        backupMsgId = m['backupMsgId'] as int?;
        lastBackup = m['lastBackup'] as int?;
      }
    } catch (_) {}
  }

  List<CloudFile> _parse(Map m) =>
      (m['files'] as List).map((e) => CloudFile.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<File> _indexFile() async => File('${(await getApplicationDocumentsDirectory()).path}/index.json');
  Map<String, dynamic> _json() => {'v': 1, 'files': files.map((f) => f.toJson()).toList()};

  Future<void> _saveIndex() async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode({..._json(), 'backupMsgId': backupMsgId, 'lastBackup': lastBackup}));
  }

  // ---- settings ----
  Future<void> setConn({String? t, String? c}) async {
    if (t != null) {
      token = t.trim();
      await _ss.write(key: 'token', value: token);
    }
    if (c != null) {
      channel = c.trim();
      await _ss.write(key: 'channel', value: channel);
    }
    notifyListeners();
  }

  Future<void> setAuto(bool v) async {
    autoBackup = v;
    await _ss.write(key: 'auto', value: v ? '1' : '0');
    notifyListeners();
  }

  Future<void> setTheme(String k) async {
    themeKey = k;
    await _ss.write(key: 'theme', value: k);
    notifyListeners();
  }

  String _hash(String p) => sha256.convert(utf8.encode('telecloud:$p')).toString();
  bool checkPin(String p) => _hash(p) == pinHash;

  Future<void> enableLock(String pin) async {
    pinHash = _hash(pin);
    lockOn = true;
    locked = false;
    await _ss.write(key: 'pin', value: pinHash);
    await _ss.write(key: 'lock', value: '1');
    notifyListeners();
  }

  Future<void> disableLock() async {
    lockOn = false;
    locked = false;
    pinHash = null;
    await _ss.delete(key: 'pin');
    await _ss.write(key: 'lock', value: '0');
    notifyListeners();
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  void allowLeave() {
    _skip = true;
    _t?.cancel();
    _t = Timer(const Duration(seconds: 90), () => _skip = false);
  }

  void onPaused() {
    if (lockOn && !_skip) {
      locked = true;
      notifyListeners();
    }
  }

  void onResumed() {
    _skip = false;
    _t?.cancel();
  }

  // ---- files ----
  Future<void> addFile(String path, String name, int size) async {
    upName = name;
    upProgress.value = 0;
    notifyListeners();
    try {
      final parts = await tg.upload(path, name, size, (v) => upProgress.value = v);
      files.insert(
          0,
          CloudFile(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
              size: size,
              date: DateTime.now().millisecondsSinceEpoch,
              parts: parts));
      await _saveIndex();
    } finally {
      upName = null;
      notifyListeners();
    }
    _auto();
  }

  Future<bool> removeFile(CloudFile f) async {
    var ok = true;
    for (final p in f.parts) {
      try {
        await tg.delete(p.messageId);
      } catch (_) {
        ok = false;
      }
    }
    files.removeWhere((x) => x.id == f.id);
    try {
      final c = File(await localPath(f));
      if (await c.exists()) await c.delete();
    } catch (_) {}
    await _saveIndex();
    notifyListeners();
    _auto();
    return ok;
  }

  Future<String> localPath(CloudFile f) async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/TeleCloud');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/${f.id}_${f.name}';
  }

  Future<String> fetch(CloudFile f, void Function(double) p) async {
    final path = await localPath(f);
    final file = File(path);
    if (await file.exists() && await file.length() == f.size) return path;
    final tmp = '$path.part';
    try {
      await tg.download(f.parts, tmp, p);
      await File(tmp).rename(path);
    } catch (e) {
      try {
        await File(tmp).delete();
      } catch (_) {}
      rethrow;
    }
    return path;
  }

  // ---- backup ----
  void _auto() {
    if (autoBackup && configured && !_backingUp) {
      unawaited(backupNow().catchError((Object _) {}));
    }
  }

  Future<void> backupNow() async {
    _backingUp = true;
    try {
      final old = backupMsgId;
      final id = await tg.sendBackup(jsonEncode(_json()));
      backupMsgId = id;
      lastBackup = DateTime.now().millisecondsSinceEpoch;
      if (old != null) {
        try {
          await tg.delete(old);
        } catch (_) {}
      }
      await _saveIndex();
      notifyListeners();
    } finally {
      _backingUp = false;
    }
  }

  Future<int> restore() async {
    final r = await tg.fetchBackup();
    final m = jsonDecode(r.$1) as Map<String, dynamic>;
    files = _parse(m);
    backupMsgId = r.$2;
    lastBackup = DateTime.now().millisecondsSinceEpoch;
    await _saveIndex();
    notifyListeners();
    return files.length;
  }
}

final store = Store();
