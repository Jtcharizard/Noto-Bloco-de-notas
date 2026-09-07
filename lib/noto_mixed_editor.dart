import 'package:flutter/material.dart';

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
  _MixedLine(this.text, {this.task = false, this.checked = false});
  String text;
  bool task;
  bool checked;
}

class _MixedContentEditorState extends State<MixedContentEditor> {
  late final List<_MixedLine> lines;
  int revision = 0;

  @override
  void initState() {
    super.initState();
    lines = widget.controller.text.split('\n').map(_parse).toList();
    if (lines.isEmpty) lines.add(_MixedLine(''));
  }

  _MixedLine _parse(String raw) {
    final match = RegExp(r'^\s*(?:-\s*)?\[([ xX])\]\s?(.*)$').firstMatch(raw);
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
          if (!line.task) return line.text;
          return '- [${line.checked ? 'x' : ' '}] ${line.text}';
        })
        .join('\n');
    widget.onChanged();
  }

  void _add({required bool task}) {
    setState(() {
      lines.add(_MixedLine('', task: task));
      revision++;
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          itemCount: lines.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              lines.insert(newIndex, lines.removeAt(oldIndex));
              revision++;
            });
            _sync();
          },
          itemBuilder: (context, index) {
            final line = lines[index];
            return Row(
              key: ValueKey('${identityHashCode(line)}-$revision'),
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
                  child: TextFormField(
                    initialValue: line.text,
                    minLines: 1,
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: line.task ? 'Tarefa' : 'Texto',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: TextStyle(
                      fontFamily: widget.family,
                      fontSize: widget.fontSize,
                      color: widget.textColor,
                      decoration: line.checked
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    onChanged: (value) {
                      line.text = value;
                      _sync();
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opções da linha',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'convert') {
                      setState(() => line.task = !line.task);
                    } else if (value == 'remove' && lines.length > 1) {
                      setState(() => lines.removeAt(index));
                    }
                    _sync();
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
                          title: Text('Remover linha'),
                        ),
                      ),
                  ],
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(4, 12, 4, 12),
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
