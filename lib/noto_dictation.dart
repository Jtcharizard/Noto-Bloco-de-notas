import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Abre a folha de ditado e devolve o texto falado (ou null se cancelar).
Future<String?> showDictation(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => const _DictationSheet(),
    );

class _DictationSheet extends StatefulWidget {
  const _DictationSheet();

  @override
  State<_DictationSheet> createState() => _DictationSheetState();
}

class _DictationSheetState extends State<_DictationSheet> {
  final speech = SpeechToText();
  String heard = '';
  String status = 'Preparando o microfone…';
  bool listening = false;
  bool failed = false;
  double level = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final ready = await speech.initialize(
        onError: (error) {
          if (!mounted) return;
          setState(() {
            listening = false;
            failed = heard.isEmpty;
            status = heard.isEmpty
                ? 'Não entendi. Toque em "Falar de novo".'
                : 'Pronto. Confira e toque em "Usar texto".';
          });
        },
        onStatus: (value) {
          if (!mounted) return;
          if (value == 'done' || value == 'notListening') {
            setState(() {
              listening = false;
              status = heard.isEmpty
                  ? 'Não ouvi nada. Toque em "Falar de novo".'
                  : 'Pronto. Confira e toque em "Usar texto".';
            });
          }
        },
      );
      if (!mounted) return;
      if (!ready) {
        setState(() {
          failed = true;
          status =
              'O ditado não está disponível. Confira a permissão do '
              'microfone e se o celular tem o reconhecimento de voz do Google.';
        });
        return;
      }
      await _listen();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        failed = true;
        status = 'Não foi possível usar o microfone agora.';
      });
    }
  }

  Future<void> _listen() async {
    setState(() {
      listening = true;
      failed = false;
      status = 'Pode falar…';
    });
    await speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (!mounted) return;
        setState(() => heard = result.recognizedWords);
      },
      onSoundLevelChange: (value) {
        if (mounted) setState(() => level = value);
      },
      localeId: 'pt_BR',
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        listenMode: ListenMode.dictation,
        cancelOnError: true,
      ),
    );
  }

  Future<void> _stop() async {
    await speech.stop();
    if (mounted) setState(() => listening = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 44 + (listening ? level.clamp(0, 10) * 2 : 0),
                height: 44 + (listening ? level.clamp(0, 10) * 2 : 0),
                decoration: BoxDecoration(
                  color: listening ? cs.primary : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: listening ? cs.onPrimary : cs.onSurface,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  status,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60, maxHeight: 200),
            child: SingleChildScrollView(
              child: Text(
                heard.isEmpty ? 'O que você falar aparece aqui.' : heard,
                style: TextStyle(
                  fontSize: 17,
                  height: 1.4,
                  color: heard.isEmpty
                      ? cs.onSurface.withValues(alpha: .5)
                      : cs.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              const Spacer(),
              if (listening)
                OutlinedButton(onPressed: _stop, child: const Text('Parar'))
              else if (!failed || heard.isEmpty)
                OutlinedButton(
                  onPressed: _listen,
                  child: const Text('Falar de novo'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: heard.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, heard.trim()),
                child: const Text('Usar texto'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
