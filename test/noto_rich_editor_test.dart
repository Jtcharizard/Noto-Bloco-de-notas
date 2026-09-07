import 'dart:convert';

import 'package:bloco_personalizavel/noto_rich_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_editor_v2.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (_) async => true,
        );
  });

  test(
    'format ranges move when text is inserted and survive serialization',
    () {
      final c = NotoRichController(text: 'abc def');
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.apply('color', 0xFF7C3AED);
      c.value = const TextEditingValue(
        text: 'XYZ abc def',
        selection: TextSelection.collapsed(offset: 4),
      );
      expect(c.marks.first['start'], 8);
      expect(c.marks.first['end'], 11);
      final note = Note(
        id: '1',
        title: '',
        body: c.text,
        updatedAt: DateTime(2026),
        editor: {'styles': c.marks},
      );
      expect(
        Note.fromJson(jsonDecode(jsonEncode(note.toJson()))).editor['styles'],
        c.marks,
      );
      c.dispose();
    },
  );

  test(
    'replacing formatted text keeps its style without out-of-range spans',
    () {
      final c = NotoRichController(text: 'abcdef');
      c.selection = const TextSelection(baseOffset: 1, extentOffset: 5);
      c.apply('bold', true);
      c.value = const TextEditingValue(
        text: 'aXf',
        selection: TextSelection.collapsed(offset: 2),
      );
      expect(c.marks.every((m) => (m['end'] as int) <= c.text.length), isTrue);
      expect(
        c.marks.any(
          (m) => m['key'] == 'bold' && m['start'] == 1 && m['end'] == 2,
        ),
        isTrue,
      );
      c.dispose();
    },
  );

  test('migrates old tables but leaves fenced code intact', () {
    final old =
        'Antes\n| A | B |\n| --- | --- |\n| 1 | 2 |\nDepois\n```\n| A | B |\n| --- | --- |\n```';
    final migrated = migrateTables(old);
    expect(migrated.tables, hasLength(1));
    expect(migrated.tables.first.cells[1], ['1', '2']);
    expect(migrated.text, contains('Antes'));
    expect(migrated.text, contains('Depois'));
    expect(migrated.text, contains('```\n| A | B |'));
  });

  testWidgets(
    'table cells edit directly; adding rows and canceling deletion keep data',
    (tester) async {
      final table = NotoTable.create(1, 2);
      var deleted = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VisualNoteTable(
              table: table,
              onChanged: () {},
              onDelete: () => deleted = true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'Valor');
      expect(table.cells[1][0], 'Valor');
      await tester.tap(find.byTooltip('Linhas e colunas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar linha abaixo'));
      await tester.pumpAndSettle();
      expect(table.cells.length, 3);
      expect(table.cells.any((r) => r.contains('Valor')), isTrue);
      await tester.tap(find.byTooltip('Linhas e colunas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apagar tabela'));
      await tester.pumpAndSettle();
      expect(find.text('Apagar a tabela preenchida?'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
    },
  );

  testWidgets('editor saves, restores cursor and provides undo on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore();
    final note = Note(
      id: 'edit',
      title: 'Teste',
      body: 'Antes',
      updatedAt: DateTime(2026),
      editor: {'cursor': 3},
    );
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(
        home: EditorPageV2(store: store, note: note, isNew: false),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.controller is NotoRichController,
    );
    expect(
      (tester.widget<TextField>(field).controller!).selection.extentOffset,
      3,
    );
    await tester.enterText(field, 'Depois');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notes'), contains('Depois'));
    await tester.tap(find.byTooltip('Desfazer'));
    await tester.pump();
    expect((tester.widget<TextField>(field).controller!).text, 'Antes');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('new-note journal is recovered after a restart', () async {
    SharedPreferences.setMockInitialValues({
      'editor.draft.recovered': jsonEncode({
        'at': '2026-09-07T12:00:00Z',
        'snapshot': jsonEncode({
          'title': 'Recuperada',
          'body': 'rascunho',
          'styles': [],
          'tables': [],
          'align': 0,
        }),
      }),
    });
    final store = AppStore();
    await store.load();
    expect(store.notes.single.id, 'recovered');
    expect(store.notes.single.body, 'rascunho');
  });
}
