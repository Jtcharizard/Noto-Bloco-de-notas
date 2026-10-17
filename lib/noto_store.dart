import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_rich_editor.dart';

final notifications = FlutterLocalNotificationsPlugin();

/// Pedidos para abrir uma nota (ex.: toque na notificação de um lembrete).
final noteOpenRequests = StreamController<String>.broadcast();

/// Nota pedida pela notificação que abriu o app do zero.
String? pendingNoteOpen;

class _SavedNoteContent {
  const _SavedNoteContent(this.title, this.body, this.editor);
  final String title;
  final String body;
  final Map<String, dynamic> editor;
}

/// Notas, modelos e histórico ficam num arquivo próprio, gravado com segurança:
/// escreve num temporário, guarda a versão anterior como cópia e só então troca.
class _NoteFiles {
  _NoteFiles(this.dir);
  final Directory dir;

  File get _main => File('${dir.path}/noto_dados.json');
  File get _backup => File('${dir.path}/noto_dados.bak.json');
  File get _temp => File('${dir.path}/noto_dados.tmp');

  static Future<_NoteFiles?> open() async {
    try {
      return _NoteFiles(await getApplicationDocumentsDirectory());
    } catch (_) {
      return null; // Sem acesso a arquivos (ex.: testes): usa as preferências.
    }
  }

  Future<Map<String, dynamic>?> read() async {
    for (final file in [_main, _backup]) {
      try {
        if (!await file.exists()) continue;
        final data = jsonDecode(await file.readAsString());
        if (data is Map && data['notes'] is List) {
          return Map<String, dynamic>.from(data);
        }
      } catch (_) {
        /* Arquivo danificado: tenta a cópia anterior. */
      }
    }
    return null;
  }

  Future<void> write(Map<String, dynamic> data) async {
    await _temp.writeAsString(jsonEncode(data), flush: true);
    if (await _main.exists()) await _main.copy(_backup.path);
    await _temp.rename(_main.path);
  }
}

class AppStore extends ChangeNotifier {
  _NoteFiles? _files;

  final List<Note> notes = [];
  final List<NotoTemplate> templates = [];
  final Map<String, List<NoteRevision>> histories = {};
  final Map<String, _SavedNoteContent> _savedContent = {};

  ThemeMode mode = ThemeMode.system;
  int accent = 0;
  int font = 0;
  double fontSize = 17;
  int layoutMode = 0;
  int wallpaper = 0;
  String? customWallpaper;
  double wallpaperDarkness = .25;
  double wallpaperBlur = 0;
  String? widgetNoteId;
  bool onboardingDone = false;
  bool loaded = false;
  bool homeShowToday = true;
  bool homeShowRecents = true;
  bool _skipRevisionCapture = false;

  // Cofre: só o resumo da senha fica salvo, nunca a senha em si.
  String? vaultPinHash;
  String vaultSalt = '';
  String vaultQuestion = '';
  String? vaultAnswerHash;
  bool get hasVault => vaultPinHash != null;

  final Set<String> seenTips = {};

  DateTime? lastBackupAt;
  DateTime? backupNudgeDismissedAt;

  /// Lembrar de fazer backup: com várias notas e 30 dias sem backup.
  bool get shouldNudgeBackup {
    final now = DateTime.now();
    bool old(DateTime? at) => at == null || now.difference(at).inDays >= 30;
    final active = notes.where((n) => n.deletedAt == null).length;
    return active >= 5 && old(lastBackupAt) && old(backupNudgeDismissedAt);
  }

  /// Devolve true só na primeira vez que a dica é pedida.
  bool takeTip(String id) {
    if (!seenTips.add(id)) return false;
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setStringList('notoSeenTips', seenTips.toList()),
    );
    return true;
  }

  bool get grid => layoutMode == 0;
  set grid(bool value) => layoutMode = value ? 0 : 1;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _files = await _NoteFiles.open();
    final fileData = await _files?.read();

    dynamic decode(String key) {
      final raw = prefs.getString(key);
      if (raw == null) return null;
      try {
        return jsonDecode(raw);
      } catch (_) {
        return null;
      }
    }

    // Versões antigas guardavam tudo nas preferências: migra na primeira vez.
    final notesData = fileData?['notes'] ?? decode('notes');
    final templatesData = fileData?['templates'] ?? decode('notoTemplates');
    final historyData = fileData?['histories'] ?? decode('noteHistories');

    notes.clear();
    if (notesData is List) {
      for (final item in notesData) {
        try {
          notes.add(Note.fromJson(Map<String, dynamic>.from(item as Map)));
        } catch (_) {
          /* Uma nota danificada não impede as outras de abrir. */
        }
      }
    }

    templates.clear();
    if (templatesData is List) {
      for (final item in templatesData) {
        try {
          templates.add(
            NotoTemplate.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        } catch (_) {}
      }
    }

    histories.clear();
    if (historyData is Map) {
      for (final entry in historyData.entries) {
        try {
          final list = (entry.value as List? ?? const [])
              .map(
                (item) => NoteRevision.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
          if (list.isNotEmpty) histories[entry.key.toString()] = list;
        } catch (_) {}
      }
    }

    _savedContent
      ..clear()
      ..addEntries(
        notes.map(
          (note) => MapEntry(
            note.id,
            _SavedNoteContent(note.title, note.body, copyEditor(note.editor)),
          ),
        ),
      );

    final modeIndex = prefs.getInt('mode') ?? 0;
    mode = ThemeMode
        .values[modeIndex.clamp(0, ThemeMode.values.length - 1).toInt()];

    final brandMigrated = prefs.getBool('notoVioletBrandMigrated') ?? false;
    if (!brandMigrated) {
      accent = 0;
      await prefs.setInt('accent', accent);
      await prefs.setBool('notoVioletBrandMigrated', true);
    } else {
      accent = (prefs.getInt('accent') ?? 0)
          .clamp(0, NotoAppearance.accents.length - 1)
          .toInt();
    }

    font = (prefs.getInt('font') ?? 0)
        .clamp(0, NotoAppearance.fonts.length - 1)
        .toInt();
    fontSize = (prefs.getDouble('fontSize') ?? 17).clamp(14, 26).toDouble();
    final oldGrid = prefs.getBool('grid') ?? true;
    layoutMode = (prefs.getInt('layoutMode') ?? (oldGrid ? 0 : 1))
        .clamp(0, 2)
        .toInt();
    wallpaper = (prefs.getInt('wallpaper') ?? 0)
        .clamp(0, NotoAppearance.wallpaperPaths.length - 1)
        .toInt();
    customWallpaper = prefs.getString('customWallpaper');
    wallpaperDarkness = (prefs.getDouble('wallpaperDarkness') ?? .25)
        .clamp(0, .8)
        .toDouble();
    wallpaperBlur = (prefs.getDouble('wallpaperBlur') ?? 0)
        .clamp(0, 16)
        .toDouble();
    widgetNoteId = prefs.getString('widgetNoteId');
    onboardingDone = prefs.getBool('onboardingDone') ?? false;
    lastBackupAt = DateTime.tryParse(prefs.getString('lastBackupAt') ?? '');
    backupNudgeDismissedAt = DateTime.tryParse(
      prefs.getString('backupNudgeDismissedAt') ?? '',
    );
    vaultPinHash = prefs.getString('vaultPinHash');
    vaultSalt = prefs.getString('vaultSalt') ?? '';
    vaultQuestion = prefs.getString('vaultQuestion') ?? '';
    vaultAnswerHash = prefs.getString('vaultAnswerHash');
    seenTips
      ..clear()
      ..addAll(prefs.getStringList('notoSeenTips') ?? const []);
    homeShowToday = prefs.getBool('homeShowToday') ?? true;
    await prefs.remove('homeShowPulse');
    await prefs.remove('editor.focus');

    // Lembretes que já tocaram não ficam pendurados na nota para sempre.
    final now = DateTime.now();
    for (final note in notes) {
      if (note.reminderAt != null &&
          note.reminderRepeat == 0 &&
          note.reminderAt!.isBefore(now)) {
        note.reminderAt = null;
      }
    }
    homeShowRecents = prefs.getBool('homeShowRecents') ?? true;

    // A journal written before the first debounced save can recover a new note.
    for (final key in prefs.getKeys().where(
      (key) => key.startsWith('editor.draft.'),
    )) {
      try {
        final id = key.substring('editor.draft.'.length);
        if (notes.any((note) => note.id == id)) continue;
        final draft = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(key)!) as Map,
        );
        final data = Map<String, dynamic>.from(
          jsonDecode(draft['snapshot'] as String) as Map,
        );
        notes.add(
          Note(
            id: id,
            title: data['title'] as String,
            checklist: data['checklist'] as bool? ?? false,
            body: data['body'] as String,
            updatedAt:
                DateTime.tryParse(draft['at'] as String) ?? DateTime.now(),
            editor: {
              'code': data['code'] ?? [],
              'styles': data['styles'],
              'tables': data['tables'],
              'align': data['align'],
            },
          ),
        );
      } catch (_) {
        /* A damaged journal must not block opening saved notes. */
      }
    }

    // A lixeira se esvazia sozinha: notas apagadas há mais de 30 dias somem.
    final limit = now.subtract(const Duration(days: 30));
    final expired = notes
        .where((n) => n.deletedAt != null && n.deletedAt!.isBefore(limit))
        .toList();
    for (final note in expired) {
      notes.remove(note);
      histories.remove(note.id);
      _savedContent.remove(note.id);
    }

    loaded = true;
    notifyListeners();
  }

  Future<void> _saveQueue = Future<void>.value();

  Future<void> save() {
    final next = _saveQueue.then((_) => _saveNow());
    _saveQueue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _saveNow() async {
    if (_skipRevisionCapture) {
      _skipRevisionCapture = false;
      _refreshSavedContent();
    } else {
      _captureRevisions();
    }

    final prefs = await SharedPreferences.getInstance();
    final notesJson = notes.map((e) => e.toJson()).toList();
    final templatesJson = templates.map((e) => e.toJson()).toList();
    final historiesJson = histories.map(
      (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
    );
    final files = _files;
    var savedToFile = false;
    if (files != null) {
      try {
        await files.write({
          'version': 1,
          'notes': notesJson,
          'templates': templatesJson,
          'histories': historiesJson,
        });
        savedToFile = true;
      } catch (_) {
        /* Se o arquivo falhar, guarda nas preferências para não perder nada. */
      }
    }
    if (savedToFile) {
      for (final key in ['notes', 'notoTemplates', 'noteHistories']) {
        if (prefs.containsKey(key)) await prefs.remove(key);
      }
    } else {
      await prefs.setString('notes', jsonEncode(notesJson));
      await prefs.setString('notoTemplates', jsonEncode(templatesJson));
      await prefs.setString('noteHistories', jsonEncode(historiesJson));
    }
    await prefs.setInt('mode', mode.index);
    await prefs.setInt('accent', accent);
    await prefs.setInt('font', font);
    await prefs.setDouble('fontSize', fontSize);
    await prefs.setInt('layoutMode', layoutMode);
    await prefs.setBool('grid', grid);
    await prefs.setInt('wallpaper', wallpaper);
    if (customWallpaper == null) {
      await prefs.remove('customWallpaper');
    } else {
      await prefs.setString('customWallpaper', customWallpaper!);
    }
    await prefs.setDouble('wallpaperDarkness', wallpaperDarkness);
    await prefs.setDouble('wallpaperBlur', wallpaperBlur);
    if (widgetNoteId == null) {
      await prefs.remove('widgetNoteId');
    } else {
      await prefs.setString('widgetNoteId', widgetNoteId!);
    }
    await prefs.setBool('onboardingDone', onboardingDone);
    for (final entry in {
      'vaultPinHash': vaultPinHash,
      'vaultAnswerHash': vaultAnswerHash,
    }.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value!);
      }
    }
    await prefs.setString('vaultSalt', vaultSalt);
    for (final entry in {
      'lastBackupAt': lastBackupAt,
      'backupNudgeDismissedAt': backupNudgeDismissedAt,
    }.entries) {
      if (entry.value == null) {
        await prefs.remove(entry.key);
      } else {
        await prefs.setString(entry.key, entry.value!.toIso8601String());
      }
    }
    await prefs.setString('vaultQuestion', vaultQuestion);
    await prefs.setBool('homeShowToday', homeShowToday);
    await prefs.setBool('homeShowRecents', homeShowRecents);

    await _syncWidget();
    notifyListeners();
  }

  void _captureRevisions() {
    for (final note in notes) {
      final previous = _savedContent[note.id];
      if (previous != null &&
          (previous.title != note.title ||
              previous.body != note.body ||
              jsonEncode(previous.editor) != jsonEncode(note.editor))) {
        _addRevision(
          note.id,
          NoteRevision(
            title: previous.title,
            body: previous.body,
            editor: copyEditor(previous.editor),
            savedAt: DateTime.now(),
          ),
        );
      }
    }
    _refreshSavedContent();
  }

  void _refreshSavedContent() {
    _savedContent
      ..clear()
      ..addEntries(
        notes.map(
          (note) => MapEntry(
            note.id,
            _SavedNoteContent(note.title, note.body, copyEditor(note.editor)),
          ),
        ),
      );
  }

  void _addRevision(String noteId, NoteRevision revision) {
    final list = histories.putIfAbsent(noteId, () => <NoteRevision>[]);
    if (list.isNotEmpty &&
        list.first.title == revision.title &&
        list.first.body == revision.body &&
        jsonEncode(list.first.editor) == jsonEncode(revision.editor)) {
      return;
    }
    list.insert(0, revision);
    if (list.length > 20) list.removeRange(20, list.length);
  }

  List<NoteRevision> historyFor(Note note) =>
      List.unmodifiable(histories[note.id] ?? const <NoteRevision>[]);

  Future<void> restoreRevision(Note note, NoteRevision revision) async {
    _addRevision(
      note.id,
      NoteRevision(
        title: note.title,
        body: note.body,
        editor: copyEditor(note.editor),
        savedAt: DateTime.now(),
      ),
    );
    note.title = revision.title;
    note.body = revision.body;
    note.editor = copyEditor(revision.editor);
    note.updatedAt = DateTime.now();
    _skipRevisionCapture = true;
    await save();
  }

  Future<void> clearHistory(Note note) async {
    histories.remove(note.id);
    await save();
  }

  Future<void> addTemplateFromNote(Note note, String name) async {
    templates.insert(
      0,
      NotoTemplate(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: name.trim().isEmpty ? 'Modelo' : name.trim(),
        title: note.title,
        body: note.body,
        editor: copyEditor(note.editor),
        checklist: note.checklist,
        emoji: note.emoji,
      ),
    );
    if (templates.length > 30) templates.removeRange(30, templates.length);
    await save();
  }

  Future<void> deleteTemplate(NotoTemplate template) async {
    templates.remove(template);
    await save();
  }

  Note noteFromTemplate(
    NotoTemplate template, {
    String folder = 'Geral',
    List<String> tags = const [],
  }) => Note(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: template.title,
    body: template.body,
    editor: copyEditor(template.editor),
    updatedAt: DateTime.now(),
    checklist: template.checklist,
    emoji: template.emoji,
    folder: folder,
    tags: List.of(tags),
    font: font,
  );

  Future<void> _syncWidget() async {
    final active =
        notes
            .where((n) => n.deletedAt == null && !n.archived && !n.locked)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    Note? selected;
    for (final note in active) {
      if (note.id == widgetNoteId) {
        selected = note;
        break;
      }
    }
    selected ??= active.isEmpty ? null : active.first;

    await HomeWidget.saveWidgetData<String>(
      'note_title',
      selected == null
          ? 'Noto'
          : (displayTitle(selected)),
    );
    await HomeWidget.saveWidgetData<String>(
      'note_body',
      selected == null
          ? 'Toque para criar sua primeira nota'
          : readablePreview(selected.body),
    );
    await HomeWidget.updateWidget(
      name: 'NotoWidgetProvider',
      androidName: 'NotoWidgetProvider',
    );
  }

  static int reminderId(Note note) => note.id.hashCode & 0x7fffffff;
  static int _weekdayReminderId(Note note, int weekday) =>
      ((note.id.hashCode & 0x0fffffff) << 3) | weekday;

  /// Próxima vez que o lembrete toca (para repetidos, a partir de agora).
  DateTime? nextReminder(Note note, {DateTime? from}) {
    final at = note.reminderAt;
    if (at == null) return null;
    final now = from ?? DateTime.now();
    if (note.reminderRepeat == 0 || at.isAfter(now)) return at;
    var day = DateTime(now.year, now.month, now.day, at.hour, at.minute);
    for (var i = 0; i < 8; i++) {
      final candidate = day.add(Duration(days: i));
      if (!candidate.isAfter(now)) continue;
      if (reminderOccursOn(note, candidate)) return candidate;
    }
    return null;
  }

  /// Pede permissão para notificar e, uma vez, para usar horário exato.
  /// Devolve se o horário exato está liberado.
  Future<bool> _prepareNotifications() async {
    try {
      final android = notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android == null) return false;
      final enabled = await android.areNotificationsEnabled() ?? true;
      if (!enabled) await android.requestNotificationsPermission();
      var exact = await android.canScheduleExactNotifications() ?? false;
      if (!exact && takeTip('ask-exact-alarm')) {
        await android.requestExactAlarmsPermission();
        exact = await android.canScheduleExactNotifications() ?? false;
      }
      return exact;
    } catch (_) {
      return false;
    }
  }

  Future<void> scheduleReminder(Note note, DateTime when, int repeat) async {
    await _cancelScheduled(note);
    final exact = await _prepareNotifications();
    note.reminderAt = when;
    note.reminderRepeat = repeat;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'noto_reminders',
        'Lembretes do Noto',
        channelDescription: 'Lembretes marcados nas notas',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final title = note.locked
        ? 'Lembrete do Noto'
        : (note.title.trim().isEmpty ? 'Lembrete do Noto' : note.title.trim());
    final preview = readablePreview(note.body);
    final text = note.locked || preview.isEmpty
        ? 'Você pediu para lembrar desta nota.'
        : preview.split('\n').first;
    Future<void> schedule(int id, DateTime at, DateTimeComponents? match) =>
        notifications.zonedSchedule(
          id,
          title,
          text,
          tz.TZDateTime.from(at, tz.local),
          details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: match,
          payload: note.id,
        );
    try {
      if (repeat == 2) {
        for (var weekday = 1; weekday <= 5; weekday++) {
          var at = DateTime(when.year, when.month, when.day, when.hour, when.minute);
          while (at.weekday != weekday || at.isBefore(DateTime.now())) {
            at = at.add(const Duration(days: 1));
          }
          await schedule(
            _weekdayReminderId(note, weekday),
            at,
            DateTimeComponents.dayOfWeekAndTime,
          );
        }
      } else {
        await schedule(
          reminderId(note),
          when,
          switch (repeat) {
            1 => DateTimeComponents.time,
            3 => DateTimeComponents.dayOfWeekAndTime,
            _ => null,
          },
        );
      }
    } catch (_) {
      /* Sem notificações (ex.: testes): o lembrete fica salvo mesmo assim. */
    }
    await save();
  }

  /// Reagenda com o texto atual (ex.: ao mover para o cofre, esconde o conteúdo).
  Future<void> refreshReminder(Note note) async {
    final next = nextReminder(note);
    if (next == null || !next.isAfter(DateTime.now())) return;
    await scheduleReminder(note, next, note.reminderRepeat);
  }

  Future<void> _cancelScheduled(Note note) async {
    try {
      await notifications.cancel(reminderId(note));
      for (var weekday = 1; weekday <= 5; weekday++) {
        await notifications.cancel(_weekdayReminderId(note, weekday));
      }
    } catch (_) {
      /* Sem notificações nesta plataforma. */
    }
  }

  void cancelReminder(Note note) {
    if (note.reminderAt == null) return;
    note.reminderAt = null;
    note.reminderRepeat = 0;
    _cancelScheduled(note);
  }

  void delete(Note note) {
    cancelReminder(note);
    note.deletedAt = DateTime.now();
    save();
  }

  void restore(Note note) {
    note.deletedAt = null;
    save();
  }

  void emptyTrash() {
    final trashed = notes.where((n) => n.deletedAt != null).toList();
    for (final note in trashed) {
      cancelReminder(note);
      notes.remove(note);
      histories.remove(note.id);
      _savedContent.remove(note.id);
    }
    save();
  }

  void deleteForever(Note note) {
    cancelReminder(note);
    notes.remove(note);
    histories.remove(note.id);
    _savedContent.remove(note.id);
    save();
  }

  void archive(Note note) {
    note.archived = true;
    save();
  }

  void unarchive(Note note) {
    note.archived = false;
    save();
  }

  void togglePin(Note note) {
    note.pinned = !note.pinned;
    note.updatedAt = DateTime.now();
    save();
  }

  Note duplicate(Note note) {
    final copy = Note(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: note.title.trim().isEmpty ? '' : '${note.title} (cópia)',
        body: note.body,
        editor: copyEditor(note.editor),
        updatedAt: DateTime.now(),
        color: note.color,
        wallpaper: note.wallpaper,
        customWallpaper: note.customWallpaper,
        textColor: note.textColor,
        font: note.font,
        titleFont: note.titleFont,
        bodyFont: note.bodyFont,
        favorite: note.favorite,
        locked: note.locked,
        folder: note.folder,
        tags: List.of(note.tags),
        checklist: note.checklist,
        wallpaperDarkness: note.wallpaperDarkness,
        wallpaperBlur: note.wallpaperBlur,
        emoji: note.emoji,
        coverImage: note.coverImage,
        cardOpacity: note.cardOpacity,
        priority: note.priority,
        dueAt: note.dueAt,
      );
    notes.add(copy);
    save();
    return copy;
  }
}
