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

/// Soma dos valores em reais escritos na nota.
class MoneySummary {
  const MoneySummary(this.total, this.pending, this.count, this.hasTasks);

  /// Soma de tudo.
  final double total;

  /// Soma só das tarefas que ainda não foram marcadas.
  final double pending;

  /// Quantos valores foram encontrados.
  final int count;
  final bool hasTasks;

  double get done => total - pending;
}

final RegExp _money = RegExp(
  r'R\$\s*(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?',
  caseSensitive: false,
);
final RegExp _taskLine = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]');

MoneySummary moneySummary(String body) {
  var total = 0.0, pending = 0.0;
  var count = 0;
  var hasTasks = false;
  for (final line in body.split('\n')) {
    final task = _taskLine.firstMatch(line);
    var lineSum = 0.0;
    for (final m in _money.allMatches(line)) {
      final reais = int.parse(m.group(1)!.replaceAll('.', ''));
      final centsText = m.group(2);
      final cents = centsText == null
          ? 0
          : int.parse(centsText.length == 1 ? '${centsText}0' : centsText);
      lineSum += reais + cents / 100;
      count++;
    }
    if (lineSum == 0) continue;
    total += lineSum;
    if (task != null) {
      hasTasks = true;
      if (task.group(1) == ' ') pending += lineSum;
    }
  }
  return MoneySummary(total, pending, count, hasTasks);
}

/// 1234.5 -> "R$ 1.234,50"
String formatBRL(double value) {
  final cents = (value * 100).round().abs();
  final reais = (cents ~/ 100).toString();
  final buffer = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
    buffer.write(reais[i]);
  }
  return 'R\$ ${value < 0 ? '-' : ''}$buffer,${(cents % 100).toString().padLeft(2, '0')}';
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
