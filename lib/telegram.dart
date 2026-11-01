import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'models.dart';

class TgException implements Exception {
  final String msg;
  TgException(this.msg);
  @override
  String toString() => msg;
}

class Telegram {
  final String token, chat;
  final Dio _d = Dio();
  static const chunk = 19 * 1024 * 1024;
  Telegram(this.token, this.chat);

  String get _api => 'https://api.telegram.org/bot$token';

  Future<Map> _call(String method, {Map<String, dynamic>? data, FormData? form, void Function(int, int)? onSend}) async {
    try {
      final r = await _d.post('$_api/$method', data: form ?? data, onSendProgress: onSend);
      final j = r.data;
      if (j is! Map || j['ok'] != true) throw TgException('টেলিগ্রাম উত্তর দেয়নি');
      return j;
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['description'] != null) throw TgException(d['description'].toString());
      throw TgException('নেটওয়ার্ক সমস্যা, আবার চেষ্টা করুন');
    }
  }

  Future<String> verify() async {
    await _call('getMe');
    final j = await _call('getChat', data: {'chat_id': chat});
    final r = j['result'] as Map;
    return (r['title'] ?? r['username'] ?? chat).toString();
  }

  Future<Map> _sendDoc(MultipartFile f, {String? caption, void Function(int, int)? onProgress}) async {
    final form = FormData.fromMap({
      'chat_id': chat,
      'document': f,
      'disable_content_type_detection': 'true',
      if (caption != null) 'caption': caption,
    });
    final j = await _call('sendDocument', form: form, onSend: onProgress);
    return j['result'] as Map;
  }

  Part _part(Map m) {
    final d = m['document'] as Map;
    return Part(d['file_id'] as String, m['message_id'] as int, (d['file_size'] ?? 0) as int);
  }

  Future<List<Part>> upload(String path, String name, int size, void Function(double) onProgress) async {
    if (size <= chunk) {
      final m = await _sendDoc(await MultipartFile.fromFile(path, filename: name),
          onProgress: (s, t) => onProgress(t <= 0 ? 0 : s / t));
      return [_part(m)];
    }
    final raf = await File(path).open();
    final parts = <Part>[];
    final n = (size / chunk).ceil();
    try {
      for (var i = 0; i < n; i++) {
        final bytes = await raf.read(chunk);
        final m = await _sendDoc(MultipartFile.fromBytes(bytes, filename: '$name.part${i + 1}'),
            caption: '#part ${i + 1}/$n', onProgress: (s, t) => onProgress((i + (t <= 0 ? 0 : s / t)) / n));
        parts.add(_part(m));
      }
    } catch (e) {
      for (final p in parts) {
        try {
          await delete(p.messageId);
        } catch (_) {}
      }
      rethrow;
    } finally {
      await raf.close();
    }
    return parts;
  }

  Future<String> _filePath(String fileId) async {
    final j = await _call('getFile', data: {'file_id': fileId});
    return (j['result'] as Map)['file_path'] as String;
  }

  Future<void> download(List<Part> parts, String dest, void Function(double) onProgress) async {
    final sink = File(dest).openWrite();
    try {
      final total = parts.fold<int>(0, (a, p) => a + p.size);
      var done = 0;
      for (final p in parts) {
        final path = await _filePath(p.fileId);
        final res = await _d.get<ResponseBody>('https://api.telegram.org/file/bot$token/$path',
            options: Options(responseType: ResponseType.stream));
        await for (final c in res.data!.stream) {
          sink.add(c);
          done += c.length;
          if (total > 0) onProgress((done / total).clamp(0.0, 1.0).toDouble());
        }
      }
    } on DioException {
      throw TgException('ডাউনলোড ব্যর্থ হয়েছে');
    } finally {
      await sink.close();
    }
  }

  Future<void> delete(int messageId) => _call('deleteMessage', data: {'chat_id': chat, 'message_id': messageId});

  Future<int> sendBackup(String json) async {
    final m = await _sendDoc(MultipartFile.fromBytes(utf8.encode(json), filename: 'telecloud_backup.json'),
        caption: '#telecloud_backup');
    final id = m['message_id'] as int;
    try {
      await _call('pinChatMessage', data: {'chat_id': chat, 'message_id': id, 'disable_notification': true});
    } on TgException {
      throw TgException('ব্যাকআপ আপলোড হয়েছে, কিন্তু পিন করা যায়নি। বটকে Pin messages অনুমতি দিন');
    }
    return id;
  }

  Future<(String, int)> fetchBackup() async {
    final j = await _call('getChat', data: {'chat_id': chat});
    final pm = (j['result'] as Map)['pinned_message'] as Map?;
    final doc = pm?['document'] as Map?;
    if (pm == null || doc == null) throw TgException('চ্যানেলে কোনো পিন করা ব্যাকআপ পাওয়া যায়নি');
    final path = await _filePath(doc['file_id'] as String);
    try {
      final r = await _d.get<String>('https://api.telegram.org/file/bot$token/$path',
          options: Options(responseType: ResponseType.plain));
      return (r.data ?? '', pm['message_id'] as int);
    } on DioException {
      throw TgException('ব্যাকআপ ডাউনলোড ব্যর্থ হয়েছে');
    }
  }
}
