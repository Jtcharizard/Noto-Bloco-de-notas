import 'package:bloco_personalizavel/noto_formatting.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_power_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats reversed selections without deleting surrounding text', () {
    final result = formatSelection(
      const TextEditingValue(
        text: 'antes texto depois',
        selection: TextSelection(baseOffset: 11, extentOffset: 6),
      ),
      prefix: '**',
      suffix: '**',
    );
    expect(result.text, 'antes **texto** depois');
    expect(result.selection.textInside(result.text), 'texto');
  });

  test('inserts placeholder at the end when there is no cursor', () {
    final result = formatSelection(
      const TextEditingValue(text: 'Olá '),
      prefix: '*',
      suffix: '*',
    );
    expect(result.text, 'Olá *texto*');
  });

  test('list formatting includes whole lines but not the following line', () {
    final result = formatSelection(
      const TextEditingValue(
        text: 'um\ndois\ntrês',
        selection: TextSelection(baseOffset: 1, extentOffset: 8),
      ),
      prefix: '- ',
      eachLine: true,
    );
    expect(result.text, '- um\n- dois\ntrês');
  });

  test(
    'table is separated from surrounding text and survives note serialization',
    () {
      final table = markdownTable(2, 3);
      final result = formatSelection(
        const TextEditingValue(
          text: 'antesdepois',
          selection: TextSelection.collapsed(offset: 5),
        ),
        placeholder: table,
        block: true,
      );
      expect(result.text, 'antes\n\n$table\n\ndepois');
      expect(table.split('\n'), hasLength(4));
      final note = Note(
        id: 'table',
        title: 'Tabela',
        body: result.text,
        updatedAt: DateTime(2026),
      );
      expect(Note.fromJson(note.toJson()).body, result.text);
    },
  );

  testWidgets(
    'preview renders a table and inline formatting on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MarkdownPreviewPage(
            title: 'Teste',
            markdown:
                '**Negrito** e *itálico*\n\n${markdownTable(2, 6)}\n\n[ ] Tarefa antiga\n\n- [x] Tarefa nova',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Table), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  group('listas continuam com Enter', () {
    TextEditingValue press(String before) {
      final old = TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      );
      final typed = TextEditingValue(
        text: '$before\n',
        selection: TextSelection.collapsed(offset: before.length + 1),
      );
      return continueList(old, typed);
    }

    test('marcador simples', () {
      expect(press('- leite').text, '- leite\n- ');
    });
    test('numeração', () {
      expect(press('1. um').text, '1. um\n2. ');
      expect(press('9) nove').text, '9) nove\n10) ');
    });
    test('tarefa vira nova tarefa desmarcada', () {
      expect(press('- [x] feito').text, '- [x] feito\n- [ ] ');
    });
    test('lista vazia encerra a lista', () {
      final result = press('- leite\n- ');
      expect(result.text, '- leite\n');
      expect(result.selection.baseOffset, result.text.length);
    });
    test('texto comum não muda', () {
      expect(press('olá').text, 'olá\n');
    });
  });
}
