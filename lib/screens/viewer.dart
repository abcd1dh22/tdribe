import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';
import '../actions.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'preview.dart';

const _bg = Color(0xFF0B0C14);

class ViewerScreen extends StatefulWidget {
  final List<CloudFile> items;
  final int index;
  const ViewerScreen({super.key, required this.items, required this.index});
  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  late final PageController pc = PageController(initialPage: widget.index);
  late int cur = widget.index;
  bool bars = true, popped = false;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final f = widget.items[cur];
        if ((f.trashed || !store.files.contains(f)) && !popped) {
          popped = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
        }
        final top = MediaQuery.of(context).padding.top;
        final sub = widget.items.length > 1
            ? '${bn(cur + 1)}/${bn(widget.items.length)} · ${fmtSize(f.size)}'
            : '${kinds[f.kind]!.label} · ${fmtSize(f.size)}';
        return Scaffold(
          backgroundColor: _bg,
          body: Stack(children: [
            PageView.builder(
              controller: pc,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => cur = i),
              itemBuilder: (_, i) => FileView(
                key: ValueKey(widget.items[i].id),
                file: widget.items[i],
                onTap: () => setState(() => bars = !bars),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: bars ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !bars,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(6, top + 6, 6, 22),
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xCC000000), Color(0x00000000)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
                    child: Row(children: [
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                          Text(sub, style: const TextStyle(color: Color(0xB3FFFFFF), fontSize: 12.5)),
                        ]),
                      ),
                      IconButton(
                        onPressed: () => store.toggleStar([f]),
                        icon: Icon(f.starred ? Icons.star_rounded : Icons.star_border_rounded, color: f.starred ? const Color(0xFFFFC53D) : Colors.white),
                      ),
                      IconButton(
                        onPressed: () => Navigator.push(context, slideRoute(PreviewScreen(file: f))),
                        icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: () => showFileSheet(context, f, siblings: widget.items),
                        icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class FileView extends StatefulWidget {
  final CloudFile file;
  final VoidCallback onTap;
  const FileView({super.key, required this.file, required this.onTap});
  @override
  State<FileView> createState() => _FileViewState();
}

class _FileViewState extends State<FileView> {
  String? path;
  double prog = 0;
  Object? err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool retry = false}) async {
    if (retry) {
      setState(() {
        err = null;
        prog = 0;
      });
    }
    try {
      final p = await store.fetch(widget.file, (v) {
        if (mounted && (v - prog >= .01 || v >= 1)) setState(() => prog = v);
      });
      if (mounted) setState(() => path = p);
    } catch (e) {
      if (mounted) setState(() => err = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    if (path == null) {
      return Center(
        child: err != null
            ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_rounded, color: Color(0xB3FFFFFF), size: 48),
                  const SizedBox(height: 14),
                  Text('$err', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  GradButton(width: 160, height: 48, radius: 16, onTap: () => _load(retry: true), child: const Text('আবার চেষ্টা', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
                ]),
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox(
                        width: 72,
                        height: 72,
                        child: CircularProgressIndicator(value: prog > 0 ? prog : null, strokeWidth: 4, color: AppColors.p, backgroundColor: const Color(0x22FFFFFF))),
                    Text('${bn((prog * 100).round())}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 18),
                Text(f.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text('${fmtSize(f.size)} · চ্যানেল থেকে আনা হচ্ছে', style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 13)),
              ]),
      );
    }
    switch (f.viewer) {
      case 'img':
        return _ImgView(path: path!, onTap: widget.onTap);
      case 'vid':
        return _VideoView(path: path!, onTap: widget.onTap);
      case 'pdf':
        return _PdfView(path: path!);
      case 'txt':
        return _TxtView(path: path!);
      default:
        final k = kinds[f.kind]!;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(gradient: LinearGradient(colors: k.colors), borderRadius: BorderRadius.circular(30)),
                child: Icon(k.icon, color: Colors.white, size: 46),
              ),
              const SizedBox(height: 20),
              Text(f.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('এই ধরনের ফাইল এপের ভেতরে দেখা যায় না', textAlign: TextAlign.center, style: TextStyle(color: Color(0x99FFFFFF))),
              const SizedBox(height: 24),
              GradButton(
                width: 220,
                onTap: () => openExternal(context, f),
                child: const Text('অন্য অ্যাপে খুলুন', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        );
    }
  }
}

class _ImgView extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  const _ImgView({required this.path, required this.onTap});
  @override
  State<_ImgView> createState() => _ImgViewState();
}

class _ImgViewState extends State<_ImgView> {
  final tc = TransformationController();
  @override
  void dispose() {
    tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTap: () {
        final zoomed = tc.value.getMaxScaleOnAxis() > 1.05;
        tc.value = zoomed ? Matrix4.identity() : (Matrix4.identity()..scale(2.5, 2.5));
      },
      child: InteractiveViewer(
        transformationController: tc,
        minScale: 1,
        maxScale: 6,
        child: SizedBox.expand(
          child: Image.file(File(widget.path), fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 56))),
        ),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  final String path;
  final VoidCallback onTap;
  const _VideoView({required this.path, required this.onTap});
  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController c = VideoPlayerController.file(File(widget.path));
  bool ready = false, ctl = true, failed = false;

  @override
  void initState() {
    super.initState();
    c.addListener(() {
      if (mounted) setState(() {});
    });
    c.initialize().then((_) {
      if (mounted) {
        setState(() => ready = true);
        c.play();
      }
    }).catchError((Object _) {
      if (mounted) setState(() => failed = true);
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String t(Duration d) =>
      '${bn(d.inMinutes.toString().padLeft(2, '0'))}:${bn((d.inSeconds % 60).toString().padLeft(2, '0'))}';

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return const Center(child: Text('ভিডিও চালানো যায়নি', style: TextStyle(color: Colors.white)));
    }
    if (!ready) return const Center(child: CircularProgressIndicator(color: AppColors.p));
    final v = c.value;
    final total = v.duration.inMilliseconds.toDouble();
    final pos = math.min(v.position.inMilliseconds.toDouble(), total);
    final bottom = MediaQuery.of(context).padding.bottom;
    return GestureDetector(
      onTap: () {
        setState(() => ctl = !ctl);
        widget.onTap();
      },
      child: Stack(fit: StackFit.expand, children: [
        Center(child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c))),
        if (ctl) ...[
          Center(
            child: GestureDetector(
              onTap: () => v.isPlaying ? c.pause() : c.play(),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0x55000000), border: Border.all(color: const Color(0x55FFFFFF))),
                child: Icon(v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom + 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(color: const Color(0x66000000), borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                Text(t(v.position), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                Expanded(
                  child: Slider(
                    value: pos,
                    max: total <= 0 ? 1 : total,
                    onChanged: (x) => c.seekTo(Duration(milliseconds: x.round())),
                  ),
                ),
                Text(t(v.duration), style: const TextStyle(color: Colors.white, fontSize: 12.5)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

class _PdfView extends StatefulWidget {
  final String path;
  const _PdfView({required this.path});
  @override
  State<_PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<_PdfView> {
  late final PdfControllerPinch ctl = PdfControllerPinch(document: PdfDocument.openFile(widget.path));

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Stack(children: [
      Padding(
        padding: EdgeInsets.only(top: mq.padding.top + 56),
        child: PdfViewPinch(controller: ctl, backgroundDecoration: const BoxDecoration(color: _bg)),
      ),
      Positioned(
        bottom: mq.padding.bottom + 20,
        left: 0,
        right: 0,
        child: Center(
          child: PdfPageNumber(
            controller: ctl,
            builder: (_, state, page, count) => (count == null || count == 0)
                ? const SizedBox.shrink()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(20)),
                    child: Text('${bn(page)} / ${bn(count)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                  ),
          ),
        ),
      ),
    ]);
  }
}

class _TxtView extends StatelessWidget {
  final String path;
  const _TxtView({required this.path});

  Future<String> _read() async {
    const cap = 512 * 1024;
    final f = File(path);
    final len = await f.length();
    final raf = await f.open();
    final bytes = await raf.read(math.min(len, cap));
    await raf.close();
    var s = utf8.decode(bytes, allowMalformed: true);
    if (len > cap) s += '\n\n… বাকি অংশ দেখতে অন্য অ্যাপে খুলুন';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return FutureBuilder<String>(
      future: _read(),
      builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.p));
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, mq.padding.top + 64, 20, mq.padding.bottom + 32),
          child: SelectableText(s.data!, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13.5, height: 1.55, fontFamily: 'monospace')),
        );
      },
    );
  }
}
