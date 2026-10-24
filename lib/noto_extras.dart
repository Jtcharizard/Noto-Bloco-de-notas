import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'noto_theme.dart';

/// Texto da nota preparado para ler ou desenhar: tira marcações de Markdown
/// e troca as caixas de tarefa por símbolos.
String noteImageText(String title, String body, {bool forImage = false}) {
  final lines = body.split('\n').map((line) {
    final task = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$').firstMatch(line);
    if (task != null) {
      final done = task.group(1) != ' ';
      if (forImage) return '${done ? '☑' : '☐'}  ${task.group(2)}';
      return '${task.group(2)}${done ? ', feito' : ''}.';
    }
    return line
        .replaceAll(RegExp(r'^#{1,6}\s+'), '')
        .replaceAll(RegExp(r'^\s*>\s?'), '')
        .replaceAll(RegExp(r'\*\*|__|~~|`'), '')
        .replaceAll(RegExp(r'\[\[([^\]]+)\]\]'), r'$1');
  });
  final text = lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  if (forImage) return text;
  return [if (title.trim().isNotEmpty) '${title.trim()}.', text].join('\n');
}

/// Mostra a nota como um cartão bonito e compartilha como imagem PNG.
Future<void> shareNoteAsImage(
  BuildContext context, {
  required String title,
  required String body,
  Color? background,
  String? fontFamily,
}) async {
  final key = GlobalKey();
  var text = noteImageText(title, body, forImage: true);
  if (text.length > 1400) text = '${text.substring(0, 1400).trimRight()}…';
  final cs = Theme.of(context).colorScheme;
  final bg = background ?? cs.surfaceContainerHigh;
  final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1B1B1F);
  var busy = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => Dialog(
        insetPadding: const EdgeInsets.all(18),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: RepaintBoundary(
                  key: key,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: cs.primary.withValues(alpha: .35), width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title.trim().isNotEmpty) ...[
                          Text(
                            title.trim(),
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 24,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              color: fg,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            fontFamily: fontFamily,
                            fontSize: 16,
                            height: 1.45,
                            color: fg.withValues(alpha: .88),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const NotoMark(size: 20),
                            const SizedBox(width: 6),
                            Text(
                              'Noto',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: fg.withValues(alpha: .7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            setDialogState(() => busy = true);
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final boundary = key.currentContext!.findRenderObject()!
                                  as RenderRepaintBoundary;
                              final image = await boundary.toImage(pixelRatio: 3);
                              final data = await image.toByteData(
                                format: ui.ImageByteFormat.png,
                              );
                              image.dispose();
                              final dir = await getTemporaryDirectory();
                              final file = File(
                                '${dir.path}/noto-${DateTime.now().millisecondsSinceEpoch}.png',
                              );
                              await file.writeAsBytes(data!.buffer.asUint8List());
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              await Share.shareXFiles(
                                [XFile(file.path, mimeType: 'image/png')],
                              );
                            } catch (_) {
                              if (dialogContext.mounted) Navigator.pop(dialogContext);
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Não deu para criar a imagem.'),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Compartilhar imagem'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

const _emojiChoices = [
  '📁', '⭐', '❤️', '🏠', '💼', '📚', '🎓', '✏️', '🛒', '🍳',
  '💰', '💡', '🎯', '✅', '📅', '⏰', '🏋️', '🧘', '💊', '🩺',
  '✈️', '🚗', '🎮', '🎵', '🎬', '📷', '🎨', '🐶', '🐱', '🌱',
  '☕', '🍕', '🎁', '🎉', '🔒', '🔧', '💻', '📱', '🌙', '🔥',
];

/// Escolhe um emoji (para pastas). Devolve '' para tirar o emoji
/// e null se cancelar.
Future<String?> pickEmoji(
  BuildContext context, {
  required String title,
  String? current,
}) {
  final typed = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(ctx).bottom +
              MediaQuery.viewPaddingOf(ctx).bottom +
              16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 8,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: [
                for (final emoji in _emojiChoices)
                  Material(
                    color: emoji == current
                        ? cs.primaryContainer
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(ctx, emoji),
                      child: Center(
                        child: Text(emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typed,
              maxLength: 4,
              decoration: const InputDecoration(
                hintText: 'Ou digite qualquer emoji',
                counterText: '',
              ),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) Navigator.pop(ctx, value.trim());
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (current != null && current.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => Navigator.pop(ctx, ''),
                    icon: const Icon(Icons.block_rounded),
                    label: const Text('Tirar emoji'),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    final value = typed.text.trim();
                    Navigator.pop(ctx, value.isEmpty ? null : value);
                  },
                  child: const Text('Usar'),
                ),
              ],
            ),
          ],
        ),
      );
    },
  ).whenComplete(() => Future<void>.delayed(
        const Duration(milliseconds: 400),
        typed.dispose,
      ));
}

/// Tema pronto: muda várias opções de aparência de uma vez.
class NotoPreset {
  const NotoPreset({
    required this.name,
    required this.mode,
    required this.accent,
    required this.font,
    this.pureBlack = false,
    this.cardRadius = 16,
  });

  final String name;
  final ThemeMode mode;
  final int accent;
  final int font;
  final bool pureBlack;
  final int cardRadius;
}

const notoPresets = <NotoPreset>[
  NotoPreset(name: 'Noto', mode: ThemeMode.system, accent: 0, font: 0),
  NotoPreset(
    name: 'Meia-noite',
    mode: ThemeMode.dark,
    accent: 17,
    font: 20,
    pureBlack: true,
    cardRadius: 10,
  ),
  NotoPreset(name: 'Papel', mode: ThemeMode.light, accent: 9, font: 13, cardRadius: 4),
  NotoPreset(name: 'Oceano', mode: ThemeMode.light, accent: 2, font: 14, cardRadius: 26),
  NotoPreset(name: 'Floresta', mode: ThemeMode.dark, accent: 5, font: 35),
  NotoPreset(name: 'Chiclete', mode: ThemeMode.light, accent: 14, font: 25, cardRadius: 26),
  NotoPreset(name: 'Pôr do sol', mode: ThemeMode.dark, accent: 11, font: 29),
  NotoPreset(name: 'Código', mode: ThemeMode.dark, accent: 6, font: 22, pureBlack: true, cardRadius: 4),
  NotoPreset(name: 'Lavanda', mode: ThemeMode.light, accent: 16, font: 15, cardRadius: 26),
  NotoPreset(name: 'Café', mode: ThemeMode.light, accent: 10, font: 33, cardRadius: 10),
  NotoPreset(name: 'Neon', mode: ThemeMode.dark, accent: 15, font: 28, pureBlack: true),
  NotoPreset(name: 'Menta', mode: ThemeMode.light, accent: 4, font: 30, cardRadius: 26),
  NotoPreset(name: 'Cereja', mode: ThemeMode.dark, accent: 13, font: 5),
  NotoPreset(name: 'Gelo', mode: ThemeMode.light, accent: 3, font: 31, cardRadius: 10),
  NotoPreset(name: 'Grafite', mode: ThemeMode.dark, accent: 1, font: 16, cardRadius: 4),
  NotoPreset(name: 'Limão', mode: ThemeMode.light, accent: 7, font: 19, cardRadius: 26),
];

/// "Bom dia", "Boa tarde" ou "Boa noite" pela hora certa do celular.
String greetingFor(DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) return 'Bom dia';
  if (hour >= 12 && hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

const _weekdaysPt = [
  'segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira',
  'sexta-feira', 'sábado', 'domingo',
];
const _monthsPt = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

/// "sábado, 24 de outubro", sem depender dos dados de idioma carregados.
String longDatePt(DateTime day) =>
    '${_weekdaysPt[day.weekday - 1]}, ${day.day} de ${_monthsPt[day.month - 1]}';
