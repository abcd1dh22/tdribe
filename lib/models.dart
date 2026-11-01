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
const _doc = {'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv'};
const _zip = {'zip', 'rar', '7z', 'tar', 'gz', 'apk'};

class CloudFile {
  final String id, name;
  final int size, date;
  final List<Part> parts;
  const CloudFile({required this.id, required this.name, required this.size, required this.date, required this.parts});

  String get kind {
    final e = name.contains('.') ? name.split('.').last.toLowerCase() : '';
    if (_img.contains(e)) return 'img';
    if (_vid.contains(e)) return 'vid';
    if (_doc.contains(e)) return 'doc';
    if (_zip.contains(e)) return 'zip';
    return 'other';
  }

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 's': size, 'd': date, 'p': parts.map((e) => e.toJson()).toList()};
  factory CloudFile.fromJson(Map<String, dynamic> j) => CloudFile(
        id: j['id'] as String,
        name: j['n'] as String,
        size: j['s'] as int,
        date: j['d'] as int,
        parts: (j['p'] as List).map((e) => Part.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );
}
