import 'dart:convert';

import 'package:bloco_personalizavel/noto_app.dart';
import 'package:bloco_personalizavel/noto_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Abre o app inteiro como no celular e confere que sai da tela de carregamento.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <String>[];

  setUp(() {
    calls.clear();
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
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add('$name.${call.method}');
        return null;
      });
    }
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

  testWidgets('abre direto num celular que já usava o app', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboardingDone': true,
      'notoVioletBrandMigrated': true,
      'accent': 3,
      'notes': jsonEncode([
        {
          'id': '1',
          'title': 'Mercado',
          'body': '- [ ] leite\n- [x] pão',
          'updatedAt': '2026-10-10T10:00:00.000',
          'checklist': true,
          'dueAt': '2026-10-01T00:00:00.000',
          'reminderAt': '2030-10-01T09:00:00.000',
        },
        {
          'id': '2',
          'title': '',
          'body': 'Sem título aqui',
          'updatedAt': '2026-10-11T10:00:00.000',
          'locked': true,
        },
      ]),
    });
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(
      find.byType(HomeShell),
      findsOneWidget,
      reason: 'App ficou preso no carregamento. Chamadas: $calls',
    );
    expect(find.text('Mercado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('primeira abertura mostra o tutorial', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await boot(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('Pular'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
