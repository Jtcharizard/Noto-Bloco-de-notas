import 'package:flutter/material.dart';

import 'noto_home_v2.dart';
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
          theme: notoTheme(store, Brightness.light),
          darkTheme: notoTheme(store, Brightness.dark),
          themeMode: store.mode,
          home: !store.loaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : store.onboardingDone
                  ? GlobalWallpaper(
                      store: store,
                      child: HomeShellV2(store: store),
                    )
                  : OnboardingPage(store: store),
        ),
      );
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.store});
  final AppStore store;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final controller = PageController();
  int page = 0;

  static const pages = [
    (
      Icons.edit_note_rounded,
      'Tira da cabeça. Joga no Noto.',
      'Captura rápida manda a ideia pra Entrada. Tu organiza quando tiver tempo.'
    ),
    (
      Icons.bolt_rounded,
      'O Pulse presta atenção.',
      'Ele encontra tarefas, lembretes e padrões sem mandar teus textos pra lugar nenhum.'
    ),
    (
      Icons.auto_awesome_outlined,
      'Agora ele tem cara própria.',
      'Papel quente, tinta escura, laranja Noto e liberdade pra mudar fonte, cor e fundo.'
    ),
  ];

  void next() {
    if (page < pages.length - 1) {
      controller.nextPage(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    widget.store.onboardingDone = true;
    widget.store.save();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: controller,
                  itemCount: pages.length,
                  onPageChanged: (value) => setState(() => page = value),
                  itemBuilder: (_, index) {
                    final item = pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(30, 28, 30, 12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const NotoMark(size: 116),
                          const SizedBox(height: 34),
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .13),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              item.$1,
                              size: 31,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            item.$2,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.8,
                                ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.$3,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.all(4),
                    width: page == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: page == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: next,
                    icon: Icon(
                      page == pages.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(
                      page == pages.length - 1 ? 'Entrar no Noto' : 'Continuar',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
