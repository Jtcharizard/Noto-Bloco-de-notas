import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'noto_formatting.dart';

/// Editor de linhas que mistura texto comum e tarefas com caixa de marcar.
///
/// O conteúdo continua salvo como texto simples no [controller]
/// (`- [ ] tarefa` / `- [x] feita`), então nada muda no formato das notas.
class MixedContentEditor extends StatefulWidget {
  const MixedContentEditor({
    super.key,
    required this.controller,
    required this.onChanged,
    this.family,
    this.fontSize = 17,
    this.textColor,
    this.hideDone = false,
    this.onShowDone,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? family;
  final double fontSize;
  final Color? textColor;

  /// Esconde as tarefas já marcadas.
  final bool hideDone;
  final VoidCallback? onShowDone;

  @override
  State<MixedContentEditor> createState() => _MixedContentEditorState();
}

class _MixedLine {
  _MixedLine(String text, {this.task = false, this.checked = false})
    : controller = TextEditingController(text: text);

  final TextEditingController controller;
  final FocusNode focus = FocusNode();
  final Key key = UniqueKey();
  bool task;
  bool checked;

  void dispose() {
    controller.dispose();
    focus.dispose();
  }
}

class _MixedContentEditorState extends State<MixedContentEditor> {
  final List<_MixedLine> lines = [];

  static final RegExp _taskPattern = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');

  @override
  void initState() {
    super.initState();
    lines.addAll(widget.controller.text.split('\n').map(_parse));
    if (lines.isEmpty) lines.add(_MixedLine(''));
  }

  @override
  void dispose() {
    for (final line in lines) {
      line.dispose();
    }
    super.dispose();
  }

  _MixedLine _parse(String raw) {
    final match = _taskPattern.firstMatch(raw);
    if (match == null) return _MixedLine(raw);
    return _MixedLine(
      match.group(2) ?? '',
      task: true,
      checked: match.group(1)!.toLowerCase() == 'x',
    );
  }

  void _sync() {
    widget.controller.text = lines
        .map((line) {
          if (!line.task) return line.controller.text;
          return '- [${line.checked ? 'x' : ' '}] ${line.controller.text}';
        })
        .join('\n');
    widget.onChanged();
  }

  void _focusLater(_MixedLine line) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      line.focus.requestFocus();
      line.controller.selection = TextSelection.collapsed(
        offset: line.controller.text.length,
      );
    });
  }

  void _add({required bool task}) {
    final line = _MixedLine('', task: task);
    setState(() => lines.add(line));
    _sync();
    _focusLater(line);
  }

  /// Enter cria uma nova linha do mesmo tipo, como em qualquer lista de tarefas.
  /// Enter numa tarefa vazia transforma a linha em texto comum.
  void _lineChanged(_MixedLine line, String value) {
    if (!value.contains('\n')) {
      _sync();
      return;
    }
    final parts = value.split('\n');
    final index = lines.indexOf(line);
    if (line.task &&
        parts.length == 2 &&
        parts.first.trim().isEmpty &&
        parts.last.isEmpty) {
      setState(() => line.task = false);
      line.controller.text = '';
      _sync();
      _focusLater(line);
      return;
    }
    // Texto com lista ("1-", "-", "a)"): Enter continua a numeração.
    if (!line.task && parts.length == 2 && parts.last.isEmpty) {
      final prefix = nextListPrefix(parts.first);
      if (prefix != null && prefix.isEmpty) {
        line.controller.text = '';
        _sync();
        _focusLater(line);
        return;
      }
      if (prefix != null) {
        line.controller.text = parts.first;
        final next = _MixedLine(prefix);
        setState(() => lines.insert(index + 1, next));
        _sync();
        _focusLater(next);
        return;
      }
    }
    line.controller.text = parts.first;
    final added = [
      for (final part in parts.skip(1)) _MixedLine(part, task: line.task),
    ];
    setState(() => lines.insertAll(index + 1, added));
    _sync();
    _focusLater(added.last);
  }

  /// Tarefa marcada desce para o fim do seu grupo de tarefas;
  /// desmarcada volta para junto das que faltam fazer.
  void _toggle(_MixedLine line, bool checked) {
    HapticFeedback.selectionClick();
    setState(() {
      line.checked = checked;
      var start = lines.indexOf(line);
      var end = start;
      while (start > 0 && lines[start - 1].task) {
        start--;
      }
      while (end < lines.length - 1 && lines[end + 1].task) {
        end++;
      }
      final block = lines.sublist(start, end + 1);
      final ordered = [
        ...block.where((item) => !item.checked),
        ...block.where((item) => item.checked),
      ];
      lines.replaceRange(start, end + 1, ordered);
    });
    _sync();
  }

  /// Apaga a linha e oferece "Desfazer" por alguns segundos.
  void _removeLine(_MixedLine line) {
    if (lines.length <= 1) return;
    final index = lines.indexOf(line);
    setState(() => lines.remove(line));
    _sync();
    var restored = false;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
      return;
    }
    messenger.hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text(line.task ? 'Tarefa apagada' : 'Linha apagada'),
            action: SnackBarAction(
              label: 'Desfazer',
              onPressed: () {
                if (!mounted) return;
                restored = true;
                setState(
                  () => lines.insert(index.clamp(0, lines.length).toInt(), line),
                );
                _sync();
              },
            ),
          ),
        )
        .closed
        .then((_) {
          if (!restored) line.dispose();
        });
  }

  List<_MixedLine> get _visible => widget.hideDone
      ? lines.where((line) => !(line.task && line.checked)).toList()
      : lines;

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final hidden = lines.length - visible.length;
    return Column(
    children: [
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          buildDefaultDragHandles: false,
          itemCount: visible.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              final moving = visible[oldIndex];
              final anchor = newIndex < visible.length
                  ? visible[newIndex]
                  : null;
              final original = lines.indexOf(moving);
              lines.remove(moving);
              final position = anchor == null
                  ? lines.length
                  : identical(anchor, moving)
                  ? original
                  : lines.indexOf(anchor);
              lines.insert(position, moving);
            });
            _sync();
          },
          itemBuilder: (context, index) {
            final line = visible[index];
            return Row(
              key: line.key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.task)
                  Checkbox(
                    value: line.checked,
                    onChanged: (value) => _toggle(line, value ?? false),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: line.controller,
                    focusNode: line.focus,
                    minLines: 1,
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: line.task ? 'Tarefa' : 'Escreva aqui',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontFamily: widget.family,
                      fontSize: widget.fontSize,
                      color: line.checked
                          ? (widget.textColor ??
                                    Theme.of(context).colorScheme.onSurface)
                                .withValues(alpha: .55)
                          : widget.textColor,
                      decoration: line.checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    onChanged: (value) => _lineChanged(line, value),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções da linha',
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (value) {
                    if (value == 'convert') {
                      setState(() {
                        line.task = !line.task;
                        if (!line.task) line.checked = false;
                      });
                      _sync();
                    } else if (value == 'remove') {
                      _removeLine(line);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'convert',
                      child: ListTile(
                        leading: Icon(
                          line.task
                              ? Icons.notes_rounded
                              : Icons.check_box_outlined,
                        ),
                        title: Text(
                          line.task
                              ? 'Transformar em texto'
                              : 'Transformar em tarefa',
                        ),
                      ),
                    ),
                    if (lines.length > 1)
                      const PopupMenuItem(
                        value: 'remove',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Apagar linha'),
                        ),
                      ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(2, 12, 4, 12),
                    child: Icon(Icons.drag_handle_rounded, size: 20),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      if (hidden > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.onShowDone,
            icon: const Icon(Icons.visibility_outlined, size: 18),
            label: Text(
              hidden == 1
                  ? '1 tarefa concluída escondida · Mostrar'
                  : '$hidden tarefas concluídas escondidas · Mostrar',
            ),
          ),
        ),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _add(task: false),
              icon: const Icon(Icons.notes_rounded),
              label: const Text('Texto'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _add(task: true),
              icon: const Icon(Icons.check_box_outlined),
              label: const Text('Tarefa'),
            ),
          ),
        ],
      ),
    ],
    );
  }
}
