import 'package:flutter/material.dart';

/// Edits only the selected range, leaving the persisted plain-text format intact.
TextEditingValue formatSelection(
  TextEditingValue value, {
  String prefix = '',
  String suffix = '',
  String placeholder = 'texto',
  bool block = false,
  bool eachLine = false,
}) {
  final selection = value.selection;
  final valid = selection.isValid && selection.end <= value.text.length;
  var start = valid ? selection.start : value.text.length;
  var end = valid ? selection.end : value.text.length;
  if (eachLine) {
    start = start == 0 ? 0 : value.text.lastIndexOf('\n', start - 1) + 1;
    if (end > start && value.text[end - 1] == '\n') end--;
    final newline = value.text.indexOf('\n', end);
    end = newline < 0 ? value.text.length : newline;
  }
  final selected = value.text.substring(start, end);
  final content = selected.isEmpty ? placeholder : selected;
  final leading = block && start > 0
      ? (value.text.substring(0, start).endsWith('\n\n')
            ? ''
            : value.text[start - 1] == '\n'
            ? '\n'
            : '\n\n')
      : '';
  final trailing = block && end < value.text.length
      ? (value.text.substring(end).startsWith('\n\n')
            ? ''
            : value.text[end] == '\n'
            ? '\n'
            : '\n\n')
      : '';
  final formatted = eachLine
      ? content.split('\n').map((line) => '$prefix$line').join('\n')
      : '$prefix$content$suffix';
  final replacement = '$leading$formatted$trailing';
  final offset = start + leading.length + (eachLine ? 0 : prefix.length);
  return TextEditingValue(
    text: value.text.replaceRange(start, end, replacement),
    selection: TextSelection(
      baseOffset: offset,
      extentOffset: offset + (eachLine ? formatted.length : content.length),
    ),
  );
}

String markdownTable(int rows, int columns) {
  assert(rows >= 1 && rows <= 20 && columns >= 1 && columns <= 6);
  String line(List<String> cells) => '| ${cells.join(' | ')} |';
  return [
    line(List.generate(columns, (i) => 'Coluna ${i + 1}')),
    line(List.filled(columns, '---')),
    ...List.generate(rows, (_) => line(List.filled(columns, '   '))),
  ].join('\n');
}

class FormattingToolbar extends StatelessWidget {
  const FormattingToolbar({
    super.key,
    required this.onFormat,
    required this.onTable,
    required this.onPreview,
  });

  final ValueChanged<String> onFormat;
  final VoidCallback onTable;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    Widget button(String label, IconData icon, VoidCallback action) =>
        IconButton(
          tooltip: label,
          onPressed: action,
          icon: Icon(icon, size: 21),
        );
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            button('Inserir tabela', Icons.table_chart_outlined, onTable),
            button('Negrito', Icons.format_bold, () => onFormat('bold')),
            button('Itálico', Icons.format_italic, () => onFormat('italic')),
            button('Título', Icons.title, () => onFormat('heading')),
            button('Lista', Icons.format_list_bulleted, () => onFormat('list')),
            button('Checklist', Icons.checklist, () => onFormat('checklist')),
            button('Citação', Icons.format_quote, () => onFormat('quote')),
            button('Bloco de código', Icons.code, () => onFormat('code')),
            button(
              'Separador',
              Icons.horizontal_rule,
              () => onFormat('divider'),
            ),
            button('Ver formatação', Icons.visibility_outlined, onPreview),
          ],
        ),
      ),
    );
  }
}
