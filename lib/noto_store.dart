import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_rich_editor.dart';
import 'noto_smart.dart';

final notifications = FlutterLocalNotificationsPlugin();

/// Pedidos para abrir uma nota (ex.: toque na notificação de um lembrete).
final noteOpenRequests = StreamController<String>.broadcast();

/// Nota pedida pela notificação que abriu o app do zero.
String? pendingNoteOpen;

/// Pedidos de "Adiar" vindos da notificação: (id da nota, minutos).
final snoozeRequests = StreamController<(String, int)>.broadcast();

/// Adiar pedido pela notificação que abriu o app do zero.
(String, int)? pendingSnooze;

/// Ações que aparecem na notificação de lembrete.
const reminderActions = <AndroidNotificationAction>[
  AndroidNotificationAction('adiar10', 'Adiar 10 min', showsUserInterface: true),
  AndroidNotificationAction('adiar60', 'Adiar 1 hora', showsUserInterface: true),
];

/// Lê a resposta de uma notificação: abrir a nota ou adiar o lembrete.
void handleNotificationResponse(NotificationResponse response) {
  final id = response.payload;
  if (id == null || id.isEmpty) return;
  final minutes = switch (response.actionId) {
    'adiar10' => 10,
    'adiar60' => 60,
    _ => 0,
  };
  if (minutes > 0) {
    snoozeRequests.add((id, minutes));
  } else {
    noteOpenRequests.add(id);
  }
}

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

  // Personalização
  bool pureBlack = false;
  int cardRadius = 16;
  int gridColumns = 2;
  int previewLines = 4;
  bool cardShowFolder = true;
  bool cardShowDate = true;
  bool cardShowTags = true;
  double editorLineHeight = 1.6;
  String homeTitle = '';

  /// O que o botão + faz: 0 = perguntar, 1 = nota em branco, 2 = lista de tarefas.
  int plusAction = 0;

  /// O que deslizar o card faz: 0 arquivar, 1 lixeira, 2 fixar, 3 favoritar, 4 nada.
  int swipeRight = 0;
  int swipeLeft = 1;

  /// Cards mais baixos, para caber mais notas na tela.
  bool compactCards = false;

  /// Mostra os atalhos de pastas e filtros rápidos na tela inicial.
  bool showFolderChips = true;

  /// Pastas fixadas no começo dos atalhos.
  final List<String> pinnedFolders = [];

  /// Calendário mostra só prazos e lembretes (sem "editada neste dia").
  bool calendarOnlyDated = false;

  /// Senhas erradas desde a última vez que o cofre foi aberto.
  int vaultWrongSinceOpen = 0;
  DateTime? vaultLastWrongAt;

  /// Cor das notas novas (índice em NotoAppearance.noteColors; 0 = sem cor).
  int newNoteColor = 0;

  /// Mostra a barra Arquivadas · Lixeira · Pastas · Tags no topo.
  bool showShortcutsBar = true;

  /// Últimas buscas feitas (mais recente primeiro).
  final List<String> recentSearches = [];

  void rememberSearch(String query) {
    final clean = query.trim();
    if (clean.length < 2) return;
    recentSearches
      ..removeWhere((item) => item.toLowerCase() == clean.toLowerCase())
      ..insert(0, clean);
    if (recentSearches.length > 6) recentSearches.removeRange(6, recentSearches.length);
    save();
  }

  /// Nota fixada na barra de notificações (null = nenhuma).
  String? pinnedNotificationNoteId;

  /// Quantas telas do cofre estão abertas agora (para bloquear ao sair do app).
  int vaultScreensOpen = 0;

  /// Segundos fora do app até o cofre pedir a senha de novo (0 = na hora).
  int vaultLockSeconds = 30;

  /// Senhas erradas seguidas e até quando esperar para tentar de novo.
  int vaultFailedAttempts = 0;
  DateTime? vaultBlockedUntil;

  static const _secureChannel = MethodChannel('noto/share');

  void vaultScreenOpened() {
    vaultScreensOpen++;
    if (vaultScreensOpen == 1) {
      _secureChannel.invokeMethod('setSecure', true).catchError((Object _) {});
    }
  }

  void vaultScreenClosed() {
    vaultScreensOpen = (vaultScreensOpen - 1).clamp(0, 999).toInt();
    if (vaultScreensOpen == 0) {
      _secureChannel.invokeMethod('setSecure', false).catchError((Object _) {});
    }
  }

  /// Registra uma tentativa de senha. Depois de 5 erros, espera 30 segundos.
  void registerVaultAttempt(bool ok) {
    if (ok) {
      vaultFailedAttempts = 0;
      vaultBlockedUntil = null;
      return;
    }
    vaultWrongSinceOpen++;
    vaultLastWrongAt = DateTime.now();
    save();
    vaultFailedAttempts++;
    if (vaultFailedAttempts >= 5) {
      vaultFailedAttempts = 0;
      vaultBlockedUntil = DateTime.now().add(const Duration(seconds: 30));
    }
  }

  /// Segundos que ainda faltam para poder tentar a senha (0 = pode tentar).
  int get vaultWaitSeconds {
    final until = vaultBlockedUntil;
    if (until == null) return 0;
    final left = until.difference(DateTime.now()).inSeconds;
    return left > 0 ? left + 1 : 0;
  }
  bool vaultLockRequested = false;

  void requestVaultLock() {
    if (vaultScreensOpen <= 0 || !hasVault) return;
    vaultLockRequested = true;
    notifyListeners();
  }

  void releaseVaultLock() {
    vaultLockRequested = false;
    notifyListeners();
  }
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
    pureBlack = prefs.getBool('pureBlack') ?? false;
    cardRadius = (prefs.getInt('cardRadius') ?? 16).clamp(0, 28).toInt();
    gridColumns = (prefs.getInt('gridColumns') ?? 2).clamp(2, 3).toInt();
    previewLines = (prefs.getInt('previewLines') ?? 4).clamp(0, 8).toInt();
    cardShowFolder = prefs.getBool('cardShowFolder') ?? true;
    cardShowDate = prefs.getBool('cardShowDate') ?? true;
    cardShowTags = prefs.getBool('cardShowTags') ?? true;
    editorLineHeight = (prefs.getDouble('editorLineHeight') ?? 1.6)
        .clamp(1.2, 2.2)
        .toDouble();
    homeTitle = prefs.getString('homeTitle') ?? '';
    plusAction = (prefs.getInt('plusAction') ?? 0).clamp(0, 2).toInt();
    swipeRight = (prefs.getInt('swipeRight') ?? 0).clamp(0, 4).toInt();
    swipeLeft = (prefs.getInt('swipeLeft') ?? 1).clamp(0, 4).toInt();
    compactCards = prefs.getBool('compactCards') ?? false;
    showFolderChips = prefs.getBool('showFolderChips') ?? true;
    pinnedFolders
      ..clear()
      ..addAll(prefs.getStringList('pinnedFolders') ?? const []);
    calendarOnlyDated = prefs.getBool('calendarOnlyDated') ?? false;
    vaultWrongSinceOpen = prefs.getInt('vaultWrongSinceOpen') ?? 0;
    vaultLastWrongAt = DateTime.tryParse(prefs.getString('vaultLastWrongAt') ?? '');
    newNoteColor = (prefs.getInt('newNoteColor') ?? 0)
        .clamp(0, NotoAppearance.noteColors.length - 1)
        .toInt();
    showShortcutsBar = prefs.getBool('showShortcutsBar') ?? false;
    // 2.8: Arquivadas, Lixeira, Pastas e Tags agora ficam no menu da tela
    // inicial. A barra antiga some uma vez; dá para ligar de novo nos Ajustes.
    if (prefs.getBool('menuUnificado28') != true) {
      showShortcutsBar = false;
      await prefs.setBool('menuUnificado28', true);
    }
    recentSearches
      ..clear()
      ..addAll(prefs.getStringList('recentSearches') ?? const []);
    vaultLockSeconds = (prefs.getInt('vaultLockSeconds') ?? 30).clamp(0, 3600).toInt();
    pinnedNotificationNoteId = prefs.getString('pinnedNotificationNoteId');
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
    await prefs.remove('homeShowRecents');

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
    runDailyResets();
  }

  /// Desmarca as listas de rotina quando o dia vira.
  void runDailyResets() {
    if (!loaded) return;
    if (applyDailyResets(notes, DateTime.now())) {
      notifyListeners();
      unawaited(save());
    }
  }

  Future<void> _saveQueue = Future<void>.value();

  Future<void> save() {
    // Nunca grava antes de ler: se a leitura falhou, gravar apagaria as notas.
    if (!loaded) return Future<void>.value();
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
    await prefs.setBool('pureBlack', pureBlack);
    await prefs.setInt('cardRadius', cardRadius);
    await prefs.setInt('gridColumns', gridColumns);
    await prefs.setInt('previewLines', previewLines);
    await prefs.setBool('cardShowFolder', cardShowFolder);
    await prefs.setBool('cardShowDate', cardShowDate);
    await prefs.setBool('cardShowTags', cardShowTags);
    await prefs.setDouble('editorLineHeight', editorLineHeight);
    await prefs.setString('homeTitle', homeTitle);
    await prefs.setInt('plusAction', plusAction);
    await prefs.setInt('swipeRight', swipeRight);
    await prefs.setInt('swipeLeft', swipeLeft);
    await prefs.setBool('compactCards', compactCards);
    await prefs.setBool('showFolderChips', showFolderChips);
    await prefs.setStringList('pinnedFolders', pinnedFolders);
    await prefs.setBool('calendarOnlyDated', calendarOnlyDated);
    await prefs.setInt('vaultWrongSinceOpen', vaultWrongSinceOpen);
    if (vaultLastWrongAt == null) {
      await prefs.remove('vaultLastWrongAt');
    } else {
      await prefs.setString('vaultLastWrongAt', vaultLastWrongAt!.toIso8601String());
    }
    await prefs.setInt('newNoteColor', newNoteColor);
    await prefs.setBool('showShortcutsBar', showShortcutsBar);
    await prefs.setStringList('recentSearches', recentSearches);
    await prefs.setInt('vaultLockSeconds', vaultLockSeconds);
    if (pinnedNotificationNoteId == null) {
      await prefs.remove('pinnedNotificationNoteId');
    } else {
      await prefs.setString(
        'pinnedNotificationNoteId',
        pinnedNotificationNoteId!,
      );
    }

    await _syncWidget();
    await _refreshPinnedNotification();
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

    final pending = selected == null ? 0 : countPendingTasks(selected.body);
    await HomeWidget.saveWidgetData<String>(
      'note_title',
      selected == null
          ? 'Noto'
          : pending > 0
          ? '${displayTitle(selected)} · $pending a fazer'
          : displayTitle(selected),
    );
    await HomeWidget.saveWidgetData<String>(
      'note_body',
      selected == null
          ? 'Toque para criar sua primeira nota'
          : readablePreview(selected.body),
    );
    await HomeWidget.saveWidgetData<String>('note_id', selected?.id ?? '');
    await HomeWidget.updateWidget(
      name: 'NotoWidgetProvider',
      androidName: 'NotoWidgetProvider',
    );

    // Widget 2x2 de resumo: tarefas que faltam e o próximo lembrete.
    final today = buildTodaySnapshot(active);
    (Note, DateTime)? next;
    for (final note in active) {
      final at = nextReminder(note);
      if (at == null || !at.isAfter(DateTime.now())) continue;
      if (next == null || at.isBefore(next.$2)) next = (note, at);
    }
    String nextText = 'Nenhum lembrete marcado';
    if (next != null) {
      final at = next.$2;
      final now = DateTime.now();
      final sameDay =
          at.year == now.year && at.month == now.month && at.day == now.day;
      final hour =
          '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
      final when = sameDay
          ? 'Hoje $hour'
          : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} $hour';
      nextText = '$when · ${displayTitle(next.$1)}';
    }
    await HomeWidget.saveWidgetData<String>(
      'summary_count',
      '${today.pendingTasks}',
    );
    await HomeWidget.saveWidgetData<String>(
      'summary_label',
      today.pendingTasks == 1 ? 'tarefa a fazer' : 'tarefas a fazer',
    );
    await HomeWidget.saveWidgetData<String>('summary_next', nextText);
    await HomeWidget.updateWidget(
      name: 'NotoSummaryWidgetProvider',
      androidName: 'NotoSummaryWidgetProvider',
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
    for (var i = 0; i < (note.reminderRepeat == 4 ? 32 : 8); i++) {
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
        actions: reminderActions,
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
            4 => DateTimeComponents.dayOfMonthAndTime,
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

  static const _pinnedNotificationId = 777001;

  /// Mostra (ou atualiza) a nota fixada na barra de notificações.
  Future<void> showPinnedNotification(Note note) async {
    pinnedNotificationNoteId = note.id;
    await _prepareNotifications();
    await save(); // save() publica a notificação com o texto atual.
  }

  Future<void> hidePinnedNotification() async {
    pinnedNotificationNoteId = null;
    try {
      await notifications.cancel(_pinnedNotificationId);
    } catch (_) {}
    await save();
  }

  /// Mantém a notificação fixada em dia com o texto da nota.
  Future<void> _refreshPinnedNotification() async {
    final id = pinnedNotificationNoteId;
    if (id == null) return;
    Note? note;
    for (final item in notes) {
      if (item.id == id && item.deletedAt == null) note = item;
    }
    if (note == null) {
      pinnedNotificationNoteId = null;
      try {
        await notifications.cancel(_pinnedNotificationId);
      } catch (_) {}
      return;
    }
    final text = note.locked ? 'Nota do cofre' : readablePreview(note.body);
    try {
      await notifications.show(
        _pinnedNotificationId,
        note.locked ? 'Noto' : displayTitle(note),
        text.isEmpty ? 'Toque para abrir' : text,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'noto_pinned',
            'Nota fixada',
            channelDescription: 'Nota que fica na barra de notificações',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            styleInformation: BigTextStyleInformation(text),
          ),
        ),
        payload: note.id,
      );
    } catch (_) {}
  }

  static int _snoozeId(Note note) => (note.id.hashCode & 0x0fffffff) | 0x10000000;

  /// Adia o lembrete: toca de novo daqui a [minutes] minutos (uma vez só).
  Future<DateTime?> snoozeReminder(String noteId, int minutes) async {
    Note? note;
    for (final item in notes) {
      if (item.id == noteId && item.deletedAt == null) note = item;
    }
    if (note == null) return null;
    final at = DateTime.now().add(Duration(minutes: minutes));
    final preview = readablePreview(note.body);
    try {
      await notifications.zonedSchedule(
        _snoozeId(note),
        note.locked ? 'Lembrete do Noto' : displayTitle(note),
        note.locked || preview.isEmpty
            ? 'Você pediu para lembrar desta nota.'
            : preview.split('\n').first,
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'noto_reminders',
            'Lembretes do Noto',
            channelDescription: 'Lembretes marcados nas notas',
            importance: Importance.high,
            priority: Priority.high,
            actions: reminderActions,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: note.id,
      );
    } catch (_) {
      return null;
    }
    return at;
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
