import 'package:bloco_personalizavel/noto_features.dart';
import 'package:bloco_personalizavel/noto_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resume o dia sem contar notas arquivadas', () {
    final now = DateTime(2026, 9, 5, 20);
    final notes = [
      Note(
        id: '1',
        title: 'Hoje',
        body: '[ ] A\n[x] B\n[ ] C',
        updatedAt: DateTime(2026, 9, 5, 12),
        checklist: true,
        reminderAt: DateTime(2026, 9, 5, 21),
      ),
      Note(
        id: '2',
        title: 'Atrasada',
        body: '',
        updatedAt: DateTime(2026, 9, 1),
        reminderAt: DateTime(2026, 9, 4, 18),
      ),
      Note(
        id: '3',
        title: 'Arquivada',
        body: '[ ] Não contar',
        updatedAt: DateTime(2026, 9, 5),
        checklist: true,
        archived: true,
      ),
    ];

    final snapshot = buildTodaySnapshot(notes, now: now);
    expect(snapshot.touched, 1);
    expect(snapshot.pendingTasks, 2);
    expect(snapshot.remindersToday, 1);
    expect(snapshot.overdueReminders, 1);
  });
}
