import 'package:flutter/material.dart';
import 'theme.dart';

const kBrand = LinearGradient(colors: [AppColors.p, AppColors.p2], begin: Alignment.topLeft, end: Alignment.bottomRight);

extension Ctx on BuildContext {
  bool get dark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => dark ? const Color(0xFF8C90AD) : const Color(0xFF6C7090);
  Color get sf => dark ? const Color(0xFF161827) : Colors.white;
  Color get sf2 => dark ? const Color(0xFF1F2133) : const Color(0xFFECEEF8);
  Color get line => dark ? const Color(0x14FFFFFF) : const Color(0x14141530);
  Color get tx => dark ? const Color(0xFFF1F2FB) : const Color(0xFF14152A);
  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  List<BoxShadow> get shadow => [
        BoxShadow(
            color: dark ? const Color(0x73000000) : const Color(0x1A3C3C8C), blurRadius: 30, offset: const Offset(0, 8))
      ];
}

String bn(Object v) => v.toString().replaceAllMapped(RegExp(r'\d'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)]);

String fmtSize(int b) {
  if (b < 1024) return '${bn(b)} B';
  const u = ['KB', 'MB', 'GB', 'TB'];
  double v = b / 1024;
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${bn(v.toStringAsFixed(v >= 100 ? 0 : 1))} ${u[i]}';
}

String fmtDate(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final n = DateTime.now();
  final diff = DateTime(n.year, n.month, n.day).difference(DateTime(d.year, d.month, d.day)).inDays;
  final hm = '${bn(d.hour.toString().padLeft(2, '0'))}:${bn(d.minute.toString().padLeft(2, '0'))}';
  if (diff == 0) return 'আজ, $hm';
  if (diff == 1) return 'গতকাল';
  const m = ['জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর'];
  return '${bn(d.day)} ${m[d.month - 1]}${d.year != n.year ? ' ${bn(d.year)}' : ''}';
}

void toastM(ScaffoldMessengerState m, String msg, {bool error = false}) {
  m
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 104),
      backgroundColor: error ? AppColors.danger : const Color(0xFF1C1E2E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      duration: const Duration(seconds: 3),
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
      ]),
    ));
}

void toast(BuildContext c, String msg, {bool error = false}) => toastM(ScaffoldMessenger.of(c), msg, error: error);

Route<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => page,
      transitionDuration: const Duration(milliseconds: 450),
      reverseTransitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, a, __, child) {
        final c = CurvedAnimation(parent: a, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
        return SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(c), child: child);
      },
    );

class GradButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double? width;
  final double height, radius;
  const GradButton({super.key, required this.child, required this.onTap, this.width, this.height = 56, this.radius = 19});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? .6 : 1,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: kBrand,
            borderRadius: BorderRadius.circular(radius),
            boxShadow: const [BoxShadow(color: Color(0x666E50F0), blurRadius: 24, offset: Offset(0, 10))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(radius), onTap: onTap, child: Center(child: child)),
          ),
        ),
      );
}

class FlatBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final VoidCallback onTap;
  const FlatBtn({super.key, required this.label, required this.bg, required this.fg, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: SizedBox(
              height: 52,
              child: Center(child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16)))),
        ),
      );
}
