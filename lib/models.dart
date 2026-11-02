import 'package:flutter/material.dart';

class Part {
  final String fileId;
  final int messageId;
  final int size;
  const Part(this.fileId, this.messageId, this.size);
  Map<String, dynamic> toJson() => {'f': fileId, 'm': messageId, 's': size};
  factory Part.fromJson(Map<String, dynamic> j) => Part(j['f'] as String, j['m'] as int, j['s'] as int);
}

class Kind {
  final String label;
  final IconData icon;
  final List<Color> colors;
  const Kind(this.label, this.icon, this.colors);
}

const kinds = <String, Kind>{
  'img': Kind('ছবি', Icons.image_outlined, [Color(0xFFFF8A5B), Color(0xFFF0568C)]),
  'vid': Kind('ভিডিও', Icons.videocam_outlined, [Color(0xFF4FACFE), Color(0xFF6A5CF0)]),
  'doc': Kind('নথি', Icons.description_outlined, [Color(0xFFF5576C), Color(0xFFD6336C)]),
  'zip': Kind('আর্কাইভ', Icons.folder_zip_outlined, [Color(0xFFF6B73C), Color(0xFFF28C2D)]),
  'other': Kind('অন্যান্য', Icons.insert_drive_file_outlined, [Color(0xFF36C5A0), Color(0xFF1A9FB8)]),
};

const _img = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic'};
const _vid = {'mp4', 'mkv', 'mov', 'avi', 'webm', '3gp'};
const _doc = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'};
const _txt = {'txt', 'csv', 'json', 'md', 'log', 'xml', 'html', 'css', 'js', 'dart', 'py', 'java', 'kt', 'yaml', 'yml', 'ini', 'sql'};
const _zip = {'zip', 'rar', '7z', 'tar', 'gz', 'apk'};

class Folder {
  final String id;
  String name;
  String? parent;
  final int date;
  Folder({required this.id, required this.name, this.parent, required this.date});
  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'p': parent, 'd': date};
  factory Folder.fromJson(Map<String, dynamic> j) =>
      Folder(id: j['id'] as String, name: j['n'] as String, parent: j['p'] as String?, date: j['d'] as int);
}

class CloudFile {
  final String id;
  String name;
  final int size, date;
  final List<Part> parts;
  String? folder;
  bool starred;
  int trashedAt;
  CloudFile({
    required this.id,
    required this.name,
    required this.size,
    required this.date,
    required this.parts,
    this.folder,
    this.starred = false,
    this.trashedAt = 0,
  });

  bool get trashed => trashedAt > 0;
  String get ext => name.contains('.') ? name.split('.').last.toLowerCase() : '';

  String get kind {
    final e = ext;
    if (_img.contains(e)) return 'img';
    if (_vid.contains(e)) return 'vid';
    if (_doc.contains(e) || _txt.contains(e)) return 'doc';
    if (_zip.contains(e)) return 'zip';
    return 'other';
  }

  /// img | vid | pdf | txt | none  (none = can't be shown inside the app)
  String get viewer {
    if (kind == 'img') return 'img';
    if (kind == 'vid') return 'vid';
    if (ext == 'pdf') return 'pdf';
    if (_txt.contains(ext)) return 'txt';
    return 'none';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'n': name,
        's': size,
        'd': date,
        'p': parts.map((e) => e.toJson()).toList(),
        'fo': folder,
        'st': starred ? 1 : 0,
        'tr': trashedAt,
      };

  factory CloudFile.fromJson(Map<String, dynamic> j) => CloudFile(
        id: j['id'] as String,
        name: j['n'] as String,
        size: j['s'] as int,
        date: j['d'] as int,
        parts: (j['p'] as List).map((e) => Part.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
        folder: j['fo'] as String?,
        starred: j['st'] == 1,
        trashedAt: (j['tr'] ?? 0) as int,
      );
}
