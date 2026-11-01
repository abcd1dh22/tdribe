import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class PreviewScreen extends StatefulWidget {
  final CloudFile file;
  const PreviewScreen({super.key, required this.file});
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  String? local;
  double? prog;
  bool deleting = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final p = await store.localPath(widget.file);
    final f = File(p);
    if (await f.exists() && await f.length() == widget.file.size && mounted) setState(() => local = p);
  }

  Future<void> _download() async {
    if (prog != null) return;
    if (local == null && !store.configured) {
      toast(context, 'আগে সেটিংসে বট টোকেন ও চ্যানেল আইডি দিন', error: true);
      return;
    }
    setState(() => prog = 0);
    try {
      final p = await store.fetch(widget.file, (v) {
        if (mounted && (prog == null || v - prog! >= .01 || v >= 1)) setState(() => prog = v);
      });
      if (!mounted) return;
      setState(() => local = p);
      store.allowLeave();
      final r = await OpenFilex.open(p);
      if (r.type != ResultType.done && mounted) toast(context, 'ফাইল সংরক্ষিত হয়েছে: $p');
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => prog = null);
    }
  }

  Future<void> _delete() async {
    final f = widget.file;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(c).padding.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
          decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(30)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: const Color(0x1FE5484D), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 28),
            ),
            const SizedBox(height: 14),
            Text('ফাইলটি মুছবেন?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: c.tx)),
            const SizedBox(height: 6),
            Text('${f.name} চ্যানেল ও তালিকা থেকে মুছে যাবে।',
                textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 14.5)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: FlatBtn(label: 'বাতিল', bg: c.sf2, fg: c.tx, onTap: () => Navigator.pop(c, false))),
              const SizedBox(width: 12),
              Expanded(child: FlatBtn(label: 'মুছুন', bg: AppColors.danger, fg: Colors.white, onTap: () => Navigator.pop(c, true))),
            ]),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final m = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => deleting = true);
    final clean = await store.removeFile(f);
    nav.pop();
    toastM(m, clean ? 'ফাইল মুছে ফেলা হয়েছে' : 'তালিকা থেকে মুছেছে; চ্যানেলের মেসেজ মোছা যায়নি', error: !clean);
  }

  Widget _art(BuildContext c) {
    final f = widget.file;
    Widget inner;
    switch (f.kind) {
      case 'img':
        inner = local != null
            ? Image.file(File(local!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const _Sunset())
            : const _Sunset();
        break;
      case 'doc':
        inner = Container(
          color: Colors.white,
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final w in [.6, 1.0, .75, 1.0, 1.0, .75, 1.0])
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FractionallySizedBox(
                    widthFactor: w,
                    child: Container(
                        height: w == .6 ? 14 : 8,
                        decoration: BoxDecoration(
                            color: w == .6 ? const Color(0xFFCFD3EA) : const Color(0xFFE6E8F2), borderRadius: BorderRadius.circular(6)))),
              ),
          ]),
        );
        break;
      case 'vid':
        inner = Container(
          decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF2B3A8F), Color(0xFF6A3FC4)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: const Color(0x38FFFFFF), border: Border.all(color: const Color(0x66FFFFFF))),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
            ),
          ),
        );
        break;
      default:
        final k = kinds[f.kind]!;
        inner = Container(
          color: c.sf,
          child: Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(gradient: LinearGradient(colors: k.colors), borderRadius: BorderRadius.circular(28)),
              child: Icon(k.icon, color: Colors.white, size: 44),
            ),
          ),
        );
    }
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [BoxShadow(color: Color(0x59000000), blurRadius: 60, offset: Offset(0, 30))]),
      child: ClipRRect(borderRadius: BorderRadius.circular(26), child: inner),
    );
  }

  Widget _tag(BuildContext c, String t, {bool primary = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: primary ? const Color(0x245B5BF0) : c.sf2, borderRadius: BorderRadius.circular(10)),
        child: Text(t,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: primary ? AppColors.p : c.muted)),
      );

  Widget _info(BuildContext c) {
    final f = widget.file;
    final rows = [
      ['আকার', fmtSize(f.size)],
      ['আপলোড', fmtDate(f.date)],
      ['অংশ', '${bn(f.parts.length)}টি'],
      ['মেসেজ আইডি', '#${bn(f.parts.first.messageId)}'],
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
          color: c.sf, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.line), boxShadow: c.shadow),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(border: i == rows.length - 1 ? null : Border(bottom: BorderSide(color: c.line))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(rows[i][0], style: TextStyle(color: c.muted, fontSize: 14.5)),
              Text(rows[i][1], style: TextStyle(color: c.tx, fontSize: 14.5, fontWeight: FontWeight.w500)),
            ]),
          ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.file;
    final k = kinds[f.kind]!;
    final mq = MediaQuery.of(context);
    final stageH = mq.size.height * .54;
    return Scaffold(
      body: Stack(children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: stageH,
          child: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [k.colors[0], Color.lerp(k.colors[1], AppColors.p, .55)!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            padding: EdgeInsets.only(top: mq.padding.top + 56, bottom: 44),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mq.size.width * .62),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: Transform.scale(scale: .94 + .06 * v, child: child))),
                  child: AspectRatio(aspectRatio: 4 / 5, child: _art(context)),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: mq.padding.top + 14,
          left: 16,
          child: Material(
            color: const Color(0x38FFFFFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Color(0x40FFFFFF))),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => Navigator.pop(context),
              child: const SizedBox(width: 44, height: 44, child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18)),
            ),
          ),
        ),
        Positioned(
          top: stageH - 30,
          left: 0,
          right: 0,
          bottom: 0,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child)),
            child: Container(
              decoration: BoxDecoration(
                color: context.bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: const [BoxShadow(color: Color(0x2E000000), blurRadius: 40, offset: Offset(0, -18))],
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(22, 12, 22, mq.padding.bottom + 20),
                children: [
                  Center(
                      child: Container(
                          width: 40, height: 5, margin: const EdgeInsets.only(bottom: 16), decoration: BoxDecoration(color: context.sf2, borderRadius: BorderRadius.circular(5)))),
                  Text(f.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.2, color: context.tx)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _tag(context, k.label, primary: true),
                    _tag(context, fmtSize(f.size)),
                    _tag(context, 'টেলিগ্রামে সুরক্ষিত'),
                  ]),
                  const SizedBox(height: 18),
                  _info(context),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(
                      child: GradButton(
                        onTap: _download,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          if (prog != null)
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(value: prog, strokeWidth: 2.5, color: Colors.white))
                          else
                            Icon(local != null ? Icons.open_in_new_rounded : Icons.download_rounded, color: Colors.white),
                          const SizedBox(width: 9),
                          Text(prog != null ? '${bn((prog! * 100).round())}%' : (local != null ? 'খুলুন' : 'ডাউনলোড'),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: const Color(0x1FE5484D),
                      borderRadius: BorderRadius.circular(19),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(19),
                        onTap: deleting ? null : _delete,
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: deleting
                              ? const Padding(padding: EdgeInsets.all(17), child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.danger))
                              : const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Sunset extends StatelessWidget {
  const _Sunset();
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFFFFD29A), Color(0xFFFF8E72), Color(0xFF7A4FA0)],
                    stops: [0, .45, 1],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter))),
        Align(
          alignment: const Alignment(.5, -.55),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFFF6DD),
                boxShadow: [BoxShadow(color: Color(0xB3FFEBBE), blurRadius: 50, spreadRadius: 14)]),
          ),
        ),
        CustomPaint(painter: _Mtn()),
      ]);
}

class _Mtn extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final top = s.height * .54, h = s.height * .46;
    final p = Path()
      ..moveTo(0, top + h * .6)
      ..lineTo(s.width * .22, top + h * .2)
      ..lineTo(s.width * .4, top + h * .55)
      ..lineTo(s.width * .62, top + h * .1)
      ..lineTo(s.width, top + h * .62)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0xFF2B2250));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
