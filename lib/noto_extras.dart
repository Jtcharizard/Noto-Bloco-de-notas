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
