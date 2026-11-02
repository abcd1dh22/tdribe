import 'dart:io';
import 'package:flutter/material.dart';
import '../actions.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class FilesPage extends StatefulWidget {
  final String mode; // files | starred | trash
  const FilesPage({super.key, required this.mode});
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String filter = 'all', q = '';
  final sel = <String>{};
  final ctl = TextEditingController();

  String get mode => widget.mode;
  bool get selecting => sel.isNotEmpty;
  List<CloudFile> get selFiles => store.files.where((f) => sel.contains(f.id)).toList();

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void toggleSel(CloudFile f) => setState(() {
        if (!sel.add(f.id)) sel.remove(f.id);
      });

  void tapFile(BuildContext c, CloudFile f, List<CloudFile> sib) {
    if (selecting) {
      toggleSel(f);
    } else if (f.trashed) {
      showFileSheet(c, f);
    } else {
      openFile(c, f, sib);
    }
  }

  List<CloudFile> sorted(List<CloudFile> l) {
    int cmp(CloudFile a, CloudFile b) {
      switch (store.sort) {
        case 'name':
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case 'size':
          return a.size.compareTo(b.size);
        default:
          return a.date.compareTo(b.date);
      }
    }

    l.sort((a, b) => store.asc ? cmp(a, b) : cmp(b, a));
    return l;
  }

  // ---------- header pieces ----------
  Widget avatar() => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: kBrand,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x595B5BF0), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: const Icon(Icons.cloud_outlined, color: Colors.white),
      );

  Widget titleBlock(BuildContext c, String t, String s) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.3, color: c.tx)),
        Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: c.muted)),
      ]);

  Widget header(BuildContext c) {
    if (mode == 'starred') return Row(children: [Expanded(child: titleBlock(c, 'তারকাচিহ্নিত', 'আপনার প্রিয় ফাইল')), avatar()]);
    if (mode == 'trash') {
      return Row(children: [
        Expanded(child: titleBlock(c, 'ট্র্যাশ', 'স্থায়ীভাবে না মুছলে ফিরিয়ে আনা যায়')),
        if (store.trash.isNotEmpty)
          TextButton(
            onPressed: () => deleteForeverFlow(c, store.trash),
            child: const Text('খালি করুন', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
      ]);
    }
    if (store.cwd == null) return Row(children: [Expanded(child: titleBlock(c, 'আমার ক্লাউড', 'টেলিগ্রাম চ্যানেলে সুরক্ষিত')), avatar()]);
    final path = store.pathTo(store.cwd);
    return Row(children: [
      IconButton(onPressed: store.up, icon: Icon(Icons.arrow_back_ios_new_rounded, color: c.tx, size: 20)),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(path.last.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: c.tx)),
          Text(['আমার ক্লাউড', ...path.map((e) => e.name)].join(' › '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c.muted)),
        ]),
      ),
    ]);
  }

  Widget selBar(BuildContext c, List<CloudFile> all) {
    Widget ib(IconData i, VoidCallback f, {Color? col}) => IconButton(onPressed: f, icon: Icon(i, color: col ?? c.tx));
    final trash = mode == 'trash';
    return Row(children: [
      ib(Icons.close_rounded, () => setState(sel.clear)),
      Expanded(child: Text('${bn(sel.length)}টি নির্বাচিত', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: c.tx))),
      ib(Icons.select_all_rounded, () => setState(() => sel.addAll(all.map((e) => e.id)))),
      if (!trash) ...[
        ib(Icons.star_border_rounded, () async {
          await store.toggleStar(selFiles);
          setState(sel.clear);
        }),
        ib(Icons.drive_file_move_outlined, () async {
          final r = await pickFolder(c);
          if (r != null) {
            await store.moveFiles(selFiles, r.id);
            setState(sel.clear);
            if (c.mounted) toast(c, 'ফাইল সরানো হয়েছে');
          }
        }),
        ib(Icons.delete_outline_rounded, () async {
          await store.trashFiles(selFiles);
          setState(sel.clear);
          if (c.mounted) toast(c, 'ট্র্যাশে পাঠানো হয়েছে');
        }, col: AppColors.danger),
      ] else ...[
        ib(Icons.restore_from_trash_rounded, () async {
          await store.restoreFiles(selFiles);
          setState(sel.clear);
        }),
        ib(Icons.delete_forever_outlined, () async {
          final l = selFiles;
          await deleteForeverFlow(c, l);
          setState(sel.clear);
        }, col: AppColors.danger),
      ],
    ]);
  }

  Widget searchBar(BuildContext c) => Container(
        decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.line), boxShadow: c.shadow),
        child: TextField(
          controller: ctl,
          onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'ড্রাইভে খুঁজুন',
            hintStyle: TextStyle(color: c.muted),
            prefixIcon: Icon(Icons.search_rounded, color: c.muted),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded, color: c.muted),
                    onPressed: () {
                      ctl.clear();
                      setState(() => q = '');
                    }),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      );

  Widget hero(BuildContext c) {
    final live = store.live;
    final total = live.fold<int>(0, (a, f) => a + f.size);
    final by = <String, int>{};
    for (final f in live) {
      by[f.kind] = (by[f.kind] ?? 0) + f.size;
    }
    final backup = store.lastBackup == null ? 'ব্যাকআপ নেই' : 'শেষ ব্যাকআপ: ${fmtDate(store.lastBackup!)}';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(colors: [Color(0xFF5B5BF0), Color(0xFF8B5CF6), Color(0xFFC06CF0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x596E50F0), blurRadius: 34, offset: Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned(right: -50, top: -60, child: Container(width: 200, height: 200, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x24FFFFFF)))),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('মোট ব্যবহৃত', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
              const SizedBox(height: 2),
              Text(fmtSize(total), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 8,
                  child: total == 0
                      ? Container(color: const Color(0x40FFFFFF))
                      : Row(children: [
                          for (final e in by.entries) Expanded(flex: (e.value * 1000 ~/ total).clamp(1, 1000), child: Container(color: kinds[e.key]!.colors[0])),
                        ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${bn(live.length)}টি ফাইল', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
                Text(backup, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget chips(BuildContext c) {
    final items = <List<String>>[
      ['all', 'সব'],
      for (final e in kinds.entries) [e.key, e.value.label],
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final on = filter == items[i][0];
          return GestureDetector(
            onTap: () => setState(() => filter = items[i][0]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: on ? c.tx : c.sf, borderRadius: BorderRadius.circular(14), border: Border.all(color: on ? Colors.transparent : c.line)),
              child: Text(items[i][1], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? c.bg : c.muted)),
            ),
          );
        },
      ),
    );
  }

  Widget toolbar(BuildContext c, String title) {
    const names = {'name': 'নাম', 'date': 'তারিখ', 'size': 'আকার'};
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 0, 6),
      child: Row(children: [
        Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.tx))),
        PopupMenuButton<String>(
          onSelected: (v) => v == 'asc' ? store.setView(a: !store.asc) : store.setView(s: v),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'name', child: Text('নাম')),
            const PopupMenuItem(value: 'date', child: Text('তারিখ')),
            const PopupMenuItem(value: 'size', child: Text('আকার')),
            const PopupMenuDivider(),
            PopupMenuItem(value: 'asc', child: Text(store.asc ? 'ক্রম: ছোট থেকে বড়' : 'ক্রম: বড় থেকে ছোট')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              Icon(Icons.swap_vert_rounded, size: 20, color: c.muted),
              const SizedBox(width: 4),
              Text('${names[store.sort]} ${store.asc ? '↑' : '↓'}', style: TextStyle(color: c.muted, fontSize: 13.5)),
            ]),
          ),
        ),
        IconButton(
          onPressed: () => store.setView(g: !store.grid),
          icon: Icon(store.grid ? Icons.view_list_rounded : Icons.grid_view_rounded, color: c.muted),
        ),
      ]),
    );
  }

  Widget uploadCard(BuildContext c) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line), boxShadow: c.shadow),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.cloud_upload_outlined, color: AppColors.p),
            const SizedBox(width: 12),
            Expanded(child: Text(store.upName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, color: c.tx))),
            ValueListenableBuilder<double>(valueListenable: store.upProgress, builder: (_, v, __) => Text('${bn((v * 100).round())}%', style: TextStyle(color: c.muted))),
          ]),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: store.upProgress,
            builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 6, borderRadius: BorderRadius.circular(6), backgroundColor: c.sf2),
          ),
        ]),
      );

  // ---------- tiles ----------
  BoxDecoration cardDeco(BuildContext c, {bool on = false}) => BoxDecoration(
        color: on ? const Color(0x1F5B5BF0) : c.sf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: on ? AppColors.p : c.line, width: on ? 1.5 : 1),
        boxShadow: c.shadow,
      );

  Widget folderTile(BuildContext c, Folder d) {
    final n = store.countIn(d.id);
    final icon = Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFF6B73C), Color(0xFFF28C2D)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.folder_rounded, color: Colors.white),
    );
    return Container(
      margin: store.grid ? null : const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(c),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (selecting) return;
            ctl.clear();
            q = '';
            store.openFolder(d.id);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(children: [
              icon,
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: c.tx)),
                  Text('${bn(n)}টি আইটেম', style: TextStyle(fontSize: 12.5, color: c.muted)),
                ]),
              ),
              IconButton(onPressed: () => showFolderSheet(c, d), icon: Icon(Icons.more_vert_rounded, color: c.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget fileRow(BuildContext c, CloudFile f, List<CloudFile> sib) {
    final k = kinds[f.kind]!;
    final on = sel.contains(f.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: cardDeco(c, on: on),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => tapFile(c, f, sib),
          onLongPress: () => toggleSel(f),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: on ? kBrand : LinearGradient(colors: k.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(on ? Icons.check_rounded : k.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: c.tx)),
                  const SizedBox(height: 2),
                  Text('${fmtSize(f.size)} · ${fmtDate(f.trashed ? f.trashedAt : f.date)}', style: TextStyle(fontSize: 13, color: c.muted)),
                ]),
              ),
              if (f.starred) const Icon(Icons.star_rounded, color: Color(0xFFFFC53D), size: 20),
              IconButton(onPressed: () => showFileSheet(c, f, siblings: sib), icon: Icon(Icons.more_vert_rounded, color: c.muted)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget fileCard(BuildContext c, CloudFile f, List<CloudFile> sib) {
    final k = kinds[f.kind]!;
    final on = sel.contains(f.id);
    return Container(
      decoration: cardDeco(c, on: on),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => tapFile(c, f, sib),
          onLongPress: () => toggleSel(f),
          child: Column(children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(fit: StackFit.expand, children: [
                    _Thumb(f: f),
                    if (on) Container(color: const Color(0x995B5BF0), child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 40)),
                    if (f.starred) const Positioned(top: 8, right: 8, child: Icon(Icons.star_rounded, color: Color(0xFFFFC53D), size: 22)),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 0, 4),
              child: Row(children: [
                Icon(k.icon, size: 18, color: k.colors[0]),
                const SizedBox(width: 8),
                Expanded(child: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: c.tx))),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showFileSheet(c, f, siblings: sib),
                  icon: Icon(Icons.more_vert_rounded, color: c.muted, size: 20),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget block(List<Widget> tiles, {required double ratio}) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: store.grid
            ? SliverGrid(
                delegate: SliverChildListDelegate(tiles),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: ratio),
              )
            : SliverList(delegate: SliverChildListDelegate(tiles)),
      );

  Widget label(BuildContext c, String t) => SliverToBoxAdapter(
        child: Padding(padding: const EdgeInsets.fromLTRB(22, 8, 20, 10), child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted))),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        sel.removeWhere((id) => !store.files.any((f) => f.id == id));
        final searching = mode == 'files' && q.isNotEmpty;
        var folders = <Folder>[];
        List<CloudFile> items;
        if (mode == 'trash') {
          items = store.trash;
        } else if (mode == 'starred') {
          items = store.live.where((f) => f.starred).toList();
        } else if (searching) {
          items = store.live.where((f) => f.name.toLowerCase().contains(q)).toList();
          folders = store.folders.where((f) => f.name.toLowerCase().contains(q)).toList();
        } else {
          folders = store.childFolders(store.cwd);
          items = store.filesIn(store.cwd);
        }
        if (filter != 'all') {
          items = items.where((f) => f.kind == filter).toList();
          folders = [];
        }
        items = sorted(items);
        final pad = MediaQuery.of(c).padding;
        final atRoot = mode == 'files' && store.cwd == null && !searching && !selecting;
        final title = mode == 'trash' ? 'মুছে ফেলা ফাইল' : (mode == 'starred' ? 'সব তারকাচিহ্নিত' : (searching ? 'অনুসন্ধানের ফলাফল' : 'ফাইল ও ফোল্ডার'));
        final empty = items.isEmpty && folders.isEmpty && !(store.uploading && mode == 'files');
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, pad.top + 18, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                selecting ? selBar(c, items) : header(c),
                if (mode == 'files' && !selecting) ...[const SizedBox(height: 16), searchBar(c)],
                if (atRoot) ...[const SizedBox(height: 18), hero(c)],
                if (mode == 'trash')
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(16)),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: c.muted),
                      const SizedBox(width: 10),
                      Expanded(child: Text('স্থায়ীভাবে মুছলে টেলিগ্রাম চ্যানেল থেকেও ফাইল মুছে যায়।', style: TextStyle(fontSize: 13, color: c.muted))),
                    ]),
                  ),
                const SizedBox(height: 16),
                chips(c),
                toolbar(c, title),
                if (store.uploading && mode == 'files') uploadCard(c),
              ]),
            ),
          ),
          if (folders.isNotEmpty) ...[
            if (items.isNotEmpty) label(c, 'ফোল্ডার'),
            block([for (final d in folders) folderTile(c, d)], ratio: 2.7),
          ],
          if (items.isNotEmpty) ...[
            if (folders.isNotEmpty) label(c, 'ফাইল'),
            block([for (final f in items) store.grid ? fileCard(c, f, items) : fileRow(c, f, items)], ratio: .92),
          ],
          if (empty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  Icon(mode == 'trash' ? Icons.delete_outline_rounded : (mode == 'starred' ? Icons.star_border_rounded : (searching ? Icons.search_off_rounded : Icons.cloud_upload_outlined)), size: 56, color: c.muted),
                  const SizedBox(height: 12),
                  Text(mode == 'trash' ? 'ট্র্যাশ খালি' : (mode == 'starred' ? 'কোনো তারকাচিহ্নিত ফাইল নেই' : (searching ? 'কিছু পাওয়া যায়নি' : 'এখানে কিছু নেই')), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: c.tx)),
                  if (mode == 'files' && !searching) ...[const SizedBox(height: 4), Text('নিচের + বোতাম চেপে আপলোড করুন', style: TextStyle(color: c.muted))],
                ]),
              ),
            ),
          SliverToBoxAdapter(child: SizedBox(height: pad.bottom + 120)),
        ]);
      },
    );
  }
}

class _Thumb extends StatefulWidget {
  final CloudFile f;
  const _Thumb({required this.f});
  @override
  State<_Thumb> createState() => _ThumbState();
}

class _ThumbState extends State<_Thumb> {
  late final Future<String?> fut = widget.f.kind == 'img' ? store.cachedPath(widget.f) : Future.value(null);

  @override
  Widget build(BuildContext context) {
    final k = kinds[widget.f.kind]!;
    final fallback = Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: [k.colors[0].withAlpha(235), k.colors[1].withAlpha(235)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Center(child: Icon(k.icon, color: Colors.white, size: 42)),
    );
    if (widget.f.kind != 'img') return fallback;
    return FutureBuilder<String?>(
      future: fut,
      builder: (_, s) => s.data == null ? fallback : Image.file(File(s.data!), fit: BoxFit.cover, cacheWidth: 400, errorBuilder: (_, __, ___) => fallback),
    );
  }
}
