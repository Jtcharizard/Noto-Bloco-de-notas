import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Object? _loadError;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  /// Lê as notas. Se der erro ou demorar demais, mostra uma tela clara
  /// em vez de ficar carregando para sempre.
  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _slow = false;
    });
    Future<void>.delayed(const Duration(seconds: 6), () {
      if (mounted && !store.loaded && _loadError == null) {
        setState(() => _slow = true);
      }
    });
    try {
      await store.load().timeout(const Duration(seconds: 25));
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
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
      home: _loadError != null
          ? _LoadProblem(error: _loadError!, onRetry: _load)
          : !store.loaded
          ? Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (_slow) ...[
                      const SizedBox(height: 18),
                      const Text('Abrindo suas notas…'),
                    ],
                  ],
                ),
              ),
            )
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

class _LoadProblem extends StatelessWidget {
  const _LoadProblem({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final details = error.toString();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 52, color: cs.error),
                const SizedBox(height: 14),
                Text(
                  'Não consegui abrir as notas',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Suas notas continuam guardadas no celular; nada foi apagado. '
                  'Tente de novo. Se continuar, copie os detalhes e envie para quem '
                  'cuida do app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
                TextButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: details));
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(content: Text('Detalhes copiados')),
                    );
                  },
                  child: const Text('Copiar detalhes'),
                ),
                const SizedBox(height: 8),
                Text(
                  details.length > 400 ? '${details.substring(0, 400)}…' : details,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurface.withValues(alpha: .55),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
