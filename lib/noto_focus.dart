import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_models.dart';
import 'noto_store.dart';

/// Minutos que o Timer de foco oferece.
const focusPresets = <int>[15, 25, 45, 60];

/// Mensagem de quando o tempo de foco acaba.
const focusDoneMessage = 'Tempo de foco terminou! Hora de uma pausa.';

/// Abre o Timer de foco (Pomodoro).
Future<void> openFocusTimer(BuildContext context, AppStore store) =>
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => FocusTimerPage(store: store)),
    );

/// "mm:ss" do tempo que falta (arredonda para cima, sem número negativo).
String focusClock(Duration left) {
  final seconds = left.isNegative ? 0 : (left.inMilliseconds / 1000).ceil();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(seconds ~/ 60)}:${two(seconds % 60)}';
}

/// Timer de foco: escolhe os minutos, começa, pausa e para. Quando está
/// rodando, o fim fica salvo em [AppStore.focusEndsAt], então sair e voltar
/// mostra o tempo certo. Um aviso agendado toca mesmo com o app fechado.
class FocusTimerPage extends StatefulWidget {
  const FocusTimerPage({super.key, required this.store});

  final AppStore store;

  @override
  State<FocusTimerPage> createState() => _FocusTimerPageState();
}

class _FocusTimerPageState extends State<FocusTimerPage> {
  Timer? _ticker;

  /// Tempo que faltava quando pausou (null = não está pausado).
  Duration? _paused;

  AppStore get store => widget.store;

  bool get _running => store.focusEndsAt != null;

  @override
  void initState() {
    super.initState();
    final ends = store.focusEndsAt;
    if (ends == null) return;
    if (ends.isAfter(DateTime.now())) {
      _startTicker();
    } else {
      // Terminou com a tela fechada: o aviso já tocou, só limpa.
      store.focusEndsAt = null;
      store.save();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final ends = store.focusEndsAt;
    if (ends == null) {
      _ticker?.cancel();
      setState(() {});
      return;
    }
    if (!ends.isAfter(DateTime.now())) {
      _finish();
      return;
    }
    setState(() {});
  }

  Duration get _total => Duration(minutes: store.focusMinutes);

  Duration get _left {
    final ends = store.focusEndsAt;
    if (ends != null) {
      final left = ends.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }
    return _paused ?? _total;
  }

  Future<void> _start() async {
    final ends = DateTime.now().add(_paused ?? _total);
    NotoHaptics.light();
    setState(() {
      _paused = null;
      store.focusEndsAt = ends;
    });
    _startTicker();
    await store.save();
    await store.scheduleFocusDone(ends);
  }

  Future<void> _pause() async {
    final left = _left;
    _ticker?.cancel();
    NotoHaptics.selection();
    setState(() {
      _paused = left;
      store.focusEndsAt = null;
    });
    await store.save();
    await store.cancelFocusDone();
  }

  Future<void> _stop() async {
    _ticker?.cancel();
    NotoHaptics.selection();
    setState(() {
      _paused = null;
      store.focusEndsAt = null;
    });
    await store.save();
    await store.cancelFocusDone();
  }

  Future<void> _finish() async {
    _ticker?.cancel();
    NotoHaptics.medium();
    setState(() {
      _paused = null;
      store.focusEndsAt = null;
    });
    store.save();
    // O app está aberto e já avisou aqui: tira o aviso agendado (no modo sem
    // horário exato ele poderia chegar atrasado).
    store.cancelFocusDone();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.timer_off_outlined),
        content: const Text(focusDoneMessage, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Ok'),
          ),
        ],
      ),
    );
  }

  void _choose(int minutes) {
    NotoHaptics.selection();
    setState(() {
      _paused = null;
      store.focusMinutes = minutes;
    });
    store.save();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final running = _running;
    final paused = !running && _paused != null;
    final busy = running || paused;
    final left = _left;
    final totalSeconds = _total.inSeconds;
    final progress = totalSeconds == 0
        ? 0.0
        : (left.inMilliseconds / 1000 / totalSeconds).clamp(0.0, 1.0);
    final hint = running
        ? 'Termina às ${DateFormat('HH:mm').format(store.focusEndsAt!)}. '
              'O Noto avisa mesmo com o app fechado.'
        : paused
        ? 'Pausado. Toque em Continuar quando quiser.'
        : 'Escolha o tempo e toque em Começar.';
    return Scaffold(
      appBar: AppBar(title: const Text('Timer de foco')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in focusPresets)
                  ChoiceChip(
                    label: Text('$minutes min'),
                    selected: store.focusMinutes == minutes,
                    onSelected: busy ? null : (_) => _choose(minutes),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 240,
                height: 240,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      color: cs.primary,
                      backgroundColor: cs.primary.withValues(alpha: .14),
                    ),
                    Center(
                      child: Text(
                        focusClock(left),
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: .66)),
            ),
            const SizedBox(height: 24),
            if (!busy)
              FilledButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Começar'),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: running
                        ? FilledButton.tonalIcon(
                            onPressed: _pause,
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pausar'),
                          )
                        : FilledButton.icon(
                            onPressed: _start,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Continuar'),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Parar'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
