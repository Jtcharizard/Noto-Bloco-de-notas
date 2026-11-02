import 'package:flutter/material.dart';

import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_store.dart';

final RegExp _task = RegExp(r'^(\s*(?:[-*]\s*)?)\[([ xX])\]\s?(.*)$');

/// Tarefas não feitas de um texto, no formato da lista ("- [ ] ..."),
/// mantendo o recuo das subtarefas. Tarefas feitas e vazias ficam de fora.
List<String> pendingTaskLines(String body) {
  final lines = <String>[];
  for (final line in body.split('\n')) {
    final match = _task.firstMatch(line);
    if (match == null || match.group(2) != ' ') continue;
    final text = (match.group(3) ?? '').trim();
    if (text.isEmpty) continue;
    final spaces = RegExp(r'^\s*')
        .stringMatch(line)!
        .replaceAll('\t', '  ')
        .length;
    final indent = (spaces ~/ 2).clamp(0, 3).toInt();
    lines.add('${'  ' * indent}- [ ] $text');
  }
  return lines;
}

/// Tarefas que faltaram na última nota do dia antes de [todayKey]
/// (chave de [dayKey]). Só copia: a nota antiga não muda. Se a última nota
/// do dia está na lixeira ou no cofre, nada vem (e nunca de um dia mais
/// antigo, que traria tarefas já resolvidas). Sem nota anterior, lista vazia.
List<String> missedTasksForToday(Iterable<Note> notes, String todayKey) {
  Note? last;
  String? lastKey;
  for (final note in notes) {
    final key = note.editor['daily'];
    if (key is! String) continue;
    if (key.compareTo(todayKey) >= 0) continue;
    if (lastKey == null || key.compareTo(lastKey) > 0) {
      last = note;
      lastKey = key;
    }
  }
  if (last == null || last.deletedAt != null || last.locked) return const [];
  return pendingTaskLines(last.body);
}

/// Aviso depois de trazer as tarefas para a nota de hoje.
String missedTasksMessage(int count) => count == 1
    ? '1 tarefa que faltou veio para hoje'
    : '$count tarefas que faltaram vieram para hoje';

class _TaskItem {
  const _TaskItem(this.note, this.line, this.text, this.done);
  final Note note;
  final int line;
  final String text;
  final bool done;
}

/// Todas as tarefas de todas as notas num lugar só, para marcar direto.
class AllTasksPage extends StatefulWidget {
  const AllTasksPage({super.key, required this.store, required this.onOpen});

  final AppStore store;
  final Future<void> Function(Note note) onOpen;

  @override
  State<AllTasksPage> createState() => _AllTasksPageState();
}

class _AllTasksPageState extends State<AllTasksPage> {
  bool showDone = false;

  List<_TaskItem> _items() {
    final notes =
        widget.store.notes
            .where((n) => n.deletedAt == null && !n.archived && !n.locked)
            .toList()
          ..sort((a, b) {
            if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
            final ad = a.dueAt, bd = b.dueAt;
            if (ad != null && bd != null) return ad.compareTo(bd);
            if (ad != null) return -1;
            if (bd != null) return 1;
            return b.updatedAt.compareTo(a.updatedAt);
          });
    return [
      for (final note in notes)
        for (final (index, line) in note.body.split('\n').indexed)
          if (_task.firstMatch(line) case final match?)
            if ((match.group(3) ?? '').trim().isNotEmpty)
              if (showDone || match.group(2) == ' ')
                _TaskItem(
                  note,
                  index,
                  match.group(3)!.trim(),
                  match.group(2) != ' ',
                ),
    ];
  }

  void _toggle(_TaskItem item) {
    final lines = item.note.body.split('\n');
    if (item.line >= lines.length) return;
    final match = _task.firstMatch(lines[item.line]);
    if (match == null) return;
    NotoHaptics.selection();
    lines[item.line] = '${match.group(1)}[${item.done ? ' ' : 'x'}] ${match.group(3)}';
    item.note
      ..body = lines.join('\n')
      ..updatedAt = DateTime.now();
    widget.store.save();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        content: Text(item.done ? 'Tarefa reaberta' : 'Feito: ${item.text}'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            final again = item.note.body.split('\n');
            if (item.line >= again.length) return;
            final m = _task.firstMatch(again[item.line]);
            if (m == null) return;
            again[item.line] = '${m.group(1)}[${item.done ? 'x' : ' '}] ${m.group(3)}';
            item.note.body = again.join('\n');
            widget.store.save();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, __) {
      final items = _items();
      final cs = Theme.of(context).colorScheme;
      // Ajustes > Tarefas feitas: 0 riscadas e apagadas, 1 só apagadas,
      // 2 só riscadas.
      final doneStyle = widget.store.doneStyle;
      final strike = doneStyle != 1;
      final fade = doneStyle != 2;
      final rows = <Widget>[];
      Note? current;
      for (final item in items) {
        if (!identical(item.note, current)) {
          current = item.note;
          final note = item.note;
          final pending = countPendingTasks(note.body);
          rows.add(
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
              title: Text(
                displayTitle(note),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text(
                [
                  note.folder,
                  pending == 1 ? '1 a fazer' : '$pending a fazer',
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => widget.onOpen(note),
            ),
          );
        }
        rows.add(
          KeyedSubtree(
            key: ValueKey('${item.note.id}-${item.line}-${item.text}'),
            child: CheckboxListTile(
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: item.done,
            onChanged: (_) => _toggle(item),
            title: Text(
              item.text,
              style: TextStyle(
                fontSize: 15,
                decoration: item.done && strike
                    ? TextDecoration.lineThrough
                    : null,
                color: item.done && fade
                    ? cs.onSurface.withValues(alpha: .5)
                    : null,
              ),
            ),
          ),
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('Todas as tarefas'),
          actions: [
            TextButton(
              onPressed: () => setState(() => showDone = !showDone),
              child: Text(showDone ? 'Esconder feitas' : 'Mostrar feitas'),
            ),
          ],
        ),
        body: rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    showDone
                        ? 'Nenhuma tarefa nas suas notas.'
                        : 'Nada pendente. Tudo feito! 🎉',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 40),
                children: rows,
              ),
      );
    },
  );
}
