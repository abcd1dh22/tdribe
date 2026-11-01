import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../store.dart';
import '../widgets.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String pin = '';
  bool bad = false;

  void tap(String d) {
    if (pin.length >= 4) return;
    setState(() {
      pin += d;
      bad = false;
    });
    if (pin.length == 4) {
      if (store.checkPin(pin)) {
        store.unlock();
      } else {
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              pin = '';
              bad = true;
            });
          }
        });
      }
    }
  }

  void back() {
    if (pin.isNotEmpty) setState(() => pin = pin.substring(0, pin.length - 1));
  }

  Widget key(BuildContext c, String label, {VoidCallback? onTap, IconData? icon}) {
    if (label.isEmpty && icon == null) return const SizedBox(width: 76, height: 76);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Material(
        color: c.sf,
        shape: const CircleBorder(),
        elevation: 0,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap ?? () => tap(label),
          child: SizedBox(
            width: 60,
            height: 60,
            child: Center(
              child: icon != null
                  ? Icon(icon, color: c.muted)
                  : Text(bn(label), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500, color: c.tx)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9']
    ];
    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 2),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: kBrand,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Color(0x666E50F0), blurRadius: 28, offset: Offset(0, 12))],
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 22),
          Text('পিন দিন', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: context.tx)),
          const SizedBox(height: 6),
          Text(bad ? 'ভুল পিন, আবার চেষ্টা করুন' : 'আপনার ফাইল সুরক্ষিত',
              style: TextStyle(color: bad ? const Color(0xFFE5484D) : context.muted)),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              4,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 9),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: i < pin.length ? kBrand : null,
                  color: i < pin.length ? null : context.sf2,
                ),
              ),
            ),
          ),
          const Spacer(),
          for (final r in rows) Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final k in r) key(context, k)]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            key(context, ''),
            key(context, '0'),
            key(context, '', icon: Icons.backspace_outlined, onTap: back),
          ]),
          const SizedBox(height: 28),
        ]),
      ),
    );
  }
}
