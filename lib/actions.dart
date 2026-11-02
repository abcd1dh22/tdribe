import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'models.dart';
import 'screens/preview.dart';
import 'screens/viewer.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets.dart';

class FolderChoice {
  final String? id;
  const FolderChoice(this.id);
}

Future<T?> _show<T>(BuildContext c, Widget Function(BuildContext) b) =>
    showModalBottomSheet<T>(context: c, backgroundColor: Colors.transparent, isScrollControlled: true, builder: b);

Widget _sheet(BuildContext c, List<Widget> kids, {Widget? head}) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).padding.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .72),
        decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [if (head != null) head, ...kids])),
      ),
    );

class _Act extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _Act(this.icon, this.label, this.onTap, {this.danger = false});

  @override
  Widget build(BuildContext context) {
    final col = danger ? AppColors.danger : context.tx;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: danger ? col : context.muted, size: 22),
          const SizedBox(width: 16),
          Expanded(child: Text(label, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: col))),
        ]),
      ),
    );
  }
}

Future<bool> confirmSheet(BuildContext c,
    {required IconData icon, required String title, required String body, required String ok}) async {
  final r = await _show<bool>(
    c,
    (s) => Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(s).padding.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        decoration: BoxDecoration(color: s.sf, borderRadius: BorderRadius.circular(30)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: const Color(0x1FE5484D), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: AppColors.danger, size: 28),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: s.tx)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: TextStyle(color: s.muted, fontSize: 14.5)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: FlatBtn(label: 'বাতিল', bg: s.sf2, fg: s.tx, onTap: () => Navigator.pop(s, false))),
            const SizedBox(width: 12),
            Expanded(child: FlatBtn(label: ok, bg: AppColors.danger, fg: Colors.white, onTap: () => Navigator.pop(s, true))),
          ]),
        ]),
      ),
    ),
  );
  return r == true;
}

Future<String?> askText(BuildContext c, String title, {String initial = '', String hint = ''}) {
  final ctl = TextEditingController(text: initial);
  return showDialog<String>(
    context: c,
    builder: (d) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: d.sf2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('বাতিল')),
        FilledButton(onPressed: () => Navigator.pop(d, ctl.text.trim().isEmpty ? null : ctl.text), child: const Text('ঠিক আছে')),
      ],
    ),
  );
}

Future<FolderChoice?> pickFolder(BuildContext c, {Set<String> exclude = const {}}) {
  return _show<FolderChoice>(c, (s) {
    final rows = <Widget>[_Act(Icons.cloud_outlined, 'আমার ক্লাউড (মূল)', () => Navigator.pop(s, const FolderChoice(null)))];
    void walk(String? p, int d) {
      for (final f in store.childFolders(p)) {
        if (exclude.contains(f.id)) continue;
        rows.add(Padding(
          padding: EdgeInsets.only(left: 18.0 * d),
          child: _Act(Icons.folder_outlined, f.name, () => Navigator.pop(s, FolderChoice(f.id))),
        ));
        walk(f.id, d + 1);
      }
    }

    walk(null, 1);
    return _sheet(s, rows,
        head: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Align(
              alignment: Alignment.centerLeft,
              child: Text('কোথায় সরাবেন?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: s.tx))),
        ));
  });
}

void openFile(BuildContext c, CloudFile f, List<CloudFile> siblings) {
  var items = [f];
  var idx = 0;
  if (f.viewer == 'img') {
    items = siblings.where((x) => x.viewer == 'img' && !x.trashed).toList();
    idx = items.indexWhere((x) => x.id == f.id);
    if (idx < 0) {
      items = [f];
      idx = 0;
    }
  }
  Navigator.push(c, slideRoute(ViewerScreen(items: items, index: idx)));
}

Future<void> openExternal(BuildContext c, CloudFile f) async {
  final m = ScaffoldMessenger.of(c);
  toastM(m, 'ফাইল প্রস্তুত হচ্ছে…');
  try {
    final p = await store.fetch(f, (_) {});
    store.allowLeave();
    final r = await OpenFilex.open(p);
    if (r.type != ResultType.done) {
      toastM(m, 'এই ফাইল খোলার মতো কোনো অ্যাপ নেই', error: true);
    } else {
      m.clearSnackBars();
    }
  } catch (e) {
    toastM(m, '$e', error: true);
  }
}

Future<void> deleteForeverFlow(BuildContext c, List<CloudFile> fs) async {
  final ok = await confirmSheet(c,
      icon: Icons.delete_forever_outlined,
      title: 'স্থায়ীভাবে মুছবেন?',
      body: 'টেলিগ্রাম চ্যানেল থেকেও মুছে যাবে, আর ফেরানো যাবে না।',
      ok: 'মুছুন');
  if (!ok || !c.mounted) return;
  final m = ScaffoldMessenger.of(c);
  final bad = await store.deleteForever(fs);
  toastM(m, bad == 0 ? 'স্থায়ীভাবে মুছে ফেলা হয়েছে' : 'তালিকা থেকে মুছেছে; চ্যানেলের কিছু মেসেজ মোছা যায়নি', error: bad != 0);
}

Future<void> showFileSheet(BuildContext c, CloudFile f, {List<CloudFile> siblings = const []}) {
  return _show<void>(c, (s) {
    void close() => Navigator.pop(s);
    final k = kinds[f.kind]!;
    final List<Widget> acts;
    if (f.trashed) {
      acts = [
        _Act(Icons.restore_from_trash_rounded, 'ফিরিয়ে আনুন', () {
          close();
          store.restoreFiles([f]);
          toast(c, 'ফাইল ফিরিয়ে আনা হয়েছে');
        }),
        _Act(Icons.delete_forever_outlined, 'স্থায়ীভাবে মুছুন', () {
          close();
          deleteForeverFlow(c, [f]);
        }, danger: true),
      ];
    } else {
      acts = [
        _Act(Icons.visibility_outlined, 'খুলুন', () {
          close();
          openFile(c, f, siblings);
        }),
        _Act(f.starred ? Icons.star_rounded : Icons.star_border_rounded, f.starred ? 'তারকা সরান' : 'তারকা যোগ করুন', () {
          close();
          store.toggleStar([f]);
        }),
        _Act(Icons.drive_file_rename_outline_rounded, 'নাম পরিবর্তন', () async {
          close();
          final n = await askText(c, 'নাম পরিবর্তন', initial: f.name);
          if (n != null) store.renameFile(f, n);
        }),
        _Act(Icons.drive_file_move_outlined, 'সরান', () async {
          close();
          final r = await pickFolder(c);
          if (r != null) {
            await store.moveFiles([f], r.id);
            if (c.mounted) toast(c, 'ফাইল সরানো হয়েছে');
          }
        }),
        _Act(Icons.info_outline_rounded, 'বিস্তারিত', () {
          close();
          Navigator.push(c, slideRoute(PreviewScreen(file: f)));
        }),
        _Act(Icons.open_in_new_rounded, 'অন্য অ্যাপে খুলুন', () {
          close();
          openExternal(c, f);
        }),
        _Act(Icons.delete_outline_rounded, 'ট্র্যাশে পাঠান', () {
          close();
          store.trashFiles([f]);
          toast(c, 'ট্র্যাশে পাঠানো হয়েছে');
        }, danger: true),
      ];
    }
    return _sheet(
      s,
      acts,
      head: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: LinearGradient(colors: k.colors), borderRadius: BorderRadius.circular(14)),
            child: Icon(k.icon, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: s.tx)),
              Text('${fmtSize(f.size)} · ${fmtDate(f.date)}', style: TextStyle(fontSize: 12.5, color: s.muted)),
            ]),
          ),
        ]),
      ),
    );
  });
}

Future<void> showFolderSheet(BuildContext c, Folder d) {
  return _show<void>(c, (s) {
    void close() => Navigator.pop(s);
    return _sheet(
      s,
      [
        _Act(Icons.folder_open_rounded, 'খুলুন', () {
          close();
          store.openFolder(d.id);
        }),
        _Act(Icons.drive_file_rename_outline_rounded, 'নাম পরিবর্তন', () async {
          close();
          final n = await askText(c, 'ফোল্ডারের নাম', initial: d.name);
          if (n != null) store.renameFolder(d, n);
        }),
        _Act(Icons.drive_file_move_outlined, 'সরান', () async {
          close();
          final r = await pickFolder(c, exclude: store.descendants(d.id));
          if (r != null) await store.moveFolder(d, r.id);
        }),
        _Act(Icons.delete_outline_rounded, 'ট্র্যাশে পাঠান', () async {
          close();
          final ok = await confirmSheet(c,
              icon: Icons.delete_outline_rounded,
              title: 'ফোল্ডারটি মুছবেন?',
              body: 'ভেতরের সব ফাইল ট্র্যাশে যাবে, সেখান থেকে ফিরিয়ে আনা যাবে।',
              ok: 'ট্র্যাশে');
          if (ok) {
            await store.trashFolder(d);
            if (c.mounted) toast(c, 'ফোল্ডার মুছে ফেলা হয়েছে');
          }
        }, danger: true),
      ],
      head: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Row(children: [
          const Icon(Icons.folder_rounded, color: Color(0xFFF6B73C), size: 32),
          const SizedBox(width: 12),
          Expanded(child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: s.tx))),
        ]),
      ),
    );
  });
}

Future<void> showAddSheet(BuildContext c, {required VoidCallback onUpload}) {
  return _show<void>(c, (s) {
    return _sheet(s, [
      _Act(Icons.upload_file_rounded, 'ফাইল আপলোড', () {
        Navigator.pop(s);
        onUpload();
      }),
      _Act(Icons.create_new_folder_outlined, 'নতুন ফোল্ডার', () async {
        Navigator.pop(s);
        final n = await askText(c, 'নতুন ফোল্ডার', hint: 'ফোল্ডারের নাম');
        if (n != null) await store.createFolder(n, store.cwd);
      }),
    ]);
  });
}
