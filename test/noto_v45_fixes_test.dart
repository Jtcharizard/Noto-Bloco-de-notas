import 'package:bloco_personalizavel/noto_editor.dart';
import 'package:bloco_personalizavel/noto_focus.dart';
import 'package:bloco_personalizavel/noto_mixed_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_rich_editor.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:bloco_personalizavel/noto_tasks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda as chamadas do aviso do Timer de foco, sem plugin de notificação.
class _FocusStore extends AppStore {
  final calls = <String>[];

  @override
  Future<void> scheduleFocusDone(DateTime at) async => calls.add('schedule');

  @override
  Future<void> showFocusDoneNow() async => calls.add('show');

  @override
  Future<void> cancelFocusDone() async => calls.add('cancel');
}

/// Correções da revisão da 4.5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'home_widget',
      'dexterous.com/flutter/local_notifications',
      'noto/share',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  void screen(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('Timer de foco', () {
    Future<_FocusStore> openTimer(WidgetTester tester, DateTime ends) async {
      screen(tester);
      final store = _FocusStore()..loaded = true;
      store.focusEndsAt = ends;
      await tester.pumpWidget(MaterialApp(home: FocusTimerPage(store: store)));
      await tester.pump();
      return store;
    }

    Future<void> runToEnd(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    }

    testWidgets('acabou com o app em segundo plano: o aviso sai, não é '
        'cancelado', (tester) async {
      final store = await openTimer(
        tester,
        DateTime.now().add(const Duration(milliseconds: 300)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await runToEnd(tester);
      expect(store.calls, contains('show'));
      expect(store.calls, isNot(contains('cancel')));
      expect(store.focusEndsAt, isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('acabou com o app aberto: tira o aviso agendado', (
      tester,
    ) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final store = await openTimer(
        tester,
        DateTime.now().add(const Duration(milliseconds: 300)),
      );
      await runToEnd(tester);
      expect(store.calls, contains('cancel'));
      expect(store.calls, isNot(contains('show')));
      expect(find.text(focusDoneMessage), findsOneWidget);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pausado continua pausado depois de sair da tela', (
      tester,
    ) async {
      screen(tester);
      final store = _FocusStore()..loaded = true;
      await tester.pumpWidget(MaterialApp(home: FocusTimerPage(store: store)));
      await tester.pump();
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(store.focusPausedSeconds, isNotNull);
      expect(store.focusPausedSeconds, inInclusiveRange(24 * 60, 25 * 60));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('focusPausedSeconds'), store.focusPausedSeconds);

      // Sai e volta: a pausa continua lá.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: FocusTimerPage(store: store)));
      await tester.pump();
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Parar'), findsOneWidget);
      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();
      expect(store.focusPausedSeconds, isNull);
      expect(find.text('Começar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('lixeira: prazo menor já tira o que passou dele', () {
    final store = AppStore()..loaded = true;
    final now = DateTime(2026, 11, 2);
    Note trashed(String id, int daysAgo) => Note(
      id: id,
      title: id,
      body: '',
      updatedAt: now,
      deletedAt: now.subtract(Duration(days: daysAgo)),
    );
    store.notes.addAll([trashed('velha', 10), trashed('nova', 3)]);
    store.trashDays = 7;
    expect(store.purgeOldTrash(now), 1);
    expect(store.notes.map((n) => n.id), ['nova']);
  });

  group('Tarefas que faltaram', () {
    Note daily(String key, String body, {bool locked = false, bool trash = false}) =>
        Note(
          id: key,
          title: key,
          body: body,
          updatedAt: DateTime(2026, 11, 1),
          editor: {'daily': key},
          locked: locked,
          deletedAt: trash ? DateTime(2026, 11, 1) : null,
          checklist: true,
        );

    test('última nota do dia no cofre: nada vem (nem de um dia mais antigo)', () {
      final notes = [
        daily('2026-10-30', '- [ ] Pagar luz'),
        daily('2026-10-31', '- [x] Pagar luz', locked: true),
      ];
      expect(missedTasksForToday(notes, '2026-11-01'), isEmpty);
    });

    test('última nota do dia na lixeira: nada vem', () {
      final notes = [
        daily('2026-10-30', '- [ ] Pagar luz'),
        daily('2026-10-31', '- [x] Pagar luz', trash: true),
      ];
      expect(missedTasksForToday(notes, '2026-11-01'), isEmpty);
    });

    test('a última nota normal continua trazendo o que faltou', () {
      final notes = [
        daily('2026-10-30', '- [ ] Antiga'),
        daily('2026-10-31', '- [ ] Pagar luz\n- [x] Feita'),
      ];
      expect(missedTasksForToday(notes, '2026-11-01'), ['- [ ] Pagar luz']);
    });
  });

  group('Lista', () {
    testWidgets('X na única tarefa com uma linha vazia sobrando: nota em '
        'branco', (tester) async {
      screen(tester);
      final controller = TextEditingController(text: '- [ ] Pilhas\n');
      var emptied = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixedContentEditor(
              controller: controller,
              onChanged: () {},
              onEmptied: () => emptied++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilhas'));
      await tester.pump();
      await tester.tap(find.byTooltip('Apagar tarefa'));
      await tester.pumpAndSettle();
      expect(emptied, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('X na única tarefa com uma tarefa vazia sobrando: nota em '
        'branco', (tester) async {
      screen(tester);
      final controller = TextEditingController(text: '- [ ] Pilhas\n- [ ] ');
      var emptied = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixedContentEditor(
              controller: controller,
              onChanged: () {},
              onEmptied: () => emptied++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilhas'));
      await tester.pump();
      await tester.tap(find.byTooltip('Apagar tarefa'));
      await tester.pumpAndSettle();
      expect(emptied, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('com outra tarefa, o X apaga só a linha tocada', (
      tester,
    ) async {
      screen(tester);
      final controller = TextEditingController(text: '- [ ] Pilhas\n- [ ] Pão');
      var emptied = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixedContentEditor(
              controller: controller,
              onChanged: () {},
              onEmptied: () => emptied++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pilhas'));
      await tester.pump();
      await tester.tap(find.byTooltip('Apagar tarefa'));
      await tester.pumpAndSettle();
      expect(emptied, 0);
      expect(controller.text, '- [ ] Pão');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('papel pautado: uma linha embaixo de cada tarefa', (
      tester,
    ) async {
      screen(tester);
      final controller = TextEditingController(
        text: '- [ ] uma tarefa bem comprida que ocupa mais de uma linha na '
            'tela do celular, para quebrar\n- [ ] pão\n- [ ] ovo',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixedContentEditor(
              controller: controller,
              onChanged: () {},
              paper: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final ruled = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .where(
            (box) =>
                box.decoration is BoxDecoration &&
                (box.decoration as BoxDecoration).border is Border &&
                ((box.decoration as BoxDecoration).border! as Border)
                        .bottom
                        .style ==
                    BorderStyle.solid,
          );
      expect(ruled.length, 3);
      // Sem linhas desenhadas por cima do texto (o pautado não usa o pintor).
      for (final paint in tester.widgetList<CustomPaint>(
        find.byType(CustomPaint),
      )) {
        if (paint.painter is NotePaperPainter) {
          expect((paint.painter! as NotePaperPainter).paper, isNot(1));
        }
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('trocar o degradê não recria o editor (a rolagem fica)', (
    tester,
  ) async {
    screen(tester);
    final store = AppStore()..loaded = true;
    store.seenTips.add('tasks-enter');
    final note = Note(
      id: 'longa',
      title: 'Longa',
      body: List.generate(200, (i) => 'linha $i').join('\n'),
      updatedAt: DateTime(2026, 11, 1),
    );
    store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(home: EditorPage(store: store, note: note, isNew: false)),
    );
    await tester.pumpAndSettle();
    // A rolagem da nota é a que fica em volta do campo do texto.
    Finder editorScroll() => find
        .ancestor(
          of: find.byWidgetPredicate(
            (w) => w is TextField && w.controller is NotoRichController,
          ),
          matching: find.byType(Scrollable),
        )
        .first;
    final before = tester.state<ScrollableState>(editorScroll());
    expect(before.position.maxScrollExtent, greaterThan(800));
    before.position.jumpTo(800);
    await tester.pump();

    await tester.tap(find.byTooltip('Estilo da nota'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('Pêssego'));
    await tester.tap(find.byTooltip('Pêssego'));
    await tester.pumpAndSettle();
    expect(note.gradient, 1);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final after = tester.state<ScrollableState>(editorScroll());
    expect(identical(before, after), isTrue);
    expect(after.position.pixels, 800);
    await tester.pumpWidget(const SizedBox());
  });
}
