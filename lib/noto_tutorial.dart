import 'package:flutter/material.dart';

import 'noto_theme.dart';

class _TutorialStep {
  const _TutorialStep(this.icon, this.title, this.text, this.points);
  final IconData icon;
  final String title;
  final String text;
  final List<(IconData, String)> points;
}

const _steps = <_TutorialStep>[
  _TutorialStep(
    Icons.edit_note_rounded,
    'Crie do seu jeito',
    'Toque no + para começar uma nota em branco ou uma lista de tarefas.',
    [
      (Icons.check_box_outlined, 'Na lista, Enter cria a próxima tarefa.'),
      (Icons.notes_rounded, 'Texto e tarefas podem ficar juntos na mesma nota.'),
      (Icons.bookmark_outline_rounded, 'Salve qualquer nota como modelo pelo menu ⋮.'),
    ],
  ),
  _TutorialStep(
    Icons.folder_open_rounded,
    'Organize sem esforço',
    'Use pastas, tags e favoritos. Tudo é encontrado pela busca, com ou sem acento.',
    [
      (Icons.folder_outlined, 'Toque em Pastas ou Tags, no topo, para criar e renomear.'),
      (Icons.star_outline_rounded, 'A estrela marca a nota como favorita.'),
      (Icons.filter_list_rounded, 'A busca avançada filtra por pasta, prazo e mais.'),
    ],
  ),
  _TutorialStep(
    Icons.swipe_rounded,
    'Gestos que poupam tempo',
    'Na tela inicial, os cards respondem ao toque e ao deslize.',
    [
      (Icons.touch_app_outlined, 'Segure uma nota para selecionar várias.'),
      (Icons.archive_outlined, 'Deslize para a direita para arquivar.'),
      (Icons.delete_outline_rounded, 'Deslize para a esquerda para mandar à lixeira.'),
    ],
  ),
  _TutorialStep(
    Icons.notifications_active_outlined,
    'Não esqueça de nada',
    'Marque lembretes e prazos nas notas e veja tudo no calendário.',
    [
      (Icons.repeat_rounded, 'Lembretes podem repetir todo dia ou toda semana.'),
      (Icons.flag_outlined, 'Prioridade e prazo ficam no menu ⋮ da nota.'),
      (Icons.calendar_month_outlined, 'O calendário mostra o que tem em cada dia.'),
    ],
  ),
  _TutorialStep(
    Icons.lock_outline_rounded,
    'Cofre para notas privadas',
    'Notas no cofre ficam escondidas de tudo e só abrem com a sua senha.',
    [
      (Icons.drive_file_move_outline, 'Para guardar: menu ⋮ da nota > Mover para o cofre.'),
      (Icons.touch_app_outlined, 'Para abrir: segure o logo do Noto, no topo, por 2 segundos.'),
      (Icons.visibility_off_outlined, 'Elas somem da tela inicial, da busca, do calendário e do widget.'),
      (Icons.timer_outlined, 'O cofre trava sozinho quando você sai do app.'),
      (Icons.help_outline_rounded, 'Esqueceu a senha? A pergunta secreta cria outra sem apagar nada.'),
    ],
  ),
  _TutorialStep(
    Icons.palette_outlined,
    'Deixe com a sua cara',
    'Cada nota pode ter cor, fonte e fundo próprios. O app também.',
    [
      (Icons.tune_rounded, 'Botão Estilo, dentro da nota, muda a aparência dela.'),
      (Icons.settings_outlined, 'Em Ajustes: tema, fonte, fundo e widget.'),
      (Icons.upload_file_outlined, 'Faça backup de vez em quando, também nos Ajustes.'),
    ],
  ),
];

/// Tutorial de uso em 6 telas. Aparece na primeira vez e pelos Ajustes.
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  final controller = PageController();
  int page = 0;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  bool get _last => page == _steps.length - 1;

  void _next() {
    if (_last) {
      widget.onDone();
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  const NotoMark(size: 36),
                  const SizedBox(width: 8),
                  Text(
                    'Noto',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const Spacer(),
                  if (!_last)
                    TextButton(
                      onPressed: widget.onDone,
                      child: const Text('Pular'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: controller,
                itemCount: _steps.length,
                onPageChanged: (value) => setState(() => page = value),
                itemBuilder: (_, index) {
                  final step = _steps[index];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Icon(
                            step.icon,
                            size: 46,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          step.title,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -.8,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          step.text,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                height: 1.4,
                                color: cs.onSurface.withValues(alpha: .72),
                              ),
                        ),
                        const SizedBox(height: 26),
                        for (final point in step.points)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(point.$1, size: 22, color: cs.primary),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    point.$2,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(height: 1.35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 20),
              child: Row(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 6),
                      width: i == page ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i == page ? cs.primary : cs.outlineVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_last ? 'Começar' : 'Próximo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
