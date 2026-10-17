import 'package:bloco_personalizavel/noto_features.dart';
import 'package:bloco_personalizavel/noto_mixed_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('busca ignora acentos e maiúsculas', () {
    expect(foldForSearch('Química'), 'quimica');
    expect(foldForSearch('AÇÃO'), 'acao');
    expect(foldForSearch('Pão de Ló'), contains('pao de lo'));
  });

  test('nota sem título usa a primeira linha', () {
    Note n(String title, String body) =>
        Note(id: 'x', title: title, body: body, updatedAt: DateTime(2026));
    expect(displayTitle(n('Mercado', 'leite')), 'Mercado');
    expect(displayTitle(n('', '\n- [ ] Comprar pão\nleite')), 'Comprar pão');
    expect(displayTitle(n('', '')), 'Sem título');
  });

  test('nota antiga ganha data de criação e campos novos', () {
    final note = Note.fromJson({
      'id': '1',
      'title': 'Antiga',
      'body': '',
      'updatedAt': '2026-01-02T10:00:00.000',
    });
    expect(note.createdAt, DateTime(2026, 1, 2, 10));
    expect(note.locked, isFalse);
    expect(note.reminderRepeat, 0);
    final copy = Note.fromJson(
      (note
            ..locked = true
            ..reminderRepeat = 2)
          .toJson(),
    );
    expect(copy.locked, isTrue);
    expect(copy.reminderRepeat, 2);
  });

  test('lembrete repetido aparece nos dias certos', () {
    final note = Note(
      id: 'r',
      title: 'Remédio',
      body: '',
      updatedAt: DateTime(2026, 10, 1),
      reminderAt: DateTime(2026, 10, 5, 8), // segunda-feira
      reminderRepeat: 2,
    );
    expect(reminderOccursOn(note, DateTime(2026, 10, 9)), isTrue); // sexta
    expect(reminderOccursOn(note, DateTime(2026, 10, 10)), isFalse); // sábado
    expect(reminderOccursOn(note, DateTime(2026, 10, 4)), isFalse); // antes
    note.reminderRepeat = 3;
    expect(reminderOccursOn(note, DateTime(2026, 10, 12)), isTrue);
    expect(reminderOccursOn(note, DateTime(2026, 10, 13)), isFalse);
  });

  test('notas do cofre ficam fora do resumo do dia', () {
    final now = DateTime(2026, 10, 16, 12);
    final notes = [
      Note(id: 'a', title: 'A', body: '- [ ] x', updatedAt: now),
      Note(
        id: 'b',
        title: 'B',
        body: '- [ ] y',
        updatedAt: now,
        locked: true,
      ),
    ];
    expect(buildTodaySnapshot(notes, now: now).pendingTasks, 1);
  });

  testWidgets('tarefa marcada desce e Enter cria a próxima', (tester) async {
    final controller = TextEditingController(
      text: '- [ ] Um\n- [ ] Dois\n- [ ] Três',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixedContentEditor(controller: controller, onChanged: () {}),
        ),
      ),
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(controller.text, '- [ ] Dois\n- [ ] Três\n- [x] Um');

    await tester.enterText(find.byType(TextField).first, 'Dois\nQuatro');
    await tester.pump();
    expect(controller.text, '- [ ] Dois\n- [ ] Quatro\n- [ ] Três\n- [x] Um');
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('esconde tarefas concluídas', (tester) async {
    final controller = TextEditingController(text: '- [ ] Falta\n- [x] Feita');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixedContentEditor(
            controller: controller,
            onChanged: () {},
            hideDone: true,
          ),
        ),
      ),
    );
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('concluída escondida'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
