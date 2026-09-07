import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bloco_personalizavel/noto_theme.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:bloco_personalizavel/noto_code_block.dart';
import 'package:bloco_personalizavel/noto_editor.dart';

void main() {
  testWidgets('navigation area stays separated from bottom controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => NotoSafeFrame(child: child!),
        home: const Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(key: Key('bar'), height: 48, width: 200),
          ),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const Key('bar'))).bottom,
      lessThanOrEqualTo(808),
    );
  });
  test('tonal buttons and containers follow the selected theme', () {
    final store = AppStore();
    final purple = notoTheme(store, Brightness.light).colorScheme;
    store.accent = 2;
    final blue = notoTheme(store, Brightness.light).colorScheme;
    expect(purple.primaryContainer, isNot(blue.primaryContainer));
    expect(purple.secondaryContainer, isNot(blue.secondaryContainer));
  });
  testWidgets('markdown checklist items display working checkboxes', (
    tester,
  ) async {
    final c = TextEditingController(text: '- [ ] Comprar\n- [x] Feito');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistEditor(
            controller: c,
            family: null,
            fontSize: 17,
            textColor: null,
            onChanged: () {},
          ),
        ),
      ),
    );
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
      tester
          .widget<CheckboxListTile>(find.byType(CheckboxListTile).at(1))
          .value,
      isTrue,
    );
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    expect(c.text, contains('[x] Comprar'));
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  testWidgets(
    'code panel edits without smart punctuation and retains language',
    (tester) async {
      final data = <String, dynamic>{
        'text': 'print(1)',
        'language': 'python',
        'wrap': false,
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NotoCodeBlock(
                data: data,
                onChanged: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      final field = find.byType(TextField);
      expect(tester.widget<TextField>(field).autocorrect, isFalse);
      await tester.enterText(field, 'print(2)\nprint(3)');
      await tester.pump();
      expect(data['text'], 'print(2)\nprint(3)');
      expect(find.text('2 linhas'), findsOneWidget);
      expect(data['language'], 'python');
    },
  );
}
