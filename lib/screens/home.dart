import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../store.dart';
import '../widgets.dart';
import 'files_page.dart';
import 'settings_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  Future<void> upload() async {
    if (!store.configured) {
      toast(context, 'আগে সেটিংসে বট টোকেন ও চ্যানেল আইডি দিন', error: true);
      setState(() => tab = 1);
      return;
    }
    if (store.uploading) return;
    store.allowLeave();
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r == null) return;
    setState(() => tab = 0);
    var ok = 0;
    for (final f in r.files) {
      if (f.path == null) continue;
      try {
        await store.addFile(f.path!, f.name, f.size);
        ok++;
      } catch (e) {
        if (mounted) toast(context, '${f.name}: $e', error: true);
      }
    }
    try {
      await FilePicker.platform.clearTemporaryFiles();
    } catch (_) {}
    if (ok > 0 && mounted) toast(context, 'আপলোড সম্পন্ন হয়েছে');
  }

  Widget navItem(int i, IconData icon, String label) {
    final on = tab == i;
    final c = on ? const Color(0xFF5B5BF0) : context.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => tab = i),
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 250),
        style: TextStyle(fontSize: 12, color: c, fontWeight: on ? FontWeight.w600 : FontWeight.w400),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: c, size: 24),
          const SizedBox(height: 2),
          Text(label),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          child: tab == 0 ? const FilesPage(key: ValueKey(0)) : const SettingsPage(key: ValueKey(1)),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).padding.bottom + 14,
          child: SizedBox(
            height: 68,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), boxShadow: context.shadow),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Container(
                      decoration: BoxDecoration(
                        color: context.sf.withAlpha(200),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: context.line),
                      ),
                      child: Row(children: [
                        Expanded(child: navItem(0, Icons.folder_outlined, 'ফাইল')),
                        const SizedBox(width: 90),
                        Expanded(child: navItem(1, Icons.tune_rounded, 'সেটিংস')),
                      ]),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Transform.translate(
                  offset: const Offset(0, -22),
                  child: ListenableBuilder(
                    listenable: store,
                    builder: (_, __) => GradButton(
                      width: 60,
                      height: 60,
                      radius: 22,
                      onTap: store.uploading ? null : upload,
                      child: store.uploading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Icon(Icons.add_rounded, color: Colors.white, size: 30),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
