import 'noto_models.dart';

/// Texto curto do prazo: "vence hoje", "vence amanhã", "venceu há 2 dias"...
String dueCountdown(DateTime due, DateTime now) {
  final a = DateTime.utc(due.year, due.month, due.day);
  final b = DateTime.utc(now.year, now.month, now.day);
  final days = a.difference(b).inDays;
  if (days == 0) return 'vence hoje';
  if (days == 1) return 'vence amanhã';
  if (days > 1 && days < 7) return 'vence em $days dias';
  if (days == -1) return 'venceu ontem';
  if (days < -1) return 'venceu há ${-days} dias';
  final dd = due.day.toString().padLeft(2, '0');
  final mm = due.month.toString().padLeft(2, '0');
  return 'até $dd/$mm';
}

const _weekdays = {
  'segunda': DateTime.monday,
  'terca': DateTime.tuesday,
  'quarta': DateTime.wednesday,
  'quinta': DateTime.thursday,
  'sexta': DateTime.friday,
  'sabado': DateTime.saturday,
  'domingo': DateTime.sunday,
};

/// Entende lembretes escritos do jeito que a gente fala:
/// "amanhã às 9", "sexta 18h", "em 2 horas", "hoje à noite", "15/11 14:30".
/// Devolve null quando não reconhece nada.
DateTime? parseReminderText(String input, DateTime now) {
  final t = foldForSearch(input).replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  final base = DateTime(now.year, now.month, now.day, now.hour, now.minute);

  if (RegExp(r'\b(?:em|daqui a)\s+meia\s+hora\b').hasMatch(t)) {
    return base.add(const Duration(minutes: 30));
  }
  final rel = RegExp(
    r'\b(?:em|daqui a|daqui)\s+(\d+|um|uma|dois|duas|tres)\s*(minutos?|min|m|horas?|h|dias?|semanas?)\b',
  ).firstMatch(t);
  if (rel != null) {
    final n = switch (rel.group(1)) {
      'um' || 'uma' => 1,
      'dois' || 'duas' => 2,
      'tres' => 3,
      final v => int.parse(v!),
    };
    final unit = rel.group(2)!;
    final duration = unit.startsWith('m')
        ? Duration(minutes: n)
        : unit.startsWith('h')
        ? Duration(hours: n)
        : unit.startsWith('s')
        ? Duration(days: 7 * n)
        : Duration(days: n);
    if (n <= 0) return null;
    return base.add(duration);
  }

  final today = DateTime(now.year, now.month, now.day);
  DateTime? day;
  if (t.contains('depois de amanha')) {
    day = today.add(const Duration(days: 2));
  } else if (RegExp(r'\bamanha\b').hasMatch(t)) {
    day = today.add(const Duration(days: 1));
  } else if (RegExp(r'\bhoje\b').hasMatch(t)) {
    day = today;
  } else if (RegExp(r'\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b').firstMatch(t)
      case final m?) {
    final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
    var y = m.group(3) == null ? now.year : int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    var candidate = DateTime(y, mo, d);
    if (candidate.month != mo) return null;
    if (m.group(3) == null && candidate.isBefore(today)) {
      candidate = DateTime(y + 1, mo, d);
    }
    day = candidate;
  } else if (RegExp(r'\bdia (\d{1,2})\b').firstMatch(t) case final m?) {
    final d = int.parse(m.group(1)!);
    if (d < 1 || d > 31) return null;
    var candidate = DateTime(now.year, now.month, d);
    if (candidate.month != now.month || candidate.isBefore(today)) {
      candidate = DateTime(now.year, now.month + 1, d);
    }
    day = candidate;
  } else {
    for (final entry in _weekdays.entries) {
      if (RegExp('\\b${entry.key}\\b').hasMatch(t)) {
        var ahead = (entry.value - now.weekday) % 7;
        if (ahead == 0) ahead = 7;
        day = today.add(Duration(days: ahead));
        break;
      }
    }
  }

  int? hour;
  var minute = 0;
  if (RegExp(r'\bmeio[ -]dia\b').hasMatch(t)) {
    hour = 12;
  } else if (RegExp(r'\bmeia[ -]noite\b').hasMatch(t)) {
    hour = 0;
  } else if (RegExp(r'\b(\d{1,2})\s*(?:h|:)\s*(\d{2})?(?:min)?\b').firstMatch(t)
      case final m?) {
    hour = int.parse(m.group(1)!);
    minute = int.tryParse(m.group(2) ?? '') ?? 0;
  } else if (RegExp(r'\b(?:as|a) (\d{1,2})\b').firstMatch(t) case final m?) {
    hour = int.parse(m.group(1)!);
  }
  if (hour != null && (hour > 23 || minute > 59)) return null;

  final night = RegExp(r'\b(?:noite)\b').hasMatch(t);
  final afternoon = RegExp(r'\b(?:tarde)\b').hasMatch(t);
  final morning = RegExp(r'\b(?:manha|cedo)\b').hasMatch(t);
  if (hour == null) {
    if (night) {
      hour = 20;
    } else if (afternoon) {
      hour = 15;
    } else if (morning) {
      hour = 9;
    }
  } else if ((night || afternoon) && hour < 12) {
    hour += 12;
  }

  if (day == null && hour == null) return null;
  if (day == null) {
    var candidate = DateTime(today.year, today.month, today.day, hour!, minute);
    if (!candidate.isAfter(now)) candidate = candidate.add(const Duration(days: 1));
    return candidate;
  }
  return DateTime(day.year, day.month, day.day, hour ?? 9, minute);
}

/// "2026-10-22": chave do dia, para saber se a lista já foi desmarcada hoje.
String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

/// Desmarca todas as tarefas do texto.
String uncheckAllTasks(String body) => body.replaceAllMapped(
  RegExp(r'^(\s*(?:[-*]\s*)?)\[[xX]\]', multiLine: true),
  (m) => '${m.group(1)}[ ]',
);

/// Listas marcadas como "desmarcar todo dia" voltam desmarcadas quando o dia
/// vira. Devolve true se alguma nota mudou.
bool applyDailyResets(List<Note> notes, DateTime now) {
  final today = dayKey(now);
  var changed = false;
  for (final note in notes) {
    if (note.editor['resetDaily'] != true || note.deletedAt != null) continue;
    if (note.editor['lastReset'] == today) continue;
    final body = uncheckAllTasks(note.body);
    note.editor = {...note.editor, 'lastReset': today};
    if (body != note.body) note.body = body;
    changed = true;
  }
  return changed;
}

/// Link, e-mail ou telefone encontrado no texto da nota.
class NoteLink {
  const NoteLink(this.kind, this.text, this.uri);

  /// 'web', 'email' ou 'phone'.
  final String kind;
  final String text;
  final Uri uri;
}

final RegExp _webLink = RegExp(
  r'''(?:https?://|www\.)[^\s<>"'()\[\]]+''',
  caseSensitive: false,
);
final RegExp _emailLink = RegExp(
  r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+',
);
final RegExp _phoneLink = RegExp(
  r'(?<![\w/.])(?:\+?55\s?)?(?:\(?\d{2}\)?\s?)?9?\d{4}[-\s]?\d{4}(?![\w/])',
);

/// Acha links, e-mails e telefones na nota, sem repetir.
List<NoteLink> extractLinks(String body) {
  final found = <NoteLink>[];
  final seen = <String>{};
  final taken = <(int, int)>[];
  bool overlaps(Match m) =>
      taken.any((r) => m.start < r.$2 && m.end > r.$1);
  void add(NoteLink link, Match m) {
    taken.add((m.start, m.end));
    if (seen.add('${link.kind}:${link.uri}')) found.add(link);
  }

  for (final m in _webLink.allMatches(body)) {
    var text = m.group(0)!.replaceFirst(RegExp(r'[.,;:!?]+$'), '');
    final uri = Uri.tryParse(
      text.toLowerCase().startsWith('www.') ? 'https://$text' : text,
    );
    if (uri != null && uri.host.isNotEmpty) add(NoteLink('web', text, uri), m);
  }
  for (final m in _emailLink.allMatches(body)) {
    if (overlaps(m)) continue;
    final text = m.group(0)!.replaceFirst(RegExp(r'[.]+$'), '');
    add(NoteLink('email', text, Uri(scheme: 'mailto', path: text)), m);
  }
  for (final m in _phoneLink.allMatches(body)) {
    if (overlaps(m)) continue;
    final text = m.group(0)!.trim();
    final digits = text.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.replaceAll('+', '').length < 8) continue;
    add(NoteLink('phone', text, Uri(scheme: 'tel', path: digits)), m);
  }
  return found;
}

/// Seção da nota: linha que começa com # (criada pelo "Título").
class NoteSection {
  const NoteSection(this.title, this.level, this.offset);
  final String title;
  final int level;

  /// Posição do fim da linha do título no texto.
  final int offset;
}

List<NoteSection> extractSections(String body) {
  final sections = <NoteSection>[];
  var position = 0;
  for (final line in body.split('\n')) {
    final m = RegExp(r'^(#{1,3})\s+(.+)$').firstMatch(line);
    if (m != null) {
      sections.add(
        NoteSection(m.group(2)!.trim(), m.group(1)!.length, position + line.length),
      );
    }
    position += line.length + 1;
  }
  return sections;
}

/// Tira todas as linhas de tarefa e devolve o que sobrar do texto.
String removeTaskLines(String body) => body
    .split('\n')
    .where((line) => !RegExp(r'^\s*(?:[-*]\s*)?\[[ xX]\]').hasMatch(line))
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();
