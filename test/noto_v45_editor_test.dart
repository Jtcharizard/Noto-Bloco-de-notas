import 'dart:convert';

import 'package:bloco_personalizavel/noto_editor.dart';
import 'package:bloco_personalizavel/noto_mixed_editor.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_power_tools.dart';
import 'package:bloco_personalizavel/noto_reader.dart';
import 'package:bloco_personalizavel/noto_rich_editor.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:bloco_personalizavel/noto_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

  AppStore newStore() {
    final store = AppStore()..loaded = true;
    // Sem a dica de tarefas, que cobre a barra de baixo por alguns segundos.
    store.seenTips.add('tasks-enter');
    return store;
  }

  Note newNote(
    String body, {
    bool checklist = false,
    bool locked = false,
    String id = 'v45',
  }) =>
      Note(
        id: id,
        title: 'Teste',
        body: body,
        updatedAt: DateTime(2026, 10, 1),
        checklist: checklist,
        locked: locked,
      );

  Future<void> openEditor(
    WidgetTester tester,
    AppStore store,
    Note note,
  ) async {
    if (!store.notes.contains(note)) store.notes.add(note);
    await tester.pumpWidget(
      MaterialApp(home: EditorPage(store: store, note: note, isNew: false)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> waitSave(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Mais opções'));
    await tester.pumpAndSettle();
  }

  Future<void> tapMenu(WidgetTester tester, String label) async {
    final item = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    await tester.tap(item);
    await tester.pumpAndSettle();
  }

  Finder bodyField() => find.byWidgetPredicate(
        (w) => w is TextField && w.controller is NotoRichController,
      );

  Finder lineField(String text) => find.byWidgetPredicate(
        (w) => w is TextField && w.controller?.text == text,
      );

  NotePaperPainter? paperPainter(WidgetTester tester) {
    for (final paint in tester.widgetList<CustomPaint>(
      find.byType(CustomPaint),
    )) {
      if (paint.painter is NotePaperPainter) {
        return paint.painter! as NotePaperPainter;
      }
    }
    return null;
  }

  group('R2/R3 · menu da nota', () {
    testWidgets('lista não tem "Apagar feitas" nem "Excluir lista"', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite\n- [x] pão', checklist: true);
      await openEditor(tester, store, note);
      await openMenu(tester);
      expect(find.text('Apagar feitas'), findsNothing);
      expect(find.text('Excluir lista'), findsNothing);
      expect(find.text('Desmarcar todas'), findsOneWidget);
      // Ferramentas novas também na lista; meta de palavras é só de texto.
      expect(find.text('Ler rolando'), findsOneWidget);
      expect(find.text('Timer de foco'), findsOneWidget);
      expect(find.text('Meta de palavras'), findsNothing);
      await tapMenu(tester, 'Desmarcar todas');
      await waitSave(tester);
      expect(note.body, '- [ ] leite\n- [ ] pão');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nota do cofre não mostra "Salvar como modelo"', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final locked = newNote('segredo', locked: true, id: 'cofre');
      await openEditor(tester, store, locked);
      await openMenu(tester);
      expect(find.text('Tirar do cofre'), findsOneWidget);
      expect(find.text('Salvar como modelo'), findsNothing);
      await tester.pumpWidget(const SizedBox());

      final normal = newNote('texto', id: 'normal');
      await openEditor(tester, store, normal);
      await openMenu(tester);
      expect(find.text('Salvar como modelo'), findsOneWidget);
      expect(find.text('Meta de palavras'), findsOneWidget);
      expect(find.text('Ler rolando'), findsOneWidget);
      expect(find.text('Timer de foco'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('X da tarefa e tarefas feitas', () {
    for (final toBottom in [true, false]) {
      testWidgets(
        'X na única tarefa deixa a nota em branco (feitas descem: $toBottom)',
        (tester) async {
          bigScreen(tester);
          final store = newStore()..doneToBottom = toBottom;
          final note = newNote('- [ ] única', checklist: true);
          await openEditor(tester, store, note);
          await tester.tap(find.text('única'));
          await tester.pump();
          await tester.tap(find.byTooltip('Apagar tarefa'));
          await tester.pumpAndSettle();
          expect(find.text('única'), findsNothing);
          await waitSave(tester);
          expect(note.body, '');
          expect(note.checklist, isFalse);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }

    Future<TextEditingController> pumpList(
      WidgetTester tester,
      String text, {
      int doneStyle = 0,
      bool doneToBottom = true,
    }) async {
      bigScreen(tester);
      final controller = TextEditingController(text: text);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MixedContentEditor(
              controller: controller,
              onChanged: () {},
              doneStyle: doneStyle,
              doneToBottom: doneToBottom,
            ),
          ),
        ),
      );
      return controller;
    }

    testWidgets('"só apagadas" não risca a tarefa feita', (tester) async {
      await pumpList(tester, '- [x] feita\n- [ ] falta', doneStyle: 1);
      final done = tester.widget<TextField>(lineField('feita'));
      expect(done.style?.decoration, isNot(TextDecoration.lineThrough));
      expect(done.style?.color, isNotNull);
      expect(done.style!.color!.a, lessThan(1));
      final open = tester.widget<TextField>(lineField('falta'));
      expect(open.style?.decoration, isNot(TextDecoration.lineThrough));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('"só riscadas" risca sem apagar; o padrão faz os dois', (
      tester,
    ) async {
      await pumpList(tester, '- [x] feita', doneStyle: 2);
      var done = tester.widget<TextField>(lineField('feita'));
      expect(done.style?.decoration, TextDecoration.lineThrough);
      expect(done.style?.color, isNull);
      await tester.pumpWidget(const SizedBox());

      await pumpList(tester, '- [x] feita');
      done = tester.widget<TextField>(lineField('feita'));
      expect(done.style?.decoration, TextDecoration.lineThrough);
      expect(done.style!.color!.a, lessThan(1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('com "feitas descem" desligado, marcar não muda a ordem', (
      tester,
    ) async {
      var controller = await pumpList(
        tester,
        '- [ ] a\n- [ ] b\n- [ ] c',
        doneToBottom: false,
      );
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(controller.text, '- [x] a\n- [ ] b\n- [ ] c');
      await tester.pumpWidget(const SizedBox());

      // Padrão de sempre: a feita desce.
      controller = await pumpList(tester, '- [ ] a\n- [ ] b\n- [ ] c');
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(controller.text, '- [ ] b\n- [ ] c\n- [x] a');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('R4 · Buscar e trocar em lista', () {
    Future<void> replaceAll(
      WidgetTester tester,
      String needle,
      String replacement,
    ) async {
      await openMenu(tester);
      await tapMenu(tester, 'Buscar e trocar');
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), needle);
      await tester.enterText(fields.at(1), replacement);
      await tester.tap(find.text('Substituir tudo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('a troca aparece na lista e não se perde ao editar', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite\n- [x] pão', checklist: true);
      await openEditor(tester, store, note);
      await replaceAll(tester, 'leite', 'café');
      expect(find.text('café'), findsOneWidget);
      expect(find.text('leite'), findsNothing);
      // Mexer em outra linha não pode trazer o texto antigo de volta.
      await tester.enterText(lineField('pão'), 'pão francês');
      await waitSave(tester);
      expect(note.body, '- [ ] café\n- [x] pão francês');
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('trocar nunca apaga uma tarefa', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite\n- [x] pão', checklist: true);
      await openEditor(tester, store, note);
      await replaceAll(tester, '[ ]', '');
      await replaceAll(tester, '- [x] ', '');
      await replaceAll(tester, 'leite', '');
      await waitSave(tester);
      expect(find.byType(Checkbox), findsNWidgets(2));
      final lines = note.body.split('\n');
      expect(lines, hasLength(2));
      expect(lines.first, startsWith('- [ ]'));
      expect(lines.last, '- [x] pão');
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('S1/S2 · papel e degradê', () {
    testWidgets('escolhas do Estilo da nota ficam salvas', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('primeira linha');
      await openEditor(tester, store, note);
      expect(paperPainter(tester), isNull);
      await tester.tap(find.byTooltip('Estilo da nota'));
      await tester.pumpAndSettle();
      expect(find.text('PAPEL'), findsOneWidget);
      expect(find.text('DEGRADÊ'), findsOneWidget);
      await tester.ensureVisible(find.text('Quadriculado'));
      await tester.tap(find.text('Quadriculado'));
      await tester.pumpAndSettle();
      expect(note.paper, 2);
      await tester.ensureVisible(find.byTooltip('Noite'));
      await tester.tap(find.byTooltip('Noite'));
      await tester.pumpAndSettle();
      expect(note.gradient, 7);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // O papel aparece atrás do texto, com o passo de uma linha de texto.
      final painter = paperPainter(tester)!;
      expect(painter.paper, 2);
      expect(
        painter.step,
        closeTo(store.fontSize * store.editorLineHeight, 1),
      );
      // O campo tem no mínimo 8 linhas: cada linha do papel = uma de texto.
      final bodySize = tester.getSize(bodyField());
      expect(bodySize.height, closeTo(painter.step * 8, .01));
      // Degradê escuro: texto claro (o padrão de cor do texto).
      expect(tester.widget<TextField>(bodyField()).style?.color, Colors.white);

      // Editar e salvar não perde as escolhas.
      await tester.enterText(bodyField(), 'primeira linha editada');
      await waitSave(tester);
      final again = Note.fromJson(jsonDecode(jsonEncode(note.toJson())));
      expect(again.paper, 2);
      expect(again.gradient, 7);
      final prefs = await SharedPreferences.getInstance();
      final saved = (jsonDecode(prefs.getString('notes')!) as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((n) => n['id'] == note.id);
      expect(saved['paper'], 2);
      expect(saved['gradient'], 7);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pautado na lista acompanha a altura das tarefas', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite\n- [ ] pão', checklist: true)
        ..paper = 1;
      // Com o tema do app (o mesmo do celular).
      store.notes.add(note);
      await tester.pumpWidget(
        MaterialApp(
          theme: notoTheme(store, Brightness.light),
          home: EditorPage(store: store, note: note, isNew: false),
        ),
      );
      await tester.pumpAndSettle();
      // Na lista, o pautado é uma linha embaixo de cada tarefa (assim ele
      // acompanha tarefas de duas linhas); o pintor não desenha o pautado.
      expect(paperPainter(tester)?.paper ?? 0, isNot(1));
      for (final text in ['leite', 'pão']) {
        final row = find
            .ancestor(of: lineField(text), matching: find.byType(DecoratedBox))
            .first;
        final box = tester.widget<DecoratedBox>(row).decoration as BoxDecoration;
        expect((box.border! as Border).bottom.style, BorderStyle.solid);
        final rowRect = tester.getRect(
          find.ancestor(of: lineField(text), matching: find.byType(Row)).first,
        );
        expect(tester.getRect(row).bottom, closeTo(rowRect.bottom, .6));
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('degradê claro deixa o texto escuro, mesmo no tema escuro', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite', checklist: true)..gradient = 1;
      store.notes.add(note);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: EditorPage(store: store, note: note, isNew: false),
        ),
      );
      await tester.pumpAndSettle();
      final expected = NotoAppearance.gradientTextColor(1);
      expect(
          tester.widget<TextField>(lineField('leite')).style?.color, expected);
      final decorated = tester.widgetList<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      expect(
        decorated.any(
          (d) =>
              d.decoration is BoxDecoration &&
              (d.decoration as BoxDecoration).gradient ==
                  NotoAppearance.gradientAt(1),
        ),
        isTrue,
      );
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.foregroundColor, expected);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P7/P8 · margens e título', () {
    testWidgets('padrão igual ao 4.4.2; opções mudam margem e título', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('texto');
      double titleSize() => tester
          .widget<TextField>(
            find.byWidgetPredicate(
              (w) => w is TextField && w.decoration?.hintText == 'Título',
            ),
          )
          .style!
          .fontSize!;
      await openEditor(tester, store, note);
      expect(titleSize(), 28);
      expect(tester.getTopLeft(bodyField()).dx, 20);
      await tester.pumpWidget(const SizedBox());

      store
        ..editorMargin = 2
        ..titleSize = 2;
      await openEditor(tester, store, note);
      expect(titleSize(), greaterThan(28));
      expect(tester.getTopLeft(bodyField()).dx, greaterThan(30));
      await tester.pumpWidget(const SizedBox());

      store
        ..editorMargin = 0
        ..titleSize = 0;
      await openEditor(tester, store, note);
      expect(titleSize(), lessThan(28));
      expect(tester.getTopLeft(bodyField()).dx, lessThan(16));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('S3 · Tamanho do trecho', () {
    test('"Normal" tira a marca de tamanho do trecho', () {
      final c = NotoRichController(text: 'abc def ghi');
      c.selection = const TextSelection(baseOffset: 0, extentOffset: 11);
      c.apply('size', 1.35);
      c.selection = const TextSelection(baseOffset: 4, extentOffset: 7);
      c.apply('size', null);
      final sizes = c.marks.where((m) => m['key'] == 'size').toList();
      expect(sizes, [
        {'start': 0, 'end': 4, 'key': 'size', 'value': 1.35},
        {'start': 7, 'end': 11, 'key': 'size', 'value': 1.35},
      ]);
      expect(NotoRichController.sizeFor(1.35, 20), 27);
      expect(NotoRichController.sizeFor(null, 20), isNull);
      c.dispose();
    });

    testWidgets('Formatar texto > Tamanho aplica e "Normal" volta', (
      tester,
    ) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('Olá mundo');
      await openEditor(tester, store, note);
      final controller = tester.widget<TextField>(bodyField()).controller!
          as NotoRichController;

      Future<void> pickSize(String label) async {
        controller.selection = const TextSelection(
          baseOffset: 0,
          extentOffset: 3,
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Formatar texto'));
        await tester.pumpAndSettle();
        await tapMenu(tester, 'Tamanho');
        expect(find.text('Tamanho do trecho'), findsOneWidget);
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }

      await pickSize('Grande');
      expect(
        controller.marks.where(
          (m) => m['key'] == 'size' && m['start'] == 0 && m['end'] == 3,
        ),
        hasLength(1),
      );
      final span = controller.buildTextSpan(
        context: tester.element(bodyField()),
        style: TextStyle(fontSize: store.fontSize),
        withComposing: false,
      );
      expect(
        (span.children!.first as TextSpan).style?.fontSize,
        closeTo(store.fontSize * 1.35, .01),
      );
      await tester.enterText(bodyField(), 'Olá mundo!');
      await waitSave(tester);
      final saved = (note.editor['styles'] as List).cast<Map>();
      expect(
          saved.any((m) => m['key'] == 'size' && m['value'] == 1.35), isTrue);

      await pickSize('Normal');
      expect(
        controller.marks.where((m) => m['key'] == 'size' && m['start'] == 0),
        isEmpty,
      );
      await tester.enterText(bodyField(), 'Olá mundo!!');
      await waitSave(tester);
      expect(
        (note.editor['styles'] as List).cast<Map>().where(
              (m) => m['key'] == 'size',
            ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('F2 · Meta de palavras', () {
    testWidgets('meta fica salva e aparece ao abrir de novo', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('uma duas três');
      await openEditor(tester, store, note);
      await openMenu(tester);
      await tapMenu(tester, 'Meta de palavras');
      await tester.tap(find.text('250'));
      await tester.pumpAndSettle();
      await waitSave(tester);
      expect(note.editor['wordGoal'], 250);
      expect(find.text('3 de 250 palavras'), findsOneWidget);
      // Editar o texto salva de novo sem perder a meta.
      await tester.enterText(bodyField(), 'uma duas três quatro');
      await waitSave(tester);
      expect(note.editor['wordGoal'], 250);
      final again = Note.fromJson(jsonDecode(jsonEncode(note.toJson())));
      expect(again.editor['wordGoal'], 250);
      // A cópia leva a meta junto.
      expect(store.duplicate(note).editor['wordGoal'], 250);
      await tester.pumpWidget(const SizedBox());

      await openEditor(tester, store, again);
      expect(find.text('4 de 250 palavras'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('avisa quando alcança a meta e dá para tirar', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('oi');
      await openEditor(tester, store, note);
      await openMenu(tester);
      await tapMenu(tester, 'Meta de palavras');
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '3',
      );
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await waitSave(tester);
      expect(note.editor['wordGoal'], 3);
      expect(find.text('1 de 3 palavras'), findsOneWidget);
      await tester.enterText(bodyField(), 'oi tudo bem');
      await tester.pumpAndSettle();
      expect(find.text('Meta de palavras alcançada! 🎉'), findsOneWidget);
      await waitSave(tester);

      await openMenu(tester);
      await tapMenu(tester, 'Meta de palavras');
      await tester.tap(find.text('Tirar meta'));
      await tester.pumpAndSettle();
      await waitSave(tester);
      expect(note.editor.containsKey('wordGoal'), isFalse);
      expect(find.textContaining('de 3 palavras'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('F5 · Ler rolando', () {
    test('texto fica limpo para ler', () {
      final lines = readerLines(
        '## Compras\n- [ ] leite\n- [x] **pão**\n> citação\n'
        '- item\nVeja [o site](https://x.com) e `código`\n',
      );
      expect(lines.map((l) => l.text).toList(), [
        'Compras',
        '☐ leite',
        '☑ pão',
        'citação',
        '• item',
        'Veja o site e código',
      ]);
      expect(lines.first.kind, ReaderLineKind.heading);
    });

    testWidgets('abre pelo menu e fecha sem mudar a nota', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final note = newNote('- [ ] leite\n- [x] pão', checklist: true);
      await openEditor(tester, store, note);
      final before = jsonEncode(note.toJson());
      await openMenu(tester);
      await tapMenu(tester, 'Ler rolando');
      expect(find.byType(ReaderPage), findsOneWidget);
      expect(find.text('☐ leite'), findsOneWidget);
      expect(find.text('☑ pão'), findsOneWidget);
      expect(find.text('Velocidade'), findsOneWidget);
      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderPage), findsNothing);
      expect(jsonEncode(note.toJson()), before);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('rola sozinho, pausa no toque e para no fim', (tester) async {
      bigScreen(tester);
      final text = List.generate(80, (i) => 'Linha número $i').join('\n');
      await tester.pumpWidget(
        MaterialApp(
          home: ReaderPage(title: 'Longa', text: text),
        ),
      );
      await tester.pump();
      final list = find.byType(Scrollable).first;
      double offset() => tester.state<ScrollableState>(list).position.pixels;
      expect(find.byTooltip('Pausar'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(offset(), 0); // espera um pouco antes de começar
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(offset(), greaterThan(0));
      // Tocar no texto pausa.
      await tester.tap(find.text('Linha número 3').hitTestable().first);
      await tester.pump();
      expect(find.byTooltip('Continuar'), findsOneWidget);
      final paused = offset();
      await tester.pump(const Duration(seconds: 2));
      expect(offset(), paused);
      // Mais rápido e até o fim.
      await tester.drag(find.byType(Slider), const Offset(400, 0));
      await tester.pump();
      expect(find.text('10'), findsOneWidget);
      await tester.tap(find.byTooltip('Continuar'));
      await tester.pump();
      for (var i = 0;
          i < 2000 && find.byTooltip('Pausar').evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final position = tester.state<ScrollableState>(list).position;
      expect(position.pixels, position.maxScrollExtent);
      expect(find.byTooltip('Continuar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P6 · calendário', () {
    Future<void> openCalendar(WidgetTester tester, AppStore store) async {
      await initializeDateFormatting('pt_BR');
      await tester.pumpWidget(
        MaterialApp(
          home: CalendarPage(store: store, onOpen: (_) async {}),
        ),
      );
      await tester.pumpAndSettle();
    }

    int column(WidgetTester tester, Finder finder) {
      final width = tester.getSize(find.byType(GridView)).width - 28;
      return ((tester.getCenter(finder).dx - 14) / (width / 7)).floor();
    }

    testWidgets('semana começa no domingo quando escolhido', (tester) async {
      bigScreen(tester);
      final store = newStore();
      final now = DateTime.now();
      final firstWeekday = DateTime(now.year, now.month).weekday;

      await openCalendar(tester, store);
      // Padrão de sempre: segunda primeiro, domingo no fim.
      expect(
        tester.getCenter(find.text('D')).dx,
        greaterThan(tester.getCenter(find.text('T')).dx),
      );
      expect(column(tester, find.text('1')), (firstWeekday + 6) % 7);
      await tester.pumpWidget(const SizedBox());

      store.weekStartsSunday = true;
      await openCalendar(tester, store);
      expect(
        tester.getCenter(find.text('D')).dx,
        lessThan(tester.getCenter(find.text('T')).dx),
      );
      expect(column(tester, find.text('1')), firstWeekday % 7);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
