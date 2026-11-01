import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../widgets.dart';
import 'preview.dart';

class FilesPage extends StatefulWidget {
  const FilesPage({super.key});
  @override
  State<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends State<FilesPage> {
  String filter = 'all';

  Widget hero(BuildContext c) {
    final total = store.files.fold<int>(0, (a, f) => a + f.size);
    final by = <String, int>{};
    for (final f in store.files) {
      by[f.kind] = (by[f.kind] ?? 0) + f.size;
    }
    final backup = store.lastBackup == null ? 'ব্যাকআপ নেই' : 'শেষ ব্যাকআপ: ${fmtDate(store.lastBackup!)}';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
            colors: [Color(0xFF5B5BF0), Color(0xFF8B5CF6), Color(0xFFC06CF0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: const [BoxShadow(color: Color(0x596E50F0), blurRadius: 34, offset: Offset(0, 14))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(children: [
          Positioned(
              right: -50,
              top: -60,
              child: Container(
                  width: 200, height: 200, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x24FFFFFF)))),
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
                          for (final e in by.entries)
                            Expanded(flex: (e.value * 1000 ~/ total).clamp(1, 1000), child: Container(color: kinds[e.key]!.colors[0])),
                        ]),
                ),
              ),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${bn(store.files.length)}টি ফাইল', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
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
              decoration: BoxDecoration(
                color: on ? c.tx : c.sf,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? Colors.transparent : c.line),
              ),
              child: Text(items[i][1],
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? c.bg : c.muted)),
            ),
          );
        },
      ),
    );
  }

  Widget uploadCard(BuildContext c) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: c.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.line), boxShadow: c.shadow),
        child: Column(children: [
          Row(children: [
            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF5B5BF0)),
            const SizedBox(width: 12),
            Expanded(child: Text(store.upName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
            ValueListenableBuilder<double>(
              valueListenable: store.upProgress,
              builder: (_, v, __) => Text('${bn((v * 100).round())}%', style: TextStyle(color: c.muted)),
            ),
          ]),
          const SizedBox(height: 12),
          ValueListenableBuilder<double>(
            valueListenable: store.upProgress,
            builder: (_, v, __) =>
                LinearProgressIndicator(value: v, minHeight: 6, borderRadius: BorderRadius.circular(6), backgroundColor: c.sf2),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final list = filter == 'all' ? store.files : store.files.where((f) => f.kind == filter).toList();
        final pad = MediaQuery.of(c).padding;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, pad.top + 18, 20, pad.bottom + 120),
          children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('আমার ক্লাউড', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.3, color: c.tx)),
                  Text('টেলিগ্রাম চ্যানেলে সুরক্ষিত', style: TextStyle(fontSize: 14, color: c.muted)),
                ]),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: kBrand,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [BoxShadow(color: Color(0x595B5BF0), blurRadius: 16, offset: Offset(0, 6))],
                ),
                child: const Icon(Icons.cloud_outlined, color: Colors.white),
              ),
            ]),
            const SizedBox(height: 18),
            hero(c),
            const SizedBox(height: 22),
            chips(c),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 20, 2, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('সাম্প্রতিক ফাইল', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: c.tx)),
                Text('${bn(list.length)}টি', style: TextStyle(fontSize: 13, color: c.muted)),
              ]),
            ),
            if (store.uploading) uploadCard(c),
            if (list.isEmpty && !store.uploading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Column(children: [
                  Icon(Icons.cloud_upload_outlined, size: 56, color: c.muted),
                  const SizedBox(height: 12),
                  Text('এখনো কোনো ফাইল নেই', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: c.tx)),
                  const SizedBox(height: 4),
                  Text('নিচের + বোতাম চেপে আপলোড করুন', style: TextStyle(color: c.muted)),
                ]),
              ),
            for (final f in list) FileTile(f: f),
          ],
        );
      },
    );
  }
}

class FileTile extends StatelessWidget {
  final CloudFile f;
  const FileTile({super.key, required this.f});

  @override
  Widget build(BuildContext context) {
    final k = kinds[f.kind]!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: context.sf, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.line), boxShadow: context.shadow),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, slideRoute(PreviewScreen(file: f))),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: k.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(k.icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5, color: context.tx)),
                  const SizedBox(height: 2),
                  Text('${fmtSize(f.size)} · ${fmtDate(f.date)}', style: TextStyle(fontSize: 13, color: context.muted)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: context.muted),
            ]),
          ),
        ),
      ),
    );
  }
}
