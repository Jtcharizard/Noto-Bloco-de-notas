import 'package:flutter/material.dart';

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
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final String? family;
  final double fontSize;
  final Color? textColor;

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
    line.controller.text = parts.first;
    final added = [
      for (final part in parts.skip(1)) _MixedLine(part, task: line.task),
    ];
    setState(() => lines.insertAll(index + 1, added));
    _sync();
    _focusLater(added.last);
  }

  void _removeLine(_MixedLine line) {
    if (lines.length <= 1) return;
    setState(() => lines.remove(line));
    _sync();
    WidgetsBinding.instance.addPostFrameCallback((_) => line.dispose());
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          buildDefaultDragHandles: false,
          itemCount: lines.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              lines.insert(newIndex, lines.removeAt(oldIndex));
            });
            _sync();
          },
          itemBuilder: (context, index) {
            final line = lines[index];
            return Row(
              key: line.key,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (line.task)
                  Checkbox(
                    value: line.checked,
                    onChanged: (value) {
                      setState(() => line.checked = value ?? false);
                      _sync();
                    },
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
