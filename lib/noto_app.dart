import 'package:flutter/material.dart';

import 'noto_home.dart';
import 'noto_store.dart';
import 'noto_theme.dart';
import 'noto_tutorial.dart';

class NotoApp extends StatefulWidget {
  const NotoApp({super.key});

  @override
  State<NotoApp> createState() => _NotoAppState();
}

class _NotoAppState extends State<NotoApp> {
  final store = AppStore();

  @override
  void initState() {
    super.initState();
    store.load();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noto',
      builder: (context, child) =>
          NotoSafeFrame(child: child ?? const SizedBox()),
      theme: notoTheme(store, Brightness.light),
      darkTheme: notoTheme(store, Brightness.dark),
      themeMode: store.mode,
      home: !store.loaded
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : store.onboardingDone
          ? GlobalWallpaper(
              store: store,
              child: HomeShell(store: store),
            )
          : TutorialPage(
              onDone: () {
                store.onboardingDone = true;
                store.save();
              },
            ),
    ),
  );
}
