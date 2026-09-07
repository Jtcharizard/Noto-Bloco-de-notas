import 'dart:convert';

import 'package:flutter/material.dart';

Map<String, dynamic> copyEditor(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);

/// UTF-16 offsets follow TextSelection. Edits translate existing format ranges.
class NotoRichController extends TextEditingController {
  NotoRichController({super.text, List<dynamic> styles = const []})
    : marks = styles.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  List<Map<String, dynamic>> marks;
  final Map<String, dynamic> typingStyle = {};
  bool restoring = false;

  @override
  set value(TextEditingValue next) {
    final previous = super.value;
    if (!restoring && previous.text != next.text) {
      var a = 0;
      while (a < previous.text.length &&
          a < next.text.length &&
          previous.text[a] == next.text[a]) {
        a++;
      }
      var oldEnd = previous.text.length;
      var newEnd = next.text.length;
      while (oldEnd > a &&
          newEnd > a &&
          previous.text[oldEnd - 1] == next.text[newEnd - 1]) {
        oldEnd--;
        newEnd--;
      }
      final shift = newEnd - oldEnd;
      final inherited = <String, dynamic>{};
      for (final mark in marks) {
        final start = mark['start'] as int;
        final end = mark['end'] as int;
        if (start <= a && end > a)
          inherited[mark['key'] as String] = mark['value'];
        mark['start'] = start <= a
            ? start
            : start >= oldEnd
            ? start + shift
            : newEnd;
        mark['end'] = end <= a
            ? end
            : end >= oldEnd
            ? end + shift
            : a;
      }
      marks.removeWhere((m) => (m['end'] as int) <= (m['start'] as int));
      inherited.addAll(typingStyle);
      if (newEnd > a) {
        for (final entry in inherited.entries) {
          marks.add({
            'start': a,
            'end': newEnd,
            'key': entry.key,
            'value': entry.value,
          });
        }
      }
    }
    super.value = next;
  }

  void restore(String text, List<dynamic> styles, int cursor) {
    restoring = true;
    marks = styles.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor.clamp(0, text.length)),
    );
    restoring = false;
  }

  void apply(String key, dynamic setting) {
    if (!selection.isValid || selection.isCollapsed) {
      typingStyle[key] = setting;
    } else {
      marks.add({
        'start': selection.start,
        'end': selection.end,
        'key': key,
        'value': setting,
      });
    }
    notifyListeners();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final points = <int>{0, text.length};
    for (final mark in marks) {
      points.add((mark['start'] as int).clamp(0, text.length));
      points.add((mark['end'] as int).clamp(0, text.length));
    }
    if (withComposing && value.isComposingRangeValid) {
      points.add(value.composing.start);
      points.add(value.composing.end);
    }
    final sorted = points.toList()..sort();
    final spans = <TextSpan>[];
    for (var i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i], end = sorted[i + 1];
      final attributes = <String, dynamic>{};
      for (final mark in marks) {
        if ((mark['start'] as int) <= start && (mark['end'] as int) >= end) {
          attributes[mark['key'] as String] = mark['value'];
        }
      }
      var part = (style ?? const TextStyle()).copyWith(
        fontWeight: attributes['bold'] == true ? FontWeight.bold : null,
        fontStyle: attributes['italic'] == true ? FontStyle.italic : null,
        color: attributes['color'] is int
            ? Color(attributes['color'] as int)
            : null,
        backgroundColor: attributes['highlight'] is int
            ? Color(attributes['highlight'] as int)
            : null,
        fontFamily: attributes['font'] as String?,
        fontSize: (attributes['size'] as num?)?.toDouble(),
      );
      if (withComposing &&
          value.isComposingRangeValid &&
          value.composing.start <= start &&
          value.composing.end >= end) {
        part = part.copyWith(decoration: TextDecoration.underline);
      }
      spans.add(TextSpan(text: text.substring(start, end), style: part));
    }
    return TextSpan(style: style, children: spans);
  }
}

class NotoTable {
  NotoTable(this.id, this.cells);
  final String id;
  List<List<String>> cells;
  int revision = 0;
  factory NotoTable.create(int rows, int columns) => NotoTable(
    DateTime.now().microsecondsSinceEpoch.toString(),
    List.generate(
      rows + 1,
      (r) => List.generate(columns, (c) => r == 0 ? 'Coluna ${c + 1}' : ''),
    ),
  );
  factory NotoTable.fromJson(Map<String, dynamic> json) => NotoTable(
    json['id'] as String,
    (json['cells'] as List)
        .map((row) => (row as List).map((e) => e.toString()).toList())
        .toList(),
  );
  Map<String, dynamic> toJson() => {'id': id, 'cells': cells};
  bool get hasContent =>
      cells.any((row) => row.any((cell) => cell.trim().isNotEmpty));
  String get plainText => cells.map((row) => row.join('\t')).join('\n');
  String get markdown {
    String line(List<String> row) =>
        '| ${row.map((s) => s.replaceAll('|', r'\|').replaceAll('\n', ' ')).join(' | ')} |';
    return [
      line(cells.first),
      line(List.filled(cells.first.length, '---')),
      ...cells.skip(1).map(line),
    ].join('\n');
  }
}

/// Existing Markdown tables are upgraded into editable cells on first open.
({String text, List<NotoTable> tables}) migrateTables(String text) {
  final lines = text.split('\n'), kept = <String>[], tables = <NotoTable>[];
  List<String> cells(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return s
        .split(RegExp(r'(?<!\\)\|'))
        .map((s) => s.trim().replaceAll(r'\|', '|'))
        .toList();
  }

  var code = false;
  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trim().startsWith('```')) code = !code;
    if (!code &&
        i + 1 < lines.length &&
        lines[i].contains('|') &&
        cells(lines[i + 1]).every((s) => RegExp(r'^:?-{3,}:?$').hasMatch(s))) {
      final grid = <List<String>>[cells(lines[i])];
      i++;
      while (i + 1 < lines.length && lines[i + 1].trim().startsWith('|')) {
        final row = cells(lines[++i]);
        while (row.length < grid.first.length) {
          row.add('');
        }
        // Keep extra cells rather than silently dropping imported text.
        if (row.length > grid.first.length) {
          for (final prior in grid) {
            while (prior.length < row.length) {
              prior.add('');
            }
          }
        }
        grid.add(row);
      }
      tables.add(
        NotoTable(
          'import-${DateTime.now().microsecondsSinceEpoch}-${tables.length}',
          grid,
        ),
      );
    } else {
      kept.add(lines[i]);
    }
  }
  return (text: kept.join('\n'), tables: tables);
}

class VisualNoteTable extends StatefulWidget {
  const VisualNoteTable({
    super.key,
    required this.table,
    required this.onChanged,
    required this.onDelete,
    this.fontFamily,
    this.fontSize = 16,
  });
  final NotoTable table;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  final String? fontFamily;
  final double fontSize;
  @override
  State<VisualNoteTable> createState() => _VisualNoteTableState();
}

class _VisualNoteTableState extends State<VisualNoteTable> {
  int row = 0, column = 0;
  Future<bool> confirm(String what) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Apagar $what?'),
          content: const Text(
            'O conteúdo será removido. Você pode desfazer depois.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apagar'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> action(String key) async {
    final t = widget.table;
    row = row.clamp(0, t.cells.length - 1);
    column = column.clamp(0, t.cells.first.length - 1);
    if (key == 'delete') {
      if (!t.hasContent || await confirm('a tabela preenchida')) {
        if (mounted) widget.onDelete();
      }
      return;
    }
    if (key == 'removeRow' &&
        t.cells[row].any((s) => s.trim().isNotEmpty) &&
        !await confirm('a linha ${row + 1}'))
      return;
    if (key == 'removeColumn' &&
        t.cells.any((r) => r[column].trim().isNotEmpty) &&
        !await confirm('a coluna ${column + 1}'))
      return;
    if (!mounted) return;
    setState(() {
      if (key == 'row' && t.cells.length < 101)
        t.cells.insert(row + 1, List.filled(t.cells.first.length, ''));
      if (key == 'column' && t.cells.first.length < 12) {
        for (final r in t.cells) {
          r.insert(column + 1, '');
        }
      }
      if (key == 'removeRow' && t.cells.length > 1) t.cells.removeAt(row);
      if (key == 'removeColumn' && t.cells.first.length > 1) {
        for (final r in t.cells) {
          r.removeAt(column);
        }
      }
      row = row.clamp(0, t.cells.length - 1);
      column = column.clamp(0, t.cells.first.length - 1);
      t.revision++;
    });
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.table, cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.surface,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tabela · ${t.cells.length} × ${t.cells.first.length}',
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Linhas e colunas',
                  onSelected: action,
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'row',
                      child: Text('Adicionar linha abaixo'),
                    ),
                    const PopupMenuItem(
                      value: 'column',
                      child: Text('Adicionar coluna à direita'),
                    ),
                    PopupMenuItem(
                      value: 'removeRow',
                      enabled: t.cells.length > 1,
                      child: const Text('Remover linha selecionada'),
                    ),
                    PopupMenuItem(
                      value: 'removeColumn',
                      enabled: t.cells.first.length > 1,
                      child: const Text('Remover coluna selecionada'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Apagar tabela'),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              'Toque para preencher · deslize para ver as colunas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Table(
                defaultColumnWidth: const FixedColumnWidth(150),
                border: TableBorder.all(color: cs.outlineVariant),
                children: List.generate(
                  t.cells.length,
                  (r) => TableRow(
                    decoration: BoxDecoration(
                      color: r == 0 ? cs.primaryContainer : cs.surface,
                    ),
                    children: List.generate(
                      t.cells[r].length,
                      (c) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        child: TextFormField(
                          key: ValueKey('${t.id}-${t.revision}-$r-$c'),
                          initialValue: t.cells[r][c],
                          minLines: 1,
                          maxLines: null,
                          style: TextStyle(
                            fontFamily: widget.fontFamily,
                            fontSize: widget.fontSize,
                            color: r == 0
                                ? cs.onPrimaryContainer
                                : cs.onSurface,
                            fontWeight: r == 0
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          decoration: InputDecoration(
                            hintText: r == 0 ? 'Cabeçalho' : '…',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                          onTap: () {
                            row = r;
                            column = c;
                          },
                          onChanged: (value) {
                            t.cells[r][c] = value;
                            widget.onChanged();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
