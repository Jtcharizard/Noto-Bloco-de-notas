import 'package:bloco_personalizavel/noto_editor.dart';
import 'package:bloco_personalizavel/noto_extras.dart';
import 'package:bloco_personalizavel/noto_mixed_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_smart.dart';
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

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('subtarefas mantêm o recuo e acompanham a tarefa principal', (
    tester,
  ) async {
    bigScreen(tester);
    final controller = TextEditingController(
      text: '- [ ] Viagem\n  - [ ] malas\n  - [ ] passaporte\n- [ ] Outra',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixedContentEditor(controller: controller, onChanged: () {}),
        ),
      ),
    );
    expect(find.byType(Checkbox), findsNWidgets(4));
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(
      controller.text,
      '- [x] Viagem\n  - [x] malas\n  - [x] passaporte\n- [ ] Outra',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('barra / no começo da linha abre o menu e vira título', (
    tester,
  ) async {
    bigScreen(tester);
    final store = AppStore()..loaded = true;
    final note = Note(
      id: 'barra',
      title: 'Teste',
      body: '',
      updatedAt: DateTime(2026, 10, 1),
    );
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(home: EditorPage(store: store, note: note, isNew: false)),
    );
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Escreva aqui...',
    );
    await tester.enterText(body, '/');
    await tester.pumpAndSettle();
    expect(find.text('Inserir aqui'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Título'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(note.body, '## ');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('nota que ficou vazia vai para a lixeira ao sair', (
    tester,
  ) async {
    bigScreen(tester);
    final store = AppStore()..loaded = true;
    final note = Note(
      id: 'vazia',
      title: '',
      body: 'algo',
      updatedAt: DateTime(2026, 10, 1),
    );
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditorPage(store: store, note: note, isNew: false),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    final body = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Escreva aqui...',
    );
    await tester.enterText(body, '');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Voltar'));
    await tester.pumpAndSettle();
    expect(note.deletedAt, isNotNull);
    expect(find.text('Nota vazia descartada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('importa nota do Google Keep', () {
    final note = noteFromKeepJson({
      'title': 'Mercado',
      'listContent': [
        {'text': 'leite', 'isChecked': false},
        {'text': 'pão', 'isChecked': true},
      ],
      'isPinned': true,
      'isArchived': false,
      'isTrashed': false,
      'labels': [
        {'name': 'casa'},
      ],
      'userEditedTimestampUsec': 1700000000000000,
    }, id: 'k1')!;
    expect(note.title, 'Mercado');
    expect(note.body, '- [ ] leite\n- [x] pão');
    expect(note.checklist, isTrue);
    expect(note.pinned, isTrue);
    expect(note.tags, ['casa']);
    expect(note.folder, 'Google Keep');
    expect(
      noteFromKeepJson({'title': 'x', 'isTrashed': true}, id: 'k2'),
      isNull,
    );
    expect(noteFromKeepJson({'outra': 'coisa'}, id: 'k3'), isNull);
  });

  test('modelos prontos têm nome e conteúdo', () {
    expect(starterTemplates.length, greaterThanOrEqualTo(6));
    for (final template in starterTemplates) {
      expect(template.name, isNotEmpty);
      expect(template.body, isNotEmpty);
      expect(template.emoji, isNotEmpty);
    }
  });

  testWidgets('tarefa marcada tem X para apagar', (tester) async {
    bigScreen(tester);
    final controller = TextEditingController(
      text: '- [x] Pão\n- [ ] Leite',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixedContentEditor(controller: controller, onChanged: () {}),
        ),
      ),
    );
    expect(find.byTooltip('Apagar tarefa'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Apagar tarefa').first);
    await tester.pump();
    expect(controller.text, '- [ ] Leite');
    // Editando a tarefa e tocando no X: tem que apagar também.
    controller.text = '- [ ] Leite\n- [ ] Ovos';
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MixedContentEditor(controller: controller, onChanged: () {}),
        ),
      ),
    );
    await tester.tap(find.text('Ovos'));
    await tester.pump();
    await tester.tap(find.byTooltip('Apagar tarefa').last);
    await tester.pumpAndSettle();
    expect(controller.text, '- [ ] Leite');
    await tester.pumpWidget(const SizedBox());
  });
}
