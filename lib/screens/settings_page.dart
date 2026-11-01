import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? busy;

  String mask(String s) => s.isEmpty ? 'সেট করা হয়নি' : (s.length <= 8 ? '••••' : '${s.substring(0, 4)}••••••${s.substring(s.length - 3)}');

  InputDecoration deco(BuildContext c, String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: c.sf2,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  Future<void> edit(String title, String hint, String cur, Future<void> Function(String) save) async {
    final ctl = TextEditingController(text: cur);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(title),
        content: TextField(controller: ctl, autofocus: true, decoration: deco(c, hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('সংরক্ষণ')),
        ],
      ),
    );
    if (v == null) return;
    await save(v);
    if (store.configured) {
      try {
        final n = await store.tg.verify();
        if (mounted) toast(context, 'সংযুক্ত হয়েছে: $n');
      } catch (e) {
        if (mounted) toast(context, '$e', error: true);
      }
    }
  }

  Future<String?> askPin() {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('৪ সংখ্যার পিন দিন'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: deco(c, '••••'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('বাতিল')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctl.text.length == 4 ? ctl.text : null), child: const Text('চালু করুন')),
        ],
      ),
    );
  }

  Future<void> run(String key, Future<String> Function() job) async {
    if (!store.configured) {
      toast(context, 'আগে বট টোকেন ও চ্যানেল আইডি দিন', error: true);
      return;
    }
    setState(() => busy = key);
    try {
      final msg = await job();
      if (mounted) toast(context, msg);
    } catch (e) {
      if (mounted) toast(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => busy = null);
    }
  }

  Future<void> restore() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('রিস্টোর করবেন?'),
        content: const Text('চ্যানেলের পিন করা ব্যাকআপ দিয়ে বর্তমান তালিকা বদলে যাবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('বাতিল')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('রিস্টোর')),
        ],
      ),
    );
    if (ok != true) return;
    await run('restore', () async => '${bn(await store.restore())}টি ফাইল ফিরে এসেছে');
  }

  Widget group(BuildContext c, String title, List<Widget> rows) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 22, 6, 10),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.muted, letterSpacing: .3)),
        ),
        Container(
          decoration: BoxDecoration(color: c.sf, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.line), boxShadow: c.shadow),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(children: [
              for (var i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1) Divider(height: 1, thickness: 1, color: c.line),
              ],
            ]),
          ),
        ),
      ]);

  Widget row(BuildContext c, IconData icon, String title, String sub, {Widget? trailing, VoidCallback? onTap}) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.sf2, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: AppColors.p, size: 21),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w500, color: c.tx)),
                const SizedBox(height: 1),
                Text(sub, style: TextStyle(fontSize: 12.5, color: c.muted)),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      );

  Widget spin() => const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5));

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (c, _) {
        final pad = MediaQuery.of(c).padding;
        return ListView(
          padding: EdgeInsets.fromLTRB(20, pad.top + 18, 20, pad.bottom + 120),
          children: [
            Text('সেটিংস', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -.3, color: c.tx)),
            Text('সংযোগ, ব্যাকআপ ও নিরাপত্তা', style: TextStyle(fontSize: 14, color: c.muted)),
            group(c, 'সংযোগ', [
              row(c, Icons.vpn_key_outlined, 'বট টোকেন', mask(store.token),
                  onTap: () => edit('বট টোকেন', '@BotFather থেকে পাওয়া টোকেন', store.token, (v) => store.setConn(t: v))),
              row(c, Icons.folder_outlined, 'চ্যানেল আইডি', store.channel.isEmpty ? 'সেট করা হয়নি' : store.channel,
                  onTap: () => edit('চ্যানেল আইডি', '-100xxxxxxxxxx', store.channel, (v) => store.setConn(c: v))),
            ]),
            group(c, 'ব্যাকআপ', [
              row(c, Icons.cloud_upload_outlined, 'এখনই ব্যাকআপ',
                  store.lastBackup == null ? 'চ্যানেলে আপলোড ও পিন' : 'শেষ: ${fmtDate(store.lastBackup!)}',
                  trailing: busy == 'backup' ? spin() : null,
                  onTap: busy != null ? null : () => run('backup', () async {
                        await store.backupNow();
                        return 'ব্যাকআপ চ্যানেলে পিন হয়েছে';
                      })),
              row(c, Icons.restore_rounded, 'রিস্টোর', 'পিন করা ব্যাকআপ থেকে',
                  trailing: busy == 'restore' ? spin() : null, onTap: busy != null ? null : restore),
              row(c, Icons.schedule_rounded, 'অটো ব্যাকআপ', 'প্রতিবার আপলোড বা ডিলিটের পর',
                  trailing: Switch(value: store.autoBackup, onChanged: store.setAuto)),
            ]),
            group(c, 'নিরাপত্তা ও চেহারা', [
              row(c, Icons.lock_outline_rounded, 'এপ লক', 'পিন দিয়ে সুরক্ষা',
                  trailing: Switch(
                      value: store.lockOn,
                      onChanged: (v) async {
                        if (v) {
                          final pin = await askPin();
                          if (pin != null) await store.enableLock(pin);
                        } else {
                          await store.disableLock();
                        }
                      })),
              row(c, Icons.dark_mode_outlined, 'ডার্ক থিম', 'চোখের আরামের জন্য',
                  trailing: Switch(value: c.dark, onChanged: (v) => store.setTheme(v ? 'dark' : 'light'))),
            ]),
          ],
        );
      },
    );
  }
}
