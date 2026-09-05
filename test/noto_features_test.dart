import 'package:bloco_personalizavel/noto_features.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Note note(String id, String title, String body, {String folder = 'Geral', bool checklist = false}) {
    return Note(
      id: id,
      title: title,
      body: body,
      folder: folder,
      checklist: checklist,
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  test('extrai links wiki sem duplicar', () {
    expect(
      extractWikiLinks('Ver [[Projeto]] e [[Ideias]]. Depois [[projeto]].'),
      ['Projeto', 'Ideias'],
    );
  });

  test('encontra backlinks pelo título da nota', () {
    final target = note('1', 'Projeto', 'principal');
    final source = note('2', 'Ideias', 'Ligar com [[Projeto]]');
    final other = note('3', 'Solta', 'Nada aqui');

    expect(backlinksFor(target, [target, source, other]), [source]);
  });

  test('Pulse detecta checklist pendente e pasta dominante', () {
    final notes = [
      note('1', 'A', '[ ] Fazer', folder: 'Escola', checklist: true),
      note('2', 'B', 'Texto', folder: 'Escola'),
      note('3', 'C', '[[A]]', folder: 'Geral'),
    ];

    final insights = buildPulseInsights(notes, now: DateTime(2026, 9, 5));
    expect(insights.any((item) => item.kind == PulseKind.checklist), isTrue);
    expect(insights.any((item) => item.kind == PulseKind.folder), isTrue);
    expect(insights.any((item) => item.kind == PulseKind.links), isTrue);
  });
}
