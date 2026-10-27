import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'noto_theme.dart';

class _TutorialStep {
  const _TutorialStep(this.image, this.title, this.text, this.points);
  final String image;
  final String title;
  final String text;
  final List<(IconData, String)> points;
}

const _steps = <_TutorialStep>[
  _TutorialStep(
    'ola',
    'Oi! Este é o Noto',
    'Um bloco de notas rápido, offline e do seu jeito. Em um minuto você pega o principal.',
    [
      (Icons.wifi_off_rounded, 'Funciona sem internet. Suas notas ficam no seu celular.'),
      (Icons.swipe_left_rounded, 'Arraste para o lado para ver as próximas dicas.'),
    ],
  ),
  _TutorialStep(
    'notas',
    'Notas e listas',
    'Toque no + para criar uma nota em branco ou uma lista de tarefas.',
    [
      (Icons.add_circle_outline_rounded, 'Segure o + para criar direto o outro tipo.'),
      (Icons.keyboard_return_rounded, 'Enter cria a próxima tarefa e continua listas como "1-" ou "-".'),
      (Icons.space_bar_rounded, 'A barra embaixo da nota tem desfazer, negrito, lista, voz e inserir.'),
      (Icons.keyboard_command_key_rounded, 'Digite / numa linha vazia para pôr título, lista, tabela e mais.'),
      (Icons.format_indent_increase_rounded, 'Nas listas, o ⋮ da tarefa cria subtarefas. Deslize para apagar.'),
    ],
  ),
  _TutorialStep(
    'organizar',
    'Tudo no lugar',
    'Pastas, tags e favoritos deixam tudo fácil de achar. A busca entende com ou sem acento.',
    [
      (Icons.folder_outlined, 'Na nota, toque na etiqueta da pasta, abaixo do título, para mudar pasta e tags.'),
      (Icons.more_vert_rounded, 'O ⋮ da nota junta tudo: fixar, enviar, exportar, cofre e mais.'),
      (Icons.apps_rounded, 'Na tela inicial, o Menu tem tarefas, lembretes, pastas, lixeira e Ajustes.'),
      (Icons.today_rounded, 'Menu > Hoje abre a nota do dia, como um diário.'),
      (Icons.emoji_emotions_outlined, 'Em Menu > Pastas, dê um emoji para cada pasta.'),
      (Icons.swipe_rounded, 'Segure um card para selecionar vários. Deslize para arquivar ou apagar.'),
    ],
  ),
  _TutorialStep(
    'lembretes',
    'Não esqueça de nada',
    'Toque no sininho da nota para marcar um lembrete.',
    [
      (Icons.edit_calendar_outlined, 'Escreva do seu jeito: "amanhã às 9", "sexta 18h", "em 2 horas".'),
      (Icons.repeat_rounded, 'Pode repetir todo dia, nos dias úteis, toda semana ou todo mês.'),
      (Icons.event_outlined, 'Com prazo, o card avisa: "vence amanhã", "venceu ontem".'),
      (Icons.calendar_month_outlined, 'O calendário mostra o que tem em cada dia.'),
    ],
  ),
  _TutorialStep(
    'cofre',
    'Cofre secreto',
    'Notas no cofre ficam escondidas de tudo e só abrem com a sua senha.',
    [
      (Icons.drive_file_move_outline, 'Para guardar: ⋮ da nota > Mover para o cofre.'),
      (Icons.touch_app_outlined, 'Para abrir: segure o logo do Noto, no topo, por 2 segundos.'),
      (Icons.visibility_off_outlined, 'Elas somem da tela inicial, da busca, do calendário e do widget.'),
      (Icons.timer_outlined, 'O cofre trava sozinho quando você sai do app.'),
      (Icons.help_outline_rounded, 'Esqueceu a senha? A pergunta secreta cria outra sem apagar nada.'),
    ],
  ),
  _TutorialStep(
    'estilo',
    'Com a sua cara',
    'Cada nota pode ter cor, fundo e fonte próprios. O app também.',
    [
      (Icons.palette_outlined, 'Na nota, o botão da paleta, ao lado da barra, muda cor, fundo e fonte.'),
      (Icons.settings_outlined, 'Em Ajustes > Aparência tem temas prontos de um toque, cores e fontes.'),
      (Icons.image_outlined, 'Pelo ⋮ dá para enviar a nota como imagem ou proteger contra edição.'),
    ],
  ),
  _TutorialStep(
    'pronto',
    'Tudo pronto!',
    'Agora é com você. Faça backup de vez em quando pelo Menu > Backup.',
    [
      (Icons.school_outlined, 'Quer rever? O tutorial fica em Ajustes > Ajuda e sobre.'),
    ],
  ),
];

/// Tutorial de uso com ilustrações. Aparece na primeira vez e pelos Ajustes.
class TutorialPage extends StatefulWidget {
  const TutorialPage({super.key, required this.onDone, this.onName});

  final VoidCallback onDone;

  /// Guarda o nome para a saudação (só na primeira abertura).
  final ValueChanged<String>? onName;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage>
    with SingleTickerProviderStateMixin {
  final controller = PageController();
  final name = TextEditingController();
  late final AnimationController floating = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();
  int page = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final step in _steps) {
      precacheImage(AssetImage('assets/onboarding/${step.image}.png'), context);
    }
  }

  @override
  void dispose() {
    floating.dispose();
    controller.dispose();
    name.dispose();
    super.dispose();
  }

  bool get _last => page == _steps.length - 1;

  void _next() {
    if (_last) {
      if (name.text.trim().isNotEmpty) widget.onName?.call(name.text.trim());
      widget.onDone();
      return;
    }
    controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _illustration(int index, ColorScheme cs, double size) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, floating]),
      builder: (context, child) {
        final current = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? page.toDouble()
            : page.toDouble();
        final delta = (index - current).clamp(-1.0, 1.0);
        // Um pulinho suave quando a tela aparece (sem animação sem fim,
        // que gastaria bateria).
        final v = floating.value;
        final hop = math.sin(math.pi * v) * (1 - v * .4);
        return Transform.translate(
          offset: Offset(delta * size * .35, -18 * hop),
          child: Transform.rotate(
            angle: delta * .25 + math.sin(2 * math.pi * v) * .05 * (1 - v),
            child: Opacity(
              opacity: (1 - delta.abs()).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: Image.asset(
        'assets/onboarding/${_steps[index].image}.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        children: [
          // Manchas de cor suaves atrás da ilustração.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: floating,
              builder: (_, __) => CustomPaint(
                painter: _BlobPainter(
                  primary: cs.primary,
                  secondary: cs.tertiary,
                  t: floating.value,
                  shift: page / (_steps.length - 1),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                  child: Row(
                    children: [
                      const NotoMark(size: 34),
                      const SizedBox(width: 8),
                      Text(
                        'Noto',
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: _last ? 0 : 1,
                        child: TextButton(
                          onPressed: _last ? null : widget.onDone,
                          child: const Text('Pular'),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageSize = math.min(
                        190.0,
                        constraints.maxHeight * .28,
                      );
                      return PageView.builder(
                        controller: controller,
                        itemCount: _steps.length,
                        onPageChanged: (value) {
                          setState(() => page = value);
                          floating.forward(from: 0);
                        },
                        itemBuilder: (_, index) {
                          final step = _steps[index];
                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(28, 18, 28, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: imageSize + 30,
                                  width: double.infinity,
                                  child: Center(
                                    child: _illustration(index, cs, imageSize),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  step.title,
                                  style: text.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  step.text,
                                  style: text.titleMedium?.copyWith(
                                    height: 1.4,
                                    color: cs.onSurface.withValues(alpha: .72),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                for (final point in step.points)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(
                                              alpha: .12,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(11),
                                          ),
                                          child: Icon(
                                            point.$1,
                                            size: 19,
                                            color: cs.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              point.$2,
                                              style: text.bodyLarge?.copyWith(
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (index == _steps.length - 1 &&
                                    widget.onName != null) ...[
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: name,
                                    maxLength: 20,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => _next(),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.waving_hand_outlined),
                                      labelText: 'Como quer ser chamado?',
                                      helperText:
                                          'Opcional. O Noto te cumprimenta pelo nome.',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
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
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.only(right: 6),
                          width: i == page ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: i == page ? cs.primary : cs.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _next,
                        icon: Icon(
                          _last
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                        ),
                        label: Text(_last ? 'Começar' : 'Próximo'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({
    required this.primary,
    required this.secondary,
    required this.t,
    required this.shift,
  });

  final Color primary;
  final Color secondary;
  final double t;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    final w = size.width, h = size.height;
    blob(
      Offset(w * (.72 - .3 * shift), h * (.22 + .03 * t)),
      w * .55,
      primary,
    );
    blob(
      Offset(w * (.18 + .25 * shift), h * (.12 - .02 * t)),
      w * .38,
      secondary,
    );
  }

  @override
  bool shouldRepaint(_BlobPainter old) =>
      old.t != t || old.shift != shift || old.primary != primary;
}
