import 'package:bloco_personalizavel/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializa e recupera uma nota', () {
    final note = Note(id: '1', title: 'Teste', body: 'Texto', updatedAt: DateTime(2026));
    final copy = Note.fromJson(note.toJson());
    expect(copy.title, 'Teste');
    expect(copy.body, 'Texto');
  });
}
