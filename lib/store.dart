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
  List<Folder> folders = [];
  String? cwd;
  String sort = 'date';
  bool asc = false, grid = false;
  String token = '', channel = '';
  bool autoBackup = true, lockOn = false, locked = false;
  String? pinHash, themeKey;
  int? backupMsgId, lastBackup;
  String? upName;
  final upProgress = ValueNotifier<double>(0);
  bool _backingUp = false, _skip = false;
  Timer? _t, _bt;

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
    sort = await _ss.read(key: 'sort') ?? 'date';
    asc = (await _ss.read(key: 'asc')) == '1';
    grid = (await _ss.read(key: 'grid')) == '1';
    try {
      final f = await _indexFile();
      if (await f.exists()) {
        final m = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        files = _parse(m);
        folders = _parseFolders(m);
        backupMsgId = m['backupMsgId'] as int?;
        lastBackup = m['lastBackup'] as int?;
      }
    } catch (_) {}
  }

  List<CloudFile> _parse(Map m) =>
      (m['files'] as List).map((e) => CloudFile.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  List<Folder> _parseFolders(Map m) =>
      ((m['folders'] as List?) ?? []).map((e) => Folder.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<File> _indexFile() async => File('${(await getApplicationDocumentsDirectory()).path}/index.json');
  Map<String, dynamic> _json() =>
      {'v': 2, 'files': files.map((f) => f.toJson()).toList(), 'folders': folders.map((f) => f.toJson()).toList()};

  Future<void> _saveIndex() async {
    final f = await _indexFile();
    await f.writeAsString(jsonEncode({..._json(), 'backupMsgId': backupMsgId, 'lastBackup': lastBackup}));
  }

  Future<void> _commit() async {
    await _saveIndex();
    notifyListeners();
    _auto();
  }

  // ---------- settings ----------
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

  Future<void> setView({String? s, bool? a, bool? g}) async {
    if (s != null) sort = s;
    if (a != null) asc = a;
    if (g != null) grid = g;
    notifyListeners();
    await _ss.write(key: 'sort', value: sort);
    await _ss.write(key: 'asc', value: asc ? '1' : '0');
    await _ss.write(key: 'grid', value: grid ? '1' : '0');
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

  // ---------- queries ----------
  Folder? folderById(String? id) {
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  List<Folder> childFolders(String? p) =>
      folders.where((f) => f.parent == p).toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  List<CloudFile> get live => files.where((f) => !f.trashed).toList();
  List<CloudFile> get trash => files.where((f) => f.trashed).toList();
  List<CloudFile> filesIn(String? fo) => files.where((f) => !f.trashed && f.folder == fo).toList();
  int countIn(String id) => childFolders(id).length + filesIn(id).length;

  List<Folder> pathTo(String? id) {
    final r = <Folder>[];
    var f = folderById(id);
    while (f != null) {
      r.insert(0, f);
      f = folderById(f.parent);
    }
    return r;
  }

  Set<String> descendants(String id) {
    final s = <String>{id};
    var changed = true;
    while (changed) {
      changed = false;
      for (final f in folders) {
        if (f.parent != null && s.contains(f.parent) && s.add(f.id)) changed = true;
      }
    }
    return s;
  }

  void openFolder(String? id) {
    cwd = id;
    notifyListeners();
  }

  void up() {
    cwd = folderById(cwd)?.parent;
    notifyListeners();
  }

  // ---------- mutations ----------
  String _id() => DateTime.now().microsecondsSinceEpoch.toString();
  int get _now => DateTime.now().millisecondsSinceEpoch;

  Future<void> createFolder(String name, String? parent) async {
    folders.add(Folder(id: _id(), name: name.trim(), parent: parent, date: _now));
    await _commit();
  }

  Future<void> renameFile(CloudFile f, String n) async {
    f.name = n.trim();
    await _commit();
  }

  Future<void> renameFolder(Folder f, String n) async {
    f.name = n.trim();
    await _commit();
  }

  Future<void> toggleStar(Iterable<CloudFile> fs) async {
    final l = fs.toList();
    final all = l.every((f) => f.starred);
    for (final f in l) {
      f.starred = !all;
    }
    await _commit();
  }

  Future<void> moveFiles(Iterable<CloudFile> fs, String? target) async {
    for (final f in fs) {
      f.folder = target;
    }
    await _commit();
  }

  Future<void> moveFolder(Folder d, String? target) async {
    d.parent = target;
    await _commit();
  }

  Future<void> trashFiles(Iterable<CloudFile> fs) async {
    final n = _now;
    for (final f in fs) {
      f.trashedAt = n;
    }
    await _commit();
  }

  Future<void> trashFolder(Folder d) async {
    final ids = descendants(d.id);
    final n = _now;
    for (final f in files) {
      if (f.folder != null && ids.contains(f.folder) && !f.trashed) {
        f.trashedAt = n;
        f.folder = null;
      }
    }
    folders.removeWhere((x) => ids.contains(x.id));
    if (cwd != null && ids.contains(cwd)) cwd = d.parent;
    await _commit();
  }

  Future<void> restoreFiles(Iterable<CloudFile> fs) async {
    for (final f in fs) {
      f.trashedAt = 0;
      if (f.folder != null && folderById(f.folder) == null) f.folder = null;
    }
    await _commit();
  }

  /// Permanently deletes from the Telegram channel and the index. Returns the number of messages that could not be removed.
  Future<int> deleteForever(Iterable<CloudFile> fs) async {
    var bad = 0;
    for (final f in fs.toList()) {
      for (final p in f.parts) {
        try {
          await tg.delete(p.messageId);
        } catch (_) {
          bad++;
        }
      }
      files.removeWhere((x) => x.id == f.id);
      try {
        final c = File(await localPath(f));
        if (await c.exists()) await c.delete();
      } catch (_) {}
    }
    await _commit();
    return bad;
  }

  Future<void> addFile(String path, String name, int size, {String? folder}) async {
    upName = name;
    upProgress.value = 0;
    notifyListeners();
    try {
      final parts = await tg.upload(path, name, size, (v) => upProgress.value = v);
      files.insert(0, CloudFile(id: _id(), name: name, size: size, date: _now, parts: parts, folder: folder));
      await _saveIndex();
    } finally {
      upName = null;
      notifyListeners();
    }
    _auto();
  }

  // ---------- local cache ----------
  Future<String> localPath(CloudFile f) async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/TeleCloud');
    if (!await dir.exists()) await dir.create(recursive: true);
    return '${dir.path}/${f.id}${f.ext.isEmpty ? '' : '.${f.ext}'}';
  }

  Future<String?> cachedPath(CloudFile f) async {
    try {
      final p = await localPath(f);
      final x = File(p);
      if (await x.exists() && await x.length() == f.size) return p;
    } catch (_) {}
    return null;
  }

  Future<String> fetch(CloudFile f, void Function(double) p) async {
    final cached = await cachedPath(f);
    if (cached != null) return cached;
    final path = await localPath(f);
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

  // ---------- backup ----------
  void _auto() {
    if (!autoBackup || !configured) return;
    _bt?.cancel();
    _bt = Timer(const Duration(seconds: 20), () {
      if (!_backingUp) unawaited(backupNow().catchError((Object _) {}));
    });
  }

  Future<void> backupNow() async {
    _backingUp = true;
    try {
      final old = backupMsgId;
      final id = await tg.sendBackup(jsonEncode(_json()));
      backupMsgId = id;
      lastBackup = _now;
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
    folders = _parseFolders(m);
    cwd = null;
    backupMsgId = r.$2;
    lastBackup = _now;
    await _saveIndex();
    notifyListeners();
    return files.length;
  }
}

final store = Store();
