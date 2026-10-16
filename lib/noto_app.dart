import 'package:flutter/material.dart';

import 'noto_home_v4.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

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
              child: HomeShellV4(store: store),
            )
          : OnboardingPage(store: store),
    ),
  );
}

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NotoMark(size: 58),
              const Spacer(),
              Text(
                'Noto',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.8,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Um lugar simples para escrever, guardar e encontrar depois.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.35,
                  color: cs.onSurface.withValues(alpha: .68),
                ),
              ),
              const SizedBox(height: 34),
              const _IntroLine(
                'Anotação rápida para quando você só quer tirar uma ideia da cabeça.',
              ),
              const _IntroLine(
                'Pastas, tags e busca para quando precisar organizar.',
              ),
              const _IntroLine(
                'Suas notas ficam só no seu celular, sem conta e sem internet.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    store.onboardingDone = true;
                    store.save();
                  },
                  child: const Text('Começar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 2,
            margin: const EdgeInsets.only(top: 9, right: 12),
            color: cs.primary,
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
