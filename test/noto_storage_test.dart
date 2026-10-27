import 'dart:convert';
import 'dart:io';

import 'package:bloco_personalizavel/noto_models.dart';
import 'package:bloco_personalizavel/noto_store.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePaths extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePaths(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

Map<String, dynamic> _note(String id, String body) => {
  'id': id,
  'title': 'Nota $id',
  'body': body,
  'updatedAt': '2026-10-01T10:00:00.000',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('noto_teste_');
    PathProviderPlatform.instance = _FakePaths(dir.path);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (_) async => true,
        );
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('migra as notas antigas para o arquivo e não perde nada', () async {
    SharedPreferences.setMockInitialValues({
      'notes': jsonEncode([_note('1', 'antiga')]),
    });
    final store = AppStore();
    await store.load();
    expect(store.notes.single.body, 'antiga');

    await store.save();
    expect(File('${dir.path}/noto_dados.json').existsSync(), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('notes'), isNull);

    final reopened = AppStore();
    await reopened.load();
    expect(reopened.notes.single.body, 'antiga');
  });

  test('arquivo danificado usa a cópia anterior', () async {
    SharedPreferences.setMockInitialValues({});
    File('${dir.path}/noto_dados.json').writeAsStringSync('{quebrado');
    File('${dir.path}/noto_dados.bak.json').writeAsStringSync(
      jsonEncode({
        'version': 1,
        'notes': [_note('2', 'da cópia')],
      }),
    );
    final store = AppStore();
    await store.load();
    expect(store.notes.single.body, 'da cópia');
  });

  test('cada gravação guarda a versão anterior como cópia', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.load();
    store.notes.add(
      Note.fromJson(_note('3', 'primeira')),
    );
    await store.save();
    store.notes.first.body = 'segunda';
    await store.save();
    final backup = jsonDecode(
      File('${dir.path}/noto_dados.bak.json').readAsStringSync(),
    );
    expect((backup['notes'] as List).first['body'], 'primeira');
  });
}
