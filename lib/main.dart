import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home.dart';
import 'screens/lock.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await store.load();
  runApp(const TeleCloudApp());
}

class TeleCloudApp extends StatefulWidget {
  const TeleCloudApp({super.key});
  @override
  State<TeleCloudApp> createState() => _TeleCloudAppState();
}

class _TeleCloudAppState extends State<TeleCloudApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) store.onPaused();
    if (s == AppLifecycleState.resumed) store.onResumed();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'TeleCloud',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: store.themeMode,
        builder: (ctx, child) {
          final dark = Theme.of(ctx).brightness == Brightness.dark;
          final icons = dark ? Brightness.light : Brightness.dark;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              statusBarIconBrightness: icons,
              systemNavigationBarIconBrightness: icons,
            ),
            child: Stack(children: [child!, if (store.locked) const Positioned.fill(child: LockScreen())]),
          );
        },
        home: const HomeShell(),
      ),
    );
  }
}
