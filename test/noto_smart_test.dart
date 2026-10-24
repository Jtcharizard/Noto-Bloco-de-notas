import 'package:flutter_test/flutter_test.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_smart.dart';

void main() {
  // Quarta-feira, 21/10/2026, 14:05.
  final now = DateTime(2026, 10, 21, 14, 5);

  group('lembrete escrito', () {
    test('amanhã às 9', () {
      expect(parseReminderText('amanhã às 9', now), DateTime(2026, 10, 22, 9));
      expect(parseReminderText('Amanha 9h30', now), DateTime(2026, 10, 22, 9, 30));
    });
    test('dia da semana', () {
      expect(parseReminderText('sexta 18h', now), DateTime(2026, 10, 23, 18));
      expect(parseReminderText('quarta-feira', now), DateTime(2026, 10, 28, 9));
      expect(parseReminderText('sábado de manhã', now), DateTime(2026, 10, 24, 9));
    });
    test('relativo', () {
      expect(parseReminderText('em 2 horas', now), DateTime(2026, 10, 21, 16, 5));
      expect(parseReminderText('daqui a 10 min', now), DateTime(2026, 10, 21, 14, 15));
      expect(parseReminderText('em meia hora', now), DateTime(2026, 10, 21, 14, 35));
      expect(parseReminderText('em 3 dias', now), DateTime(2026, 10, 24, 14, 5));
    });
    test('períodos do dia', () {
      expect(parseReminderText('hoje à noite', now), DateTime(2026, 10, 21, 20));
      expect(parseReminderText('hoje às 7 da noite', now), DateTime(2026, 10, 21, 19));
      expect(parseReminderText('amanhã à tarde', now), DateTime(2026, 10, 22, 15));
      expect(parseReminderText('meio-dia', now), DateTime(2026, 10, 22, 12));
    });
    test('só a hora: hoje ou amanhã', () {
      expect(parseReminderText('18:30', now), DateTime(2026, 10, 21, 18, 30));
      expect(parseReminderText('às 8', now), DateTime(2026, 10, 22, 8));
    });
    test('datas', () {
      expect(parseReminderText('15/11 14:30', now), DateTime(2026, 11, 15, 14, 30));
      expect(parseReminderText('03/01', now), DateTime(2027, 1, 3, 9));
      expect(parseReminderText('dia 5', now), DateTime(2026, 11, 5, 9));
      expect(parseReminderText('31/02', now), isNull);
    });
    test('texto sem data', () {
      expect(parseReminderText('comprar pão', now), isNull);
      expect(parseReminderText('', now), isNull);
      expect(parseReminderText('às 25', now), isNull);
    });
  });

  test('contagem do prazo', () {
    expect(dueCountdown(DateTime(2026, 10, 21), now), 'vence hoje');
    expect(dueCountdown(DateTime(2026, 10, 22), now), 'vence amanhã');
    expect(dueCountdown(DateTime(2026, 10, 25), now), 'vence em 4 dias');
    expect(dueCountdown(DateTime(2026, 10, 20), now), 'venceu ontem');
    expect(dueCountdown(DateTime(2026, 10, 18), now), 'venceu há 3 dias');
    expect(dueCountdown(DateTime(2026, 12, 1), now), 'até 01/12');
  });

  test('lista de rotina desmarca uma vez por dia', () {
    final note = Note(
      id: 'r',
      title: 'Rotina',
      body: '- [x] Remédio\n- [ ] Água\ntexto [x] solto',
      updatedAt: now,
      checklist: true,
      editor: {'resetDaily': true, 'lastReset': '2026-10-20'},
    );
    final other = Note(id: 'o', title: '', body: '- [x] Fica', updatedAt: now);
    expect(applyDailyResets([note, other], now), isTrue);
    expect(note.body, '- [ ] Remédio\n- [ ] Água\ntexto [x] solto');
    expect(note.editor['lastReset'], '2026-10-21');
    expect(other.body, '- [x] Fica');
    note.body = '- [x] Remédio';
    expect(applyDailyResets([note], now), isFalse);
    expect(note.body, '- [x] Remédio');
  });

  test('links, e-mails e telefones', () {
    final links = extractLinks(
      'Site: https://exemplo.com/a?b=1. Outro www.noto.app\n'
      'Mande para ana.souza@gmail.com ou ligue (11) 98765-4321\n'
      'Repetido https://exemplo.com/a?b=1 e data 21/10/2026 não é telefone',
    );
    expect(links.map((l) => l.kind).toList(), ['web', 'web', 'email', 'phone']);
    expect(links[0].uri.toString(), 'https://exemplo.com/a?b=1');
    expect(links[1].uri.toString(), 'https://www.noto.app');
    expect(links[2].uri.toString(), 'mailto:ana.souza@gmail.com');
    expect(links[3].uri.toString(), 'tel:11987654321');
    expect(extractLinks('nada aqui, só 2026 e 15:30'), isEmpty);
  });

  test('seções da nota', () {
    const body = '# Viagem\nmalas\n## Dia 1\npraia\nsem #título';
    final sections = extractSections(body);
    expect(sections.map((s) => s.title).toList(), ['Viagem', 'Dia 1']);
    expect(sections[1].level, 2);
    expect(body.substring(0, sections[1].offset).endsWith('## Dia 1'), isTrue);
  });

  test('excluir a lista mantém o texto', () {
    expect(
      removeTaskLines('Compras\n- [ ] leite\n- [x] pão\n\nobs: ver preço'),
      'Compras\n\nobs: ver preço',
    );
    expect(removeTaskLines('- [ ] só tarefa'), '');
  });
}
