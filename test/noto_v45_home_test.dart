import 'package:bloco_personalizavel/noto_app.dart';
import 'package:bloco_personalizavel/noto_focus.dart';
import 'package:bloco_personalizavel/noto_home.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_settings.dart';
import 'package:bloco_personalizavel/noto_smart.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:bloco_personalizavel/noto_tasks.dart';
import 'package:bloco_personalizavel/noto_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Testes da 4.5 na tela inicial, Ajustes, Timer de foco e tema.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in [
      'home_widget',
      'home_widget/updates',
      'dexterous.com/flutter/local_notifications',
      'plugins.flutter.io/quick_actions_android',
      'plugins.flutter.io/quick_actions',
      'noto/share',
      'plugins.flutter.io/path_provider',
      'plugin.csdcorp.com/speech_to_text',
    ]) {
      messenger.setMockMethodCallHandler(
        MethodChannel(name),
        (_) async => null,
      );
    }
  });

  void screen(WidgetTester tester, {double height = 900}) {
    tester.view.physicalSize = Size(420, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<AppStore> openHome(
    WidgetTester tester, {
    List<Note> notes = const [],
    void Function(AppStore store)? setup,
    double height = 900,
  }) async {
    screen(tester, height: height);
    final store = AppStore()..loaded = true;
    store.seenTips.addAll(['home-gestures', 'tasks-enter']);
    store.notes.addAll(notes);
    setup?.call(store);
    await tester.pumpWidget(MaterialApp(home: HomeShell(store: store)));
    await tester.pumpAndSettle();
    return store;
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(BottomSheet), matching: finder);

  group('R1: menu de criar', () {
    testWidgets('só Em branco e Lista de tarefas, mesmo com texto copiado', (
      tester,
    ) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (
        call,
      ) async {
        if (call.method == 'Clipboard.hasStrings') return {'value': true};
        if (call.method == 'Clipboard.getData') {
          return {'text': 'Texto copiado'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await openHome(tester);
      await tester.tap(find.text('Criar primeira nota'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Em branco')), findsOneWidget);
      expect(inSheet(find.text('Lista de tarefas')), findsOneWidget);
      expect(find.text('Colar o que copiei'), findsNothing);
      expect(find.text('Usar um modelo'), findsNothing);
      expect(inSheet(find.byType(InkWell)), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Usar um modelo aparece quando há modelo salvo', (
      tester,
    ) async {
      await openHome(
        tester,
        setup: (store) => store.templates.add(
          NotoTemplate(id: 't1', name: 'Reunião', body: 'Pauta'),
        ),
      );
      await tester.tap(find.text('Criar primeira nota'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Em branco')), findsOneWidget);
      expect(inSheet(find.text('Lista de tarefas')), findsOneWidget);
      expect(inSheet(find.text('Usar um modelo')), findsOneWidget);
      expect(find.text('Colar o que copiei'), findsNothing);
      expect(inSheet(find.byType(InkWell)), findsNWidgets(3));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Ajustes', () {
    const categories = [
      'Aparência',
      'Tela inicial e cards',
      'Notas, gestos e widget',
      'Backup e dados',
      'Ajuda e sobre',
    ];

    testWidgets('nenhuma página dos Ajustes fala de cofre ou senha', (
      tester,
    ) async {
      // Tela bem alta: todos os itens das listas ficam montados.
      screen(tester, height: 5000);
      final store = AppStore()..loaded = true;
      store.notes.add(
        Note(id: 'n', title: 'Nota', body: 'x', updatedAt: DateTime(2026)),
      );
      await tester.pumpWidget(MaterialApp(home: SettingsPage(store: store)));
      await tester.pumpAndSettle();
      for (final category in categories) {
        await tester.tap(find.text(category));
        await tester.pumpAndSettle();
        expect(find.text('Trocar senha'), findsNothing, reason: category);
        expect(find.textContaining('Cofre'), findsNothing, reason: category);
        expect(find.textContaining('cofre'), findsNothing, reason: category);
        expect(find.textContaining('senha'), findsNothing, reason: category);
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
      expect(find.textContaining('Cofre'), findsNothing);
      expect(find.text('Trocar senha'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    Future<AppStore> openCategory(WidgetTester tester, String category) async {
      screen(tester, height: 5000);
      final store = AppStore()..loaded = true;
      await tester.pumpWidget(MaterialApp(home: SettingsPage(store: store)));
      await tester.pumpAndSettle();
      await tester.tap(find.text(category));
      await tester.pumpAndSettle();
      return store;
    }

    Future<void> pick(WidgetTester tester, String tile, String option) async {
      await tester.tap(find.text(tile));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text(option)));
      await tester.pumpAndSettle();
    }

    testWidgets('Aparência: cantos, letras do app, título e margens', (
      tester,
    ) async {
      final store = await openCategory(tester, 'Aparência');
      expect(find.text('Cantos do app'), findsOneWidget);
      expect(find.text('Suaves (padrão)'), findsOneWidget);
      // "Normal (padrão)" também é o padrão do espaço entre as linhas.
      expect(find.text('Normal (padrão)'), findsNWidgets(2));
      expect(find.text('Tamanho das letras do app'), findsOneWidget);
      expect(find.text('Médio (padrão)'), findsOneWidget);
      expect(find.text('Normais (padrão)'), findsOneWidget);

      await pick(tester, 'Cantos do app', 'Redondos');
      expect(store.appCorners, 2);
      await pick(tester, 'Cantos do app', 'Retos');
      expect(store.appCorners, 0);

      await pick(tester, 'Tamanho das letras do app', 'Maior');
      expect(store.uiScale, 1.2);
      await pick(tester, 'Tamanho das letras do app', 'Pequeno');
      expect(store.uiScale, .9);

      await pick(tester, 'Tamanho do título da nota', 'Grande');
      expect(store.titleSize, 2);

      await pick(tester, 'Margens do editor', 'Largas');
      expect(store.editorMargin, 2);
      await pick(tester, 'Margens do editor', 'Estreitas');
      expect(store.editorMargin, 0);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('appCorners'), 0);
      expect(prefs.getDouble('uiScale'), .9);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Tela inicial e cards: data nos cards', (tester) async {
      final store = await openCategory(tester, 'Tela inicial e cards');
      expect(find.text('Data nos cards'), findsOneWidget);
      expect(find.text('Relativa (ontem, 14:30)'), findsOneWidget);
      await pick(tester, 'Data nos cards', 'Completa (02/11/2026)');
      expect(store.cardDateFull, isTrue);
      await pick(tester, 'Data nos cards', 'Relativa (ontem, 14:30)');
      expect(store.cardDateFull, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Notas: tarefas feitas, descer, trazer, vibrar e semana', (
      tester,
    ) async {
      addTearDown(() => NotoHaptics.enabled = true);
      final store = await openCategory(tester, 'Notas, gestos e widget');
      expect(find.text('Toque e calendário'.toUpperCase()), findsOneWidget);
      expect(find.text('Riscadas e apagadas (padrão)'), findsOneWidget);
      expect(find.text('Segunda (padrão)'), findsOneWidget);
      expect(
        find.text('Copia as tarefas não feitas da última nota do dia'),
        findsOneWidget,
      );

      await pick(tester, 'Tarefas feitas', 'Só riscadas');
      expect(store.doneStyle, 2);
      await pick(tester, 'Tarefas feitas', 'Só apagadas');
      expect(store.doneStyle, 1);

      expect(store.doneToBottom, isTrue);
      await tester.tap(find.text('Feitas descem para o fim'));
      await tester.pumpAndSettle();
      expect(store.doneToBottom, isFalse);

      expect(store.carryTasksToToday, isTrue);
      await tester.tap(find.text('Nota de hoje traz o que faltou'));
      await tester.pumpAndSettle();
      expect(store.carryTasksToToday, isFalse);

      expect(store.haptics, isTrue);
      await tester.tap(find.text('Vibrar ao tocar'));
      await tester.pumpAndSettle();
      expect(store.haptics, isFalse);
      expect(NotoHaptics.enabled, isFalse);

      await pick(tester, 'Semana começa no', 'Domingo');
      expect(store.weekStartsSunday, isTrue);
      await pick(tester, 'Semana começa no', 'Segunda (padrão)');
      expect(store.weekStartsSunday, isFalse);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Backup e dados: esvaziar a lixeira depois de', (tester) async {
      final store = await openCategory(tester, 'Backup e dados');
      expect(find.text('Lixeira'.toUpperCase()), findsOneWidget);
      expect(find.text('30 dias (padrão)'), findsOneWidget);
      await pick(tester, 'Esvaziar a lixeira depois de', '7 dias');
      expect(store.trashDays, 7);
      await pick(tester, 'Esvaziar a lixeira depois de', '60 dias');
      expect(store.trashDays, 60);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('trashDays'), 60);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('F3: tarefas que faltaram', () {
    Note daily(String id, DateTime day, String body, {bool deleted = false}) =>
        Note(
          id: id,
          title: 'Dia $id',
          body: body,
          updatedAt: day,
          checklist: true,
          folder: 'Diário',
          editor: {'daily': dayKey(day)},
          deletedAt: deleted ? day : null,
        );

    test('copia as pendentes da última nota do dia, com recuo', () {
      final today = DateTime(2026, 11, 2);
      const body =
          '- [x] feita\n- [ ] pendente\n  - [ ] sub\n  - [x] sub feita\n'
          '- [ ] \n- [ ]    \ntexto solto\n\t- [ ] com tab';
      final older = daily('a', DateTime(2026, 10, 30), '- [ ] antiga');
      final last = daily('b', DateTime(2026, 11, 1), body);
      final missed = missedTasksForToday([last, older], dayKey(today));
      expect(missed, ['- [ ] pendente', '  - [ ] sub', '  - [ ] com tab']);
      // Cópia: a nota antiga não muda.
      expect(last.body, body);
      expect(missedTasksMessage(1), '1 tarefa que faltou veio para hoje');
      expect(missedTasksMessage(3), '3 tarefas que faltaram vieram para hoje');
    });

    test('sem nota do dia anterior, não traz nada', () {
      final key = dayKey(DateTime(2026, 11, 2));
      expect(missedTasksForToday(const [], key), isEmpty);
      // A de hoje e uma comum não contam.
      final todayNote = daily('t', DateTime(2026, 11, 2), '- [ ] hoje');
      final plain = Note(
        id: 'p',
        title: 'Comum',
        body: '- [ ] comum',
        updatedAt: DateTime(2026, 10, 1),
      );
      expect(missedTasksForToday([todayNote, plain], key), isEmpty);
      // Apagada e do cofre também não.
      final deleted = daily('d', DateTime(2026, 11, 1), '- [ ] x', deleted: true);
      final vault = daily('v', DateTime(2026, 10, 31), '- [ ] segredo')
        ..locked = true;
      expect(missedTasksForToday([deleted, vault], key), isEmpty);
      // Só feitas: nada.
      final done = daily('f', DateTime(2026, 11, 1), '- [x] tudo feito');
      expect(missedTasksForToday([done], key), isEmpty);
    });

    testWidgets('Menu > Hoje cria a nota de hoje com o que faltou', (
      tester,
    ) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      const body = '- [x] feita\n- [ ] pagar conta\n  - [ ] boleto';
      final old = daily('ontem', yesterday, body);
      final store = await openHome(tester, notes: [old]);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Hoje')));
      await tester.pumpAndSettle();
      expect(
        find.text('2 tarefas que faltaram vieram para hoje'),
        findsOneWidget,
      );
      expect(find.text('pagar conta'), findsOneWidget);
      expect(find.text('boleto'), findsOneWidget);
      expect(find.text('feita'), findsNothing);
      expect(old.body, body);
      expect(store.notes.where((n) => n.id == 'ontem').single.body, body);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('desligado, a nota de hoje nasce vazia', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await openHome(
        tester,
        notes: [daily('ontem', yesterday, '- [ ] pagar conta')],
        setup: (store) => store.carryTasksToToday = false,
      );
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Hoje')));
      await tester.pumpAndSettle();
      expect(find.textContaining('vieram para hoje'), findsNothing);
      expect(find.textContaining('veio para hoje'), findsNothing);
      expect(find.text('pagar conta'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('F4: filtrar por cor', () {
    List<Note> colored() => [
      Note(id: '1', title: 'Rosa', body: 'a', updatedAt: DateTime(2026, 10, 3), color: 3),
      Note(id: '2', title: 'Lilás', body: 'b', updatedAt: DateTime(2026, 10, 2), color: 4),
      Note(id: '3', title: 'Sem cor', body: 'c', updatedAt: DateTime(2026, 10, 1)),
    ];

    Future<void> openFilters(WidgetTester tester) async {
      if (find.byTooltip('Busca avançada').evaluate().isEmpty) {
        await tester.tap(find.byTooltip('Buscar'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Busca avançada'));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra só as notas da cor e dá para tirar o filtro', (
      tester,
    ) async {
      await openHome(tester, notes: colored(), height: 1600);
      await openFilters(tester);
      expect(inSheet(find.text('Cor')), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && (w.message ?? '').startsWith('Cor '),
        ),
        findsNWidgets(NotoAppearance.noteColors.length - 1),
      );
      await tester.tap(find.byTooltip('Cor 3'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Aplicar')));
      await tester.pumpAndSettle();
      expect(find.text('Rosa'), findsOneWidget);
      expect(find.text('Lilás'), findsNothing);
      expect(find.text('Sem cor'), findsNothing);
      expect(find.text('1 encontrada'), findsOneWidget);

      // O filtro ativo aparece e sai com um toque.
      expect(find.byTooltip('Tirar filtro de cor'), findsOneWidget);
      await tester.tap(find.byTooltip('Tirar filtro de cor'));
      await tester.pumpAndSettle();
      expect(find.text('Lilás'), findsOneWidget);
      expect(find.text('Sem cor'), findsOneWidget);

      // Tocar de novo na mesma cor tira a escolha.
      await openFilters(tester);
      await tester.tap(find.byTooltip('Cor 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cor 4'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Aplicar')));
      await tester.pumpAndSettle();
      expect(find.text('Rosa'), findsOneWidget);
      expect(find.byTooltip('Tirar filtro de cor'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Limpar da busca avançada tira a cor; Limpar da tela também', (
      tester,
    ) async {
      await openHome(tester, notes: colored(), height: 1600);
      await openFilters(tester);
      await tester.tap(find.byTooltip('Cor 4'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Limpar')));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Aplicar')));
      await tester.pumpAndSettle();
      expect(find.text('Rosa'), findsOneWidget);
      expect(find.text('Lilás'), findsOneWidget);

      await openFilters(tester);
      await tester.tap(find.byTooltip('Cor 4'));
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Aplicar')));
      await tester.pumpAndSettle();
      expect(find.text('Rosa'), findsNothing);
      await tester.tap(find.text('Limpar'));
      await tester.pumpAndSettle();
      expect(find.text('Rosa'), findsOneWidget);
      expect(find.text('Lilás'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P1: cantos do app', () {
    double radiusOf(ShapeBorder? shape) {
      final border = (shape! as RoundedRectangleBorder).borderRadius.resolve(
        TextDirection.ltr,
      );
      return border.topLeft.x;
    }

    List<double> radii(ThemeData theme) => [
      radiusOf(theme.cardTheme.shape),
      radiusOf(theme.chipTheme.shape),
      radiusOf(theme.filledButtonTheme.style!.shape!.resolve({})),
      radiusOf(theme.bottomSheetTheme.shape),
      radiusOf(theme.dialogTheme.shape),
      radiusOf(theme.snackBarTheme.shape),
    ];

    test('Suaves (padrão) mantém os cantos da 4.4.2', () {
      final store = AppStore();
      expect(store.appCorners, 1);
      for (final brightness in Brightness.values) {
        final theme = notoTheme(store, brightness);
        // Valores lidos do noto_theme.dart da 4.4.2.
        expect(radii(theme), [10, 7, 8, 14, 12, 8]);
        expect(
          theme.floatingActionButtonTheme.shape,
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        );
        expect(
          theme.bottomSheetTheme.shape,
          const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
        );
      }
    });

    test('Retos deixa tudo quase reto e Redondos bem redondo', () {
      final store = AppStore()..appCorners = 0;
      final square = notoTheme(store, Brightness.light);
      for (final r in [
        ...radii(square),
        radiusOf(square.floatingActionButtonTheme.shape),
      ]) {
        expect(r, inInclusiveRange(2, 4));
      }
      store.appCorners = 2;
      final round = notoTheme(store, Brightness.light);
      for (final r in radii(round)) {
        expect(r, inInclusiveRange(20, 28));
      }
      expect(round.floatingActionButtonTheme.shape, isA<StadiumBorder>());
    });
  });

  group('P2: tamanho das letras do app', () {
    testWidgets('NotoTextScale multiplica a letra do sistema', (tester) async {
      late double scaled;
      late double plain;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Column(
            children: [
              NotoTextScale(
                scale: 1.2,
                child: Builder(
                  builder: (context) {
                    scaled = MediaQuery.textScalerOf(context).scale(10);
                    return const SizedBox();
                  },
                ),
              ),
              NotoTextScale(
                scale: 1,
                child: Builder(
                  builder: (context) {
                    plain = MediaQuery.textScalerOf(context).scale(10);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      );
      expect(scaled, closeTo(18, .0001));
      expect(plain, closeTo(15, .0001));
    });

    Future<void> boot(WidgetTester tester) async {
      await tester.pumpWidget(const NotoApp());
      for (var i = 0; i < 40; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(HomeShell).evaluate().isNotEmpty) break;
      }
    }

    testWidgets('o app inteiro usa uiScale', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboardingDone': true,
        'notoVioletBrandMigrated': true,
        'uiScale': 1.2,
      });
      await boot(tester);
      expect(find.byType(HomeShell), findsOneWidget);
      final context = tester.element(find.byType(HomeShell));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(12, .0001));
      await tester.pumpWidget(const SizedBox());
    });

    for (final (scale, compact, extent) in [
      (1.0, false, 224.0),
      (1.0, true, 168.0),
      (1.2, false, 224.0 * 1.2),
    ]) {
      testWidgets('altura dos cards com letras $scale (compactos: $compact)', (
        tester,
      ) async {
        await openHome(
          tester,
          notes: [
            Note(id: 'a', title: 'A', body: 'x', updatedAt: DateTime(2026)),
          ],
          setup: (store) => store
            ..uiScale = scale
            ..compactCards = compact,
        );
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.mainAxisExtent, closeTo(extent, .001));
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('padrão 1.0 não muda nada', (tester) async {
      SharedPreferences.setMockInitialValues({
        'onboardingDone': true,
        'notoVioletBrandMigrated': true,
      });
      await boot(tester);
      final context = tester.element(find.byType(HomeShell));
      expect(MediaQuery.textScalerOf(context).scale(10), closeTo(10, .0001));
      expect(find.byType(NotoTextScale), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('F1: timer de foco', () {
    Future<AppStore> openTimer(
      WidgetTester tester, {
      DateTime? endsAt,
    }) async {
      screen(tester);
      final store = AppStore()..loaded = true;
      store.focusEndsAt = endsAt;
      await tester.pumpWidget(
        MaterialApp(home: FocusTimerPage(store: store)),
      );
      await tester.pump();
      return store;
    }

    testWidgets('Começar salva o fim, Pausar e Continuar, Parar limpa', (
      tester,
    ) async {
      final store = await openTimer(tester);
      expect(find.text('Timer de foco'), findsOneWidget);
      for (final label in ['15 min', '25 min', '45 min', '60 min']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(find.text('25:00'), findsOneWidget);
      await tester.tap(find.text('45 min'));
      await tester.pumpAndSettle();
      expect(store.focusMinutes, 45);
      expect(find.text('45:00'), findsOneWidget);

      final before = DateTime.now();
      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();
      expect(store.focusEndsAt, isNotNull);
      expect(
        store.focusEndsAt!.difference(before).inMinutes,
        inInclusiveRange(44, 45),
      );
      expect(find.text('Pausar'), findsOneWidget);
      expect(find.text('Parar'), findsOneWidget);
      expect(find.text('Começar'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('focusEndsAt'), isNotNull);

      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();
      expect(store.focusEndsAt, isNull);
      expect(find.text('Continuar'), findsOneWidget);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(store.focusEndsAt, isNotNull);

      await tester.tap(find.text('Parar'));
      await tester.pumpAndSettle();
      expect(store.focusEndsAt, isNull);
      expect(find.text('Começar'), findsOneWidget);
      expect(prefs.getString('focusEndsAt'), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sair e voltar mostra o tempo que falta', (tester) async {
      await openTimer(
        tester,
        endsAt: DateTime.now().add(const Duration(minutes: 10)),
      );
      expect(find.textContaining(RegExp(r'^(10:00|09:5\d)$')), findsOneWidget);
      expect(find.text('Pausar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('terminou com a tela fechada: volta ao começo', (tester) async {
      final store = await openTimer(
        tester,
        endsAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(store.focusEndsAt, isNull);
      expect(find.text('Começar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chegando a zero, avisa e limpa', (tester) async {
      final store = await openTimer(
        tester,
        endsAt: DateTime.now().add(const Duration(milliseconds: 300)),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text(focusDoneMessage), findsOneWidget);
      expect(store.focusEndsAt, isNull);
      await tester.tap(find.text('Ok'));
      await tester.pumpAndSettle();
      expect(find.text('Começar'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    test('relógio mm:ss', () {
      expect(focusClock(const Duration(minutes: 25)), '25:00');
      expect(focusClock(const Duration(seconds: 61, milliseconds: 200)), '01:02');
      expect(focusClock(const Duration(seconds: -5)), '00:00');
    });

    testWidgets('Menu tem o Foco, com os minutos que faltam', (tester) async {
      await openHome(
        tester,
        setup: (store) => store.focusEndsAt = DateTime.now().add(
          const Duration(minutes: 9, seconds: 30),
        ),
      );
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Foco')), findsOneWidget);
      expect(inSheet(find.text('10 min')), findsOneWidget);
      await tester.tap(inSheet(find.text('Foco')));
      await tester.pumpAndSettle();
      expect(find.byType(FocusTimerPage), findsOneWidget);
      expect(find.text('Timer de foco'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Menu sem timer rodando: Foco sem selo', (tester) async {
      await openHome(tester);
      await tester.tap(find.byTooltip('Menu'));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Foco')), findsOneWidget);
      expect(inSheet(find.textContaining(' min')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Cards da tela inicial', () {
    Finder gradientInk(int index) => find.byWidgetPredicate(
      (w) =>
          w is Ink &&
          w.decoration is BoxDecoration &&
          (w.decoration! as BoxDecoration).gradient ==
              NotoAppearance.gradientAt(index),
    );

    for (final layout in [0, 1]) {
      testWidgets('degradê no card (${layout == 1 ? 'lista' : 'grade'})', (
        tester,
      ) async {
        await openHome(
          tester,
          notes: [
            Note(
              id: 'g',
              title: 'Noite',
              body: 'estrelas',
              updatedAt: DateTime(2026, 10, 2),
              gradient: 7,
            ),
            Note(
              id: 'p',
              title: 'Pêssego',
              body: 'doce',
              updatedAt: DateTime(2026, 10, 1),
              gradient: 1,
              textColor: 3,
            ),
          ],
          setup: (store) => store.layoutMode = layout,
        );
        expect(gradientInk(7), findsOneWidget);
        expect(gradientInk(1), findsOneWidget);
        final title = tester.widget<Text>(find.text('Noite'));
        expect(title.style?.color, NotoAppearance.gradientTextColor(7));
        expect(title.style?.color, Colors.white);
        // Cor de texto escolhida na nota continua valendo.
        final peach = tester.widget<Text>(find.text('Pêssego'));
        expect(peach.style?.color, NotoAppearance.textColors[3]);
        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('nota sem degradê fica como antes', (tester) async {
      await openHome(
        tester,
        notes: [
          Note(id: 'n', title: 'Comum', body: 'x', updatedAt: DateTime(2026)),
        ],
      );
      final inks = tester.widgetList<Ink>(find.byType(Ink));
      expect(
        inks.any(
          (ink) =>
              ink.decoration is BoxDecoration &&
              (ink.decoration! as BoxDecoration).gradient != null,
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('data completa nos cards', (tester) async {
      final note = Note(
        id: 'd',
        title: 'Datada',
        body: 'x',
        updatedAt: DateTime(2026, 3, 5, 10),
      );
      final store = await openHome(tester, notes: [note]);
      expect(find.textContaining('05/03/2026'), findsNothing);
      expect(find.textContaining('05/03'), findsOneWidget);
      store.cardDateFull = true;
      await store.save();
      await tester.pumpAndSettle();
      expect(find.textContaining('05/03/2026'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('P3: Todas as tarefas', () {
    for (final (style, strike, faded) in [
      (0, true, true),
      (1, false, true),
      (2, true, false),
    ]) {
      testWidgets('tarefas feitas com doneStyle $style', (tester) async {
        screen(tester);
        final store = AppStore()
          ..loaded = true
          ..doneStyle = style;
        store.notes.add(
          Note(
            id: 'l',
            title: 'Lista',
            body: '- [x] feita\n- [ ] pendente',
            updatedAt: DateTime(2026, 10, 1),
            checklist: true,
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: AllTasksPage(store: store, onOpen: (_) async {}),
          ),
        );
        await tester.tap(find.text('Mostrar feitas'));
        await tester.pumpAndSettle();
        final done = tester.widget<Text>(find.text('feita'));
        expect(
          done.style?.decoration == TextDecoration.lineThrough,
          strike,
        );
        expect(done.style?.color != null, faded);
        final pending = tester.widget<Text>(find.text('pendente'));
        expect(pending.style?.decoration, isNull);
        expect(pending.style?.color, isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  });
}
