import 'noto_models.dart';

class NoteRevision {
  const NoteRevision({
    required this.title,
    required this.body,
    required this.savedAt,
    this.editor = const {},
  });

  final String title;
  final String body;
  final DateTime savedAt;
  final Map<String, dynamic> editor;

  Map<String, dynamic> toJson() => {
    'title': title,
    'body': body,
    'savedAt': savedAt.toIso8601String(),
    'editor': editor,
  };

  factory NoteRevision.fromJson(Map<String, dynamic> json) => NoteRevision(
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    editor: Map<String, dynamic>.from(json['editor'] ?? const {}),
    savedAt:
        DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
  );
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.touched,
    required this.remindersToday,
    required this.pendingTasks,
  });

  final int touched;
  final int remindersToday;
  final int pendingTasks;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Linha de tarefa nos dois formatos que o Noto já salvou: `[ ] item` e `- [ ] item`.
final RegExp _taskLine = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');

bool hasTaskLines(String body) =>
    body.split('\n').any((line) => _taskLine.hasMatch(line));

int countPendingTasks(String body) => body
    .split('\n')
    .where((line) => _taskLine.firstMatch(line)?.group(1) == ' ')
    .length;

int countDoneTasks(String body) => body
    .split('\n')
    .where((line) {
      final mark = _taskLine.firstMatch(line)?.group(1);
      return mark == 'x' || mark == 'X';
    })
    .length;

/// Texto corrido para cards, widget e notificações: troca marcações por símbolos.
String readablePreview(String body) => body
    .split('\n')
    .map((line) {
      final task = _taskLine.firstMatch(line);
      if (task != null) {
        final done = task.group(1)!.toLowerCase() == 'x';
        return '${done ? '☑' : '☐'} ${task.group(2) ?? ''}'.trim();
      }
      return line
          .replaceFirst(RegExp(r'^\s*#{1,6}\s+'), '')
          .replaceFirst(RegExp(r'^\s*>\s?'), '')
          .replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ');
    })
    .join('\n')
    .replaceAll('**', '')
    .trim();

/// Se o lembrete toca nesse dia (respeitando a repetição).
bool reminderOccursOn(Note note, DateTime day) {
  final at = note.reminderAt;
  if (at == null) return false;
  final date = DateTime(day.year, day.month, day.day);
  final start = DateTime(at.year, at.month, at.day);
  if (date.isBefore(start)) return false;
  return switch (note.reminderRepeat) {
    1 => true,
    2 => day.weekday <= DateTime.friday,
    3 => day.weekday == at.weekday,
    // Todo mês: no mesmo dia; em meses mais curtos, no último dia do mês.
    4 => day.day ==
        (at.day <= DateTime(day.year, day.month + 1, 0).day
            ? at.day
            : DateTime(day.year, day.month + 1, 0).day),
    _ => date == start,
  };
}

/// Título para mostrar: o próprio título ou, se estiver vazio,
/// a primeira linha do texto (como fazem outros apps de notas).
String displayTitle(Note note) {
  final title = note.title.trim();
  if (title.isNotEmpty) return title;
  for (final line in readablePreview(note.body).split('\n')) {
    final clean = line.replaceFirst(RegExp(r'^[☐☑•]\s*'), '').trim();
    if (clean.isEmpty) continue;
    return clean.length <= 60 ? clean : '${clean.substring(0, 57)}…';
  }
  return 'Sem título';
}

TodaySnapshot buildTodaySnapshot(List<Note> allNotes, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final notes = allNotes
      .where((n) => n.deletedAt == null && !n.archived && !n.locked)
      .toList();
  var touched = 0;
  var remindersToday = 0;
  var pendingTasks = 0;

  for (final note in notes) {
    if (_sameDay(note.updatedAt, today)) touched++;
    if (reminderOccursOn(note, today)) remindersToday++;
    pendingTasks += countPendingTasks(note.body);
  }

  return TodaySnapshot(
    touched: touched,
    remindersToday: remindersToday,
    pendingTasks: pendingTasks,
  );
}

List<String> extractWikiLinks(String body) {
  final seen = <String>{};
  final result = <String>[];
  final expression = RegExp(r'\[\[([^\[\]]+)\]\]');
  for (final match in expression.allMatches(body)) {
    final value = match.group(1)?.trim() ?? '';
    if (value.isEmpty) continue;
    final key = value.toLowerCase();
    if (seen.add(key)) result.add(value);
  }
  return result;
}

Note? noteByTitle(List<Note> notes, String title) {
  final wanted = title.trim().toLowerCase();
  if (wanted.isEmpty) return null;
  for (final note in notes) {
    if (note.deletedAt != null) continue;
    if (note.title.trim().toLowerCase() == wanted) return note;
  }
  return null;
}

List<Note> backlinksFor(Note target, List<Note> notes) {
  final wanted = target.title.trim().toLowerCase();
  if (wanted.isEmpty) return const [];
  final result = <Note>[];
  for (final note in notes) {
    if (identical(note, target) || note.deletedAt != null) continue;
    if (extractWikiLinks(note.body)
        .any((link) => link.toLowerCase() == wanted)) {
      result.add(note);
    }
  }
  result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return result;
}
