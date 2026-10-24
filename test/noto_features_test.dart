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

  test('conta tarefas nos formatos antigo e novo', () {
    const body = '[ ] Antiga\n- [ ] Nova\n- [x] Feita\nTexto solto';
    expect(hasTaskLines(body), isTrue);
    expect(countPendingTasks(body), 2);
    expect(countDoneTasks(body), 1);
    expect(hasTaskLines('Só texto'), isFalse);
  });

  test('prévia legível sem marcações cruas', () {
    expect(
      readablePreview('## Mercado\n- [ ] Leite\n- [x] Pão\n- Ovos'),
      'Mercado\n☐ Leite\n☑ Pão\n• Ovos',
    );
  });
}
