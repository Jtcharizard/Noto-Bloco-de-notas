import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Ícones da barra de status que combinam com um texto dessa cor
/// (texto claro = fundo escuro = ícones claros).
SystemUiOverlayStyle overlayStyleFor(Color textColor) =>
    ThemeData.estimateBrightnessForColor(textColor) == Brightness.light
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

/// Tipo de cada linha na leitura.
enum ReaderLineKind { text, heading, task, quote, blank }

/// Uma linha já limpa para ler (sem os sinais do markdown).
class ReaderLine {
  const ReaderLine(this.text, this.kind);
  final String text;
  final ReaderLineKind kind;
}

final _task = RegExp(r'^(\s*)(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');
final _heading = RegExp(r'^\s{0,3}#{1,6}\s+(.*)$');
final _bullet = RegExp(r'^(\s*)[-*+•]\s+(.*)$');
final _quote = RegExp(r'^\s*>\s?(.*)$');
final _divider = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');
final _tableSeparator = RegExp(r'^\s*\|?[\s:|-]+\|?\s*$');

/// Tira os sinais de formatação de dentro da linha (negrito, link...).
String readerInline(String text) => text
    .replaceAllMapped(RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2]!)
    .replaceAllMapped(RegExp(r'~~(.+?)~~'), (m) => m[1]!)
    .replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1]!)
    .replaceAllMapped(
        RegExp(r'(^|[\s(])\*(\S(?:.*?\S)?)\*'), (m) => '${m[1]}${m[2]}');

/// Transforma o texto da nota em linhas fáceis de ler.
/// Tarefas viram "☐ tarefa" e "☑ feita".
List<ReaderLine> readerLines(String markdown) {
  final lines = <ReaderLine>[];
  var inCode = false;
  for (final raw in markdown.split('\n')) {
    final line = raw.trimRight();
    if (line.trimLeft().startsWith('```')) {
      inCode = !inCode;
      continue;
    }
    if (inCode) {
      lines.add(ReaderLine(line, ReaderLineKind.text));
      continue;
    }
    if (line.trim().isEmpty || _divider.hasMatch(line)) {
      lines.add(const ReaderLine('', ReaderLineKind.blank));
      continue;
    }
    final task = _task.firstMatch(line);
    if (task != null) {
      final depth = task[1]!.replaceAll('\t', '  ').length ~/ 2;
      final done = task[2]!.toLowerCase() == 'x';
      lines.add(
        ReaderLine(
          '${'    ' * depth}${done ? '☑' : '☐'} ${readerInline(task[3]!.trim())}',
          ReaderLineKind.task,
        ),
      );
      continue;
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      lines.add(
        ReaderLine(readerInline(heading[1]!.trim()), ReaderLineKind.heading),
      );
      continue;
    }
    final quote = _quote.firstMatch(line);
    if (quote != null) {
      lines.add(ReaderLine(readerInline(quote[1]!), ReaderLineKind.quote));
      continue;
    }
    if (line.trimLeft().startsWith('|')) {
      if (_tableSeparator.hasMatch(line)) continue;
      final cells = line
          .trim()
          .replaceAll(RegExp(r'^\||\|$'), '')
          .split('|')
          .map((c) => readerInline(c.trim()))
          .where((c) => c.isNotEmpty);
      lines.add(ReaderLine(cells.join(' · '), ReaderLineKind.text));
      continue;
    }
    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      final depth = bullet[1]!.replaceAll('\t', '  ').length ~/ 2;
      lines.add(
        ReaderLine(
          '${'    ' * depth}• ${readerInline(bullet[2]!)}',
          ReaderLineKind.text,
        ),
      );
      continue;
    }
    lines.add(ReaderLine(readerInline(line), ReaderLineKind.text));
  }
  // Sem linhas em branco sobrando no começo e no fim.
  while (lines.isNotEmpty && lines.first.kind == ReaderLineKind.blank) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.kind == ReaderLineKind.blank) {
    lines.removeLast();
  }
  return lines;
}

/// "Ler rolando": a nota em letra grande, rolando sozinha (como um
/// teleprompter). Só lê: nada na nota muda.
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.title,
    required this.text,
    this.titleFamily,
    this.bodyFamily,
    this.fontSize = 17,
    this.background,
    this.gradient,
    this.textColor,
    this.startDelay = const Duration(milliseconds: 1500),
  });

  final String title;

  /// Texto da nota (markdown simples; tarefas em "- [ ]").
  final String text;
  final String? titleFamily;
  final String? bodyFamily;

  /// Tamanho da letra da nota; a leitura usa uma letra maior.
  final double fontSize;
  final Color? background;
  final Gradient? gradient;
  final Color? textColor;

  /// Espera antes de começar a rolar, para dar tempo de ler o começo.
  final Duration startDelay;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage>
    with SingleTickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  late final List<ReaderLine> _lines = readerLines(widget.text);

  /// 1 (devagar) a 10 (rápido).
  double speed = 3;
  bool playing = true;
  bool _dragging = false;
  Duration _last = Duration.zero;
  late double _wait = widget.startDelay.inMicroseconds / 1e6;

  double get _readFontSize =>
      widget.fontSize * 1.35 < 22 ? 22 : widget.fontSize * 1.35;
  static const _lineHeight = 1.6;

  /// Pixels por segundo: na velocidade 1, cerca de uma linha a cada 4,5 s.
  double get _pixelsPerSecond =>
      speed *
      .22 *
      _readFontSize *
      _lineHeight *
      MediaQuery.textScalerOf(context).scale(1);

  /// Canal do Android que deixa a tela acesa enquanto a nota rola.
  static const _screen = MethodChannel('noto/share');

  void _keepScreenOn(bool on) {
    _screen.invokeMethod<void>('keepScreenOn', on).catchError((Object _) {
      /* Sem Android (ex.: testes): nada a fazer. */
    });
  }

  @override
  void initState() {
    super.initState();
    _keepScreenOn(true);
    _ticker.start();
  }

  @override
  void dispose() {
    _keepScreenOn(false);
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!mounted || dt <= 0 || !_scroll.hasClients || _dragging) return;
    if (_wait > 0) {
      _wait -= dt;
      return;
    }
    final position = _scroll.position;
    final next = position.pixels + _pixelsPerSecond * dt;
    if (next >= position.maxScrollExtent) {
      // Chegou ao fim: para.
      _scroll.jumpTo(position.maxScrollExtent);
      _setPlaying(false);
      return;
    }
    _scroll.jumpTo(next);
  }

  bool get _atEnd =>
      _scroll.hasClients &&
      _scroll.position.pixels >= _scroll.position.maxScrollExtent - 1;

  void _setPlaying(bool value) {
    if (!mounted) return;
    setState(() => playing = value);
    if (value) {
      _last = Duration.zero;
      if (!_ticker.isActive) _ticker.start();
    } else if (_ticker.isActive) {
      _ticker.stop();
    }
  }

  void _toggle() {
    if (!playing && _atEnd && _scroll.position.maxScrollExtent > 0) {
      // No fim, "Continuar" lê de novo desde o começo.
      _scroll.jumpTo(0);
      _wait = widget.startDelay.inMicroseconds / 1e6;
    }
    _setPlaying(!playing);
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
    } else if (notification is ScrollEndNotification) {
      _dragging = false;
    }
    return false;
  }

  Widget _line(ReaderLine line, Color? color) {
    final base = TextStyle(
      fontFamily: widget.bodyFamily,
      fontSize: _readFontSize,
      height: _lineHeight,
      color: color,
    );
    return switch (line.kind) {
      ReaderLineKind.blank => SizedBox(height: _readFontSize * .7),
      ReaderLineKind.heading => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(
            line.text,
            style: base.copyWith(
              fontSize: _readFontSize * 1.2,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ),
      ReaderLineKind.quote => Text(
          line.text,
          style: base.copyWith(
            fontStyle: FontStyle.italic,
            color:
                (color ?? Theme.of(context).colorScheme.onSurface).withValues(
              alpha: .8,
            ),
          ),
        ),
      _ => Text(line.text, style: base),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = widget.textColor;
    final height = MediaQuery.sizeOf(context).height;
    final page = Scaffold(
      backgroundColor:
          widget.gradient != null ? Colors.transparent : widget.background,
      appBar: AppBar(
        backgroundColor:
            widget.gradient != null ? Colors.transparent : widget.background,
        foregroundColor: fg,
        systemOverlayStyle:
            widget.gradient != null && fg != null ? overlayStyleFor(fg) : null,
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Text('Ler rolando'),
      ),
      body: Column(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: ListView(
                  controller: _scroll,
                  padding: EdgeInsets.fromLTRB(24, 12, 24, height * .45),
                  children: [
                    if (widget.title.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Text(
                          widget.title.trim(),
                          style: TextStyle(
                            fontFamily: widget.titleFamily,
                            fontSize: _readFontSize * 1.45,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                            color: fg,
                          ),
                        ),
                      ),
                    if (_lines.isEmpty)
                      Text(
                        'Esta nota ainda não tem texto.',
                        style: TextStyle(
                          fontSize: _readFontSize,
                          color: (fg ?? cs.onSurface).withValues(alpha: .6),
                        ),
                      ),
                    for (final line in _lines) _line(line, fg),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 16, 10),
              child: Material(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(18),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 10, 4),
                  child: Row(
                    children: [
                      IconButton.filled(
                        tooltip: playing ? 'Pausar' : 'Continuar',
                        onPressed: _toggle,
                        icon: Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Velocidade',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: speed,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${speed.round()}',
                          semanticFormatterCallback: (value) =>
                              'Velocidade ${value.round()}',
                          onChanged: (value) => setState(() => speed = value),
                        ),
                      ),
                      SizedBox(
                        width: 22,
                        child: Text(
                          '${speed.round()}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (widget.gradient == null) return page;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: widget.gradient),
      child: page,
    );
  }
}
