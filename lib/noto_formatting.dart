import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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


/// Marcadores de lista reconhecidos: "- [ ]", "-", "*", "•", "1.", "1)", "1-",
/// "1 -", "1–" e letras "a)" / "a.". Precisa de espaço depois do marcador.
final RegExp _listLine = RegExp(
  r'^(\s*)(- \[[ xX]\]|[-*•]|\d+\s?[.)\-–]|[a-zA-Z][.)])\s(.*)$',
);

/// Prefixo da próxima linha de uma lista.
/// Devolve null se [line] não é item de lista, e '' se é um item vazio
/// (Enter num item vazio encerra a lista).
String? nextListPrefix(String line) {
  final match = _listLine.firstMatch(line);
  if (match == null) return null;
  final indent = match.group(1)!;
  final marker = match.group(2)!;
  if (match.group(3)!.trim().isEmpty) return '';
  String next;
  final number = RegExp(r'^(\d+)(.*)$').firstMatch(marker);
  if (marker.startsWith('- [')) {
    next = '- [ ]';
  } else if (number != null) {
    next = '${int.parse(number.group(1)!) + 1}${number.group(2)}';
  } else if (RegExp(r'^[a-yA-Y][.)]$').hasMatch(marker)) {
    next = '${String.fromCharCode(marker.codeUnitAt(0) + 1)}${marker[1]}';
  } else {
    next = marker;
  }
  return '$indent$next ';
}

/// Continua listas ao apertar Enter. Enter num item vazio encerra a lista.
TextEditingValue continueList(TextEditingValue oldValue, TextEditingValue newValue) {
  final selection = newValue.selection;
  if (!selection.isValid || !selection.isCollapsed) return newValue;
  if (newValue.text.length != oldValue.text.length + 1) return newValue;
  final cursor = selection.baseOffset;
  if (cursor < 1 || newValue.text[cursor - 1] != '\n') return newValue;
  if (oldValue.text != newValue.text.replaceRange(cursor - 1, cursor, '')) {
    return newValue;
  }
  final lineStart = cursor - 1 == 0
      ? 0
      : newValue.text.lastIndexOf('\n', cursor - 2) + 1;
  final prefix = nextListPrefix(newValue.text.substring(lineStart, cursor - 1));
  if (prefix == null) return newValue;
  if (prefix.isEmpty) {
    // Item vazio + Enter: tira o marcador e não cria outra linha.
    return TextEditingValue(
      text: newValue.text.replaceRange(lineStart, cursor, ''),
      selection: TextSelection.collapsed(offset: lineStart),
    );
  }
  return TextEditingValue(
    text: newValue.text.replaceRange(cursor, cursor, prefix),
    selection: TextSelection.collapsed(offset: cursor + prefix.length),
  );
}

/// Formatter do campo de texto que aplica [continueList].
class ListContinuationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => continueList(oldValue, newValue);
}
