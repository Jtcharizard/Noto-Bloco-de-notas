import 'noto_rich_editor.dart';

import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_settings.dart' as legacy;
import 'noto_store.dart';
import 'noto_theme.dart';

String priorityLabel(int priority) => switch (priority) {
  1 => 'Baixa',
  2 => 'Média',
  3 => 'Alta',
  _ => 'Sem prioridade',
};

IconData priorityIcon(int priority) => switch (priority) {
  1 => Icons.keyboard_arrow_down_rounded,
  2 => Icons.remove_rounded,
  3 => Icons.keyboard_double_arrow_up_rounded,
  _ => Icons.flag_outlined,
};

Future<String?> pickPersistentImage(String prefix) async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  final dir = await getApplicationDocumentsDirectory();
  final ext = picked.path.contains('.') ? picked.path.split('.').last : 'jpg';
  final target = File(
    '${dir.path}/${prefix}_${DateTime.now().microsecondsSinceEpoch}.$ext',
  );
  await File(picked.path).copy(target.path);
  return target.path;
}

String _safeFileName(String input) {
  final clean = input
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return clean.isEmpty ? 'nota' : clean;
}

Future<void> exportNoteFile(Note note, {required bool markdown}) async {
  final dir = await getTemporaryDirectory();
  final ext = markdown ? 'md' : 'txt';
  final title = note.title.trim().isEmpty ? 'Sem título' : note.title.trim();
  final path = '${dir.path}/${_safeFileName(title)}.$ext';
  final tables = ((note.editor['tables'] as List?) ?? []).map(
    (e) => NotoTable.fromJson(Map<String, dynamic>.from(e as Map)),
  );
  final code = ((note.editor['code'] as List?) ?? []).map(
    (c) => markdown
        ? '```${c['language']}\n${c['text']}\n```'
        : c['text'].toString(),
  );
  final body = [
    note.body,
    ...code,
    ...tables.map((t) => markdown ? t.markdown : t.plainText),
  ].join('\n\n');
  final content = markdown
      ? '# $title\n\n$body\n\n---\nExportado pelo Noto'
      : '$title\n\n$body\n\n— Noto';
  final file = File(path);
  await file.writeAsString(content);
  await Share.shareXFiles([XFile(file.path)], text: 'Exportado pelo Noto');
}

Future<pw.Font?> _pdfFont(String asset) async {
  try {
    return pw.Font.ttf(await rootBundle.load(asset));
  } catch (_) {
    return null;
  }
}

/// Gera um PDF simples da nota (texto, tarefas, tabelas e código) e compartilha.
Future<void> exportNotePdf(Note note) async {
  final regular = await _pdfFont('assets/fonts/FiraSans-Regular.ttf');
  final bold = await _pdfFont('assets/fonts/Poppins-Bold.ttf');
  final doc = pw.Document(
    title: note.title,
    theme: regular == null
        ? null
        : pw.ThemeData.withFont(base: regular, bold: bold ?? regular),
  );
  final title = note.title.trim().isEmpty ? 'Sem título' : note.title.trim();
  final task = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');
  final content = <pw.Widget>[
    pw.Text(
      title,
      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    pw.Text(
      '${note.folder} · ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
    pw.SizedBox(height: 16),
  ];

  for (final raw in note.body.split('\n')) {
    final line = raw.replaceAll('**', '');
    final match = task.firstMatch(line);
    if (line.trim().isEmpty) {
      content.add(pw.SizedBox(height: 6));
    } else if (match != null) {
      final done = match.group(1)!.toLowerCase() == 'x';
      content.add(
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 9,
                height: 9,
                margin: const pw.EdgeInsets.only(top: 2, right: 7),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: .8),
                  color: done ? PdfColors.grey400 : null,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  match.group(2) ?? '',
                  style: pw.TextStyle(
                    fontSize: 11,
                    color: done ? PdfColors.grey600 : null,
                    decoration: done ? pw.TextDecoration.lineThrough : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (RegExp(r'^\s*#{1,6}\s').hasMatch(line)) {
      content.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.Text(
            line.replaceFirst(RegExp(r'^\s*#{1,6}\s+'), ''),
            style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
          ),
        ),
      );
    } else if (line.trimLeft().startsWith('>')) {
      content.add(
        pw.Container(
          padding: const pw.EdgeInsets.only(left: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              left: pw.BorderSide(color: PdfColors.grey500, width: 2),
            ),
          ),
          child: pw.Text(
            line.replaceFirst(RegExp(r'^\s*>\s?'), ''),
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ),
      );
    } else {
      content.add(
        pw.Text(
          line.replaceFirst(RegExp(r'^\s*[-*]\s+'), '•  '),
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
        ),
      );
    }
  }

  for (final table in ((note.editor['tables'] as List?) ?? const [])) {
    final data = NotoTable.fromJson(Map<String, dynamic>.from(table as Map));
    if (data.cells.isEmpty) continue;
    content
      ..add(pw.SizedBox(height: 12))
      ..add(
        pw.TableHelper.fromTextArray(
          data: data.cells,
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      );
  }
  for (final code in ((note.editor['code'] as List?) ?? const [])) {
    content
      ..add(pw.SizedBox(height: 12))
      ..add(
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          color: PdfColors.grey200,
          child: pw.Text(
            ((code as Map)['text'] ?? '').toString(),
            style: pw.TextStyle(font: pw.Font.courier(), fontSize: 9),
          ),
        ),
      );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      maxPages: 200,
      build: (_) => content,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Página ${context.pageNumber} de ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
    ),
  );

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${_safeFileName(title)}.pdf');
  await file.writeAsBytes(await doc.save());
  await Share.shareXFiles([XFile(file.path)], text: title);
}

Future<Note?> importTextNote({required int defaultFont}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['txt', 'md', 'markdown'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final selected = result.files.single;
  String content;
  if (selected.bytes != null) {
    content = utf8.decode(selected.bytes!, allowMalformed: true);
  } else if (selected.path != null) {
    content = await File(selected.path!).readAsString();
  } else {
    return null;
  }
  final filename = selected.name.replaceFirst(
    RegExp(r'\.(txt|md|markdown)$', caseSensitive: false),
    '',
  );
  final lines = content.split('\n');
  var title = filename;
  var body = content;
  if (selected.extension?.toLowerCase() != 'txt' &&
      lines.isNotEmpty &&
      lines.first.trim().startsWith('# ')) {
    title = lines.first.trim().substring(2).trim();
    body = lines.skip(1).join('\n').trimLeft();
  }
  return Note(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: title,
    body: body,
    updatedAt: DateTime.now(),
    font: defaultFont,
  );
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.store, required this.onOpen});

  final AppStore store;
  final Future<void> Function(Note note) onOpen;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime month = DateTime(DateTime.now().year, DateTime.now().month);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Note> _notesFor(DateTime day) => widget.store.notes.where((note) {
    if (note.deletedAt != null || note.locked) return false;
    return _sameDay(note.updatedAt, day) ||
        _sameDay(note.createdAt, day) ||
        (note.dueAt != null && _sameDay(note.dueAt!, day)) ||
        reminderOccursOn(note, day);
  }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  void _changeMonth(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
  });

  Future<void> _openDay(DateTime day) async {
    final notes = _notesFor(day);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .62,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat("dd 'de' MMMM", 'pt_BR').format(day),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: notes.isEmpty
                  ? const Center(child: Text('Nada neste dia.'))
                  : ListView.builder(
                      itemCount: notes.length,
                      itemBuilder: (_, index) {
                        final note = notes[index];
                        final dueHere =
                            note.dueAt != null && _sameDay(note.dueAt!, day);
                        final reminderHere = reminderOccursOn(note, day);
                        return ListTile(
                          leading: Text(
                            note.emoji.isEmpty ? '•' : note.emoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(
                            note.title.trim().isEmpty
                                ? 'Sem título'
                                : note.title,
                          ),
                          subtitle: Text(
                            reminderHere
                                ? 'Lembrete às ${DateFormat('HH:mm').format(note.reminderAt!)}'
                                : dueHere
                                ? note.priority > 0
                                      ? 'Prazo · prioridade ${priorityLabel(note.priority).toLowerCase()}'
                                      : 'Prazo'
                                : _sameDay(note.createdAt, day) &&
                                      !_sameDay(note.updatedAt, day)
                                ? 'Criada neste dia'
                                : 'Editada neste dia',
                          ),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await widget.onOpen(note);
                            if (mounted) setState(() {});
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = (first.weekday + 6) % 7;
    final total = ((startOffset + days + 6) ~/ 7) * 7;
    const weekdays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendário'),
        actions: [
          IconButton(
            tooltip: 'Hoje',
            onPressed: () => setState(() {
              final now = DateTime.now();
              month = DateTime(now.year, now.month);
            }),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy', 'pt_BR').format(month),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: weekdays
                  .map(
                    (day) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          day,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 28),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: .82,
              ),
              itemCount: total,
              itemBuilder: (_, index) {
                final dayNumber = index - startOffset + 1;
                if (dayNumber < 1 || dayNumber > days)
                  return const SizedBox.shrink();
                final day = DateTime(month.year, month.month, dayNumber);
                final notes = _notesFor(day);
                final today = _sameDay(day, DateTime.now());
                return InkWell(
                  onTap: () => _openDay(day),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: today
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            fontWeight: today
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (notes.length > 1)
                            Text(
                              '${notes.length}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class MarkdownPreviewPage extends StatelessWidget {
  const MarkdownPreviewPage({
    super.key,
    required this.title,
    required this.markdown,
  });

  final String title;
  final String markdown;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title.trim().isEmpty ? 'Visualizar' : title),
    ),
    body: Markdown(
      data: markdown.replaceAllMapped(
        RegExp(r'^\[([ xX])\] ', multiLine: true),
        (match) => '- [${match[1]}] ',
      ),
      selectable: true,
      softLineBreak: true,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
      // Notes stay offline: never fetch remote images embedded in Markdown.
      imageBuilder: (uri, title, alt) => Text(alt ?? 'Imagem'),
    ),
  );
}

class PowerNoteStyleSheet extends StatefulWidget {
  const PowerNoteStyleSheet({
    super.key,
    required this.store,
    required this.note,
    required this.onChanged,
  });

  final AppStore store;
  final Note note;
  final VoidCallback onChanged;

  @override
  State<PowerNoteStyleSheet> createState() => _PowerNoteStyleSheetState();
}

class _PowerNoteStyleSheetState extends State<PowerNoteStyleSheet> {
  late final TextEditingController emoji = TextEditingController(
    text: widget.note.emoji,
  );

  @override
  void dispose() {
    emoji.dispose();
    super.dispose();
  }

  Future<void> _save(VoidCallback change) async {
    setState(change);
    await widget.store.save();
    widget.onChanged();
  }

  Future<void> _pickFont({required bool title}) async {
    final current = title
        ? (widget.note.titleFont ?? widget.note.font)
        : (widget.note.bodyFont ?? widget.note.font);
    final selected = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => legacy.FontPickerSheet(
        selected: NotoAppearance.safeFontIndex(current),
      ),
    );
    if (selected == null) return;
    await _save(() {
      if (title) {
        widget.note.titleFont = selected;
      } else {
        widget.note.bodyFont = selected;
      }
    });
  }

  Future<void> _pickCover() async {
    final path = await pickPersistentImage('noto_cover');
    if (path == null) return;
    await _save(() => widget.note.coverImage = path);
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            Text(
              'Estilo da nota',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emoji,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: 'Emoji da nota',
                hintText: 'Ex.: 📚',
              ),
              onChanged: (value) => _save(() => note.emoji = value.trim()),
            ),
            const SizedBox(height: 8),
            const Text(
              'COR DA NOTA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: List.generate(NotoAppearance.noteColors.length, (
                index,
              ) {
                final color = index == 0
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : NotoAppearance.noteColors[index];
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _save(() => note.color = index),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: color,
                    child: note.color == index
                        ? const Icon(Icons.check_rounded)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 18),
            const Text(
              'COR DO TEXTO',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: List.generate(NotoAppearance.textColors.length, (
                index,
              ) {
                final color = index == 0
                    ? Theme.of(context).colorScheme.surfaceContainerHighest
                    : NotoAppearance.textColors[index];
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _save(() => note.textColor = index),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: color,
                    child: note.textColor == index
                        ? const Icon(Icons.check_rounded)
                        : null,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.title_rounded),
              title: const Text('Fonte do título'),
              subtitle: Text(
                NotoAppearance
                    .fonts[NotoAppearance.safeFontIndex(
                      note.titleFont ?? note.font,
                    )]
                    .name,
              ),
              onTap: () => _pickFont(title: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.notes_rounded),
              title: const Text('Fonte do corpo'),
              subtitle: Text(
                NotoAppearance
                    .fonts[NotoAppearance.safeFontIndex(
                      note.bodyFont ?? note.font,
                    )]
                    .name,
              ),
              onTap: () => _pickFont(title: false),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.image_outlined),
              title: const Text('Capa no card'),
              subtitle: Text(
                note.coverImage == null ? 'Sem capa' : 'Com imagem',
              ),
              trailing: note.coverImage == null
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: 'Remover capa',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => _save(() => note.coverImage = null),
                    ),
              onTap: _pickCover,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('Wallpaper da nota'),
              subtitle: const Text('Imagem de fundo ao abrir a nota'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) =>
                    legacy.WallpaperSheet(store: widget.store, note: note),
              ).then((_) => widget.onChanged()),
            ),
            const SizedBox(height: 8),
            if (noteWallpaper(note) != null) ...[
              Text(
                'Escurecer fundo · ${(note.wallpaperDarkness * 100).round()}%',
              ),
              Slider(
                value: note.wallpaperDarkness,
                min: 0,
                max: .8,
                onChanged: (value) =>
                    _save(() => note.wallpaperDarkness = value),
              ),
              Text('Desfoque · ${note.wallpaperBlur.round()}'),
              Slider(
                value: note.wallpaperBlur,
                min: 0,
                max: 16,
                divisions: 16,
                onChanged: (value) => _save(() => note.wallpaperBlur = value),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
