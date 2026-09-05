import 'noto_models.dart';

class NoteRevision {
  const NoteRevision({
    required this.title,
    required this.body,
    required this.savedAt,
  });

  final String title;
  final String body;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'savedAt': savedAt.toIso8601String(),
      };

  factory NoteRevision.fromJson(Map<String, dynamic> json) => NoteRevision(
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ?? DateTime.now(),
      );
}

enum PulseKind { checklist, stale, folder, links, momentum }

class PulseInsight {
  const PulseInsight({
    required this.kind,
    required this.title,
    required this.detail,
  });

  final PulseKind kind;
  final String title;
  final String detail;
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
    if (extractWikiLinks(note.body).any((link) => link.toLowerCase() == wanted)) {
      result.add(note);
    }
  }
  result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return result;
}

List<PulseInsight> buildPulseInsights(List<Note> allNotes, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final notes = allNotes.where((n) => n.deletedAt == null && !n.archived).toList();
  if (notes.isEmpty) {
    return const [
      PulseInsight(
        kind: PulseKind.momentum,
        title: 'O Pulse acorda contigo',
        detail: 'Cria algumas notas e eu começo a apontar padrões úteis por aqui.',
      ),
    ];
  }

  final insights = <PulseInsight>[];

  var unfinishedLists = 0;
  var pendingItems = 0;
  for (final note in notes.where((n) => n.checklist)) {
    final lines = note.body.split('\n').map((e) => e.trim());
    final pending = lines.where((line) => line.startsWith('[ ]')).length;
    if (pending > 0) {
      unfinishedLists++;
      pendingItems += pending;
    }
  }
  if (unfinishedLists > 0) {
    insights.add(PulseInsight(
      kind: PulseKind.checklist,
      title: '$pendingItems ${pendingItems == 1 ? 'tarefa pendente' : 'tarefas pendentes'}',
      detail: 'Espalhadas em $unfinishedLists ${unfinishedLists == 1 ? 'checklist' : 'checklists'}.',
    ));
  }

  final stale = notes.where((note) => today.difference(note.updatedAt).inDays >= 45).length;
  if (stale > 0) {
    insights.add(PulseInsight(
      kind: PulseKind.stale,
      title: '$stale ${stale == 1 ? 'nota esquecida' : 'notas esquecidas'}',
      detail: 'Sem edição há pelo menos 45 dias. Talvez seja hora de arquivar ou revisitar.',
    ));
  }

  final folderCounts = <String, int>{};
  for (final note in notes) {
    final value = note.folder.trim().isEmpty ? 'Geral' : note.folder.trim();
    folderCounts[value] = (folderCounts[value] ?? 0) + 1;
  }
  final folders = folderCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  if (folders.isNotEmpty && folders.first.value >= 2) {
    insights.add(PulseInsight(
      kind: PulseKind.folder,
      title: '${folders.first.key} domina teu Noto',
      detail: '${folders.first.value} notas estão nessa pasta${folders.first.key.contains('/') ? ' ou subpasta' : ''}.',
    ));
  }

  final linked = notes.where((note) => extractWikiLinks(note.body).isNotEmpty).length;
  if (linked > 0) {
    insights.add(PulseInsight(
      kind: PulseKind.links,
      title: '$linked ${linked == 1 ? 'nota conectada' : 'notas conectadas'}',
      detail: 'Tu já está criando uma rede com links no formato [[Nome da nota]].',
    ));
  }

  final recent = notes.where((note) => today.difference(note.updatedAt).inDays < 7).length;
  if (recent >= 3) {
    insights.add(PulseInsight(
      kind: PulseKind.momentum,
      title: 'Semana movimentada',
      detail: '$recent notas receberam atenção nos últimos 7 dias.',
    ));
  }

  if (insights.isEmpty) {
    insights.add(PulseInsight(
      kind: PulseKind.momentum,
      title: 'Tudo sob controle',
      detail: '${notes.length} ${notes.length == 1 ? 'nota ativa' : 'notas ativas'} e nenhum padrão chato forte por enquanto.',
    ));
  }
  return insights.take(4).toList();
}
