import 'package:flutter/material.dart';

import 'noto_home.dart';
import 'noto_store.dart';
import 'noto_theme.dart';
import 'noto_tutorial.dart';
import 'noto_vault.dart';

final notoNavigatorKey = GlobalKey<NavigatorState>();

class NotoApp extends StatefulWidget {
  const NotoApp({super.key});

  @override
  State<NotoApp> createState() => _NotoAppState();
}

class _NotoAppState extends State<NotoApp> with WidgetsBindingObserver {
  final store = AppStore();
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Com o cofre aberto, sair do app por mais de 30 segundos bloqueia de novo.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null &&
          DateTime.now().difference(left) > const Duration(seconds: 30)) {
        store.requestVaultLock();
      }
    }
  }

  void _leaveVault() {
    notoNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    store.releaseVaultLock();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noto',
      navigatorKey: notoNavigatorKey,
      builder: (context, child) => Stack(
        children: [
          NotoSafeFrame(child: child ?? const SizedBox()),
          if (store.vaultLockRequested && store.vaultScreensOpen > 0)
            Positioned.fill(
              // Overlay próprio: o campo de senha precisa de um para funcionar
              // aqui, acima das telas do app.
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (_) =>
                        VaultLockScreen(store: store, onLeave: _leaveVault),
                  ),
                ],
              ),
            ),
        ],
      ),
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
