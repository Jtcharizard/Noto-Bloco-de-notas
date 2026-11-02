import 'package:bloco_personalizavel/noto_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
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

  Future<(AppStore, Note)> openList(WidgetTester tester, String body) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..loaded = true;
    // Sem a dica de tarefas, que cobre a barra de baixo por alguns segundos.
    store.seenTips.add('tasks-enter');
    final note = Note(
      id: 'lista',
      title: 'Mercado',
      body: body,
      updatedAt: DateTime(2026, 10, 1),
      checklist: true,
    );
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(home: EditorPage(store: store, note: note, isNew: false)),
    );
    await tester.pumpAndSettle();
    return (store, note);
  }

  testWidgets('excluir lista pelo menu deixa a nota vazia', (tester) async {
    final (_, note) = await openList(tester, '- [ ] leite\n- [x] pão');
    expect(find.text('leite'), findsOneWidget);
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Excluir lista'));
    await tester.tap(find.text('Excluir lista'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('leite'), findsNothing);
    expect(find.text('pão'), findsNothing);
    expect(note.body, '');
    expect(note.checklist, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('excluir lista mantém o texto que não é tarefa', (tester) async {
    final (_, note) = await openList(tester, 'Para sábado\n- [ ] leite');
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Excluir lista'));
    await tester.tap(find.text('Excluir lista'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(note.body, 'Para sábado');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('lista nova vazia vira nota em branco', (tester) async {
    final (_, note) = await openList(tester, '- [ ] ');
    await tester.tap(find.byTooltip('Virar texto comum'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(note.body, '');
    expect(note.checklist, isFalse);
    await tester.pumpWidget(const SizedBox());
  });
}
