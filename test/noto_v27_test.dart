import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:bloco_personalizavel/noto_tasks.dart';
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

  testWidgets('todas as tarefas: marca direto na nota certa', (tester) async {
    final store = AppStore()..loaded = true;
    store.notes.addAll([
      Note(
        id: 'a',
        title: 'Mercado',
        body: '- [ ] leite\n- [x] pão\n- [ ] ovos',
        updatedAt: DateTime(2026, 10, 1),
        checklist: true,
      ),
      Note(
        id: 'b',
        title: 'Segredo',
        body: '- [ ] não aparece',
        updatedAt: DateTime(2026, 10, 1),
        locked: true,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AllTasksPage(store: store, onOpen: (_) async {}),
      ),
    );
    expect(find.text('leite'), findsOneWidget);
    expect(find.text('ovos'), findsOneWidget);
    expect(find.text('pão'), findsNothing);
    expect(find.text('não aparece'), findsNothing);

    await tester.tap(find.text('ovos'));
    await tester.pump();
    expect(store.notes.first.body, '- [ ] leite\n- [x] pão\n- [x] ovos');
    await tester.pumpWidget(const SizedBox());
  });
}
