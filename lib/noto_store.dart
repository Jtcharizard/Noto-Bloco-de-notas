import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_features.dart';
import 'noto_models.dart';

final notifications = FlutterLocalNotificationsPlugin();

class _SavedNoteContent {
  const _SavedNoteContent(this.title, this.body);
  final String title;
  final String body;
}

class AppStore extends ChangeNotifier {
  final List<Note> notes = [];
  final Map<String, List<NoteRevision>> histories = {};
  final Map<String, _SavedNoteContent> _savedContent = {};

  ThemeMode mode = ThemeMode.system;
  int accent = 9;
  int font = 0;
  double fontSize = 17;

  /// 0 = grade, 1 = lista, 2 = compacta.
  int layoutMode = 0;

  int wallpaper = 0;
  String? customWallpaper;
  double wallpaperDarkness = .25;
  double wallpaperBlur = 0;
  String? widgetNoteId;
  bool onboardingDone = false;
  bool loaded = false;

  bool homeShowToday = true;
  bool homeShowPulse = true;
  bool homeShowRecents = true;

  bool _skipRevisionCapture = false;

  bool get grid => layoutMode == 0;
  set grid(bool value) => layoutMode = value ? 0 : 1;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notes');
    if (raw != null) {
      try {
        notes
          ..clear()
          ..addAll((jsonDecode(raw) as List).map(
            (e) => Note.fromJson(Map<String, dynamic>.from(e)),
          ));
      } catch (_) {}
    }

    histories.clear();
    final historyRaw = prefs.getString('noteHistories');
    if (historyRaw != null) {
      try {
        final decoded = Map<String, dynamic>.from(jsonDecode(historyRaw));
        for (final entry in decoded.entries) {
          final list = (entry.value as List? ?? const [])
              .map((item) => NoteRevision.fromJson(Map<String, dynamic>.from(item)))
              .toList();
          if (list.isNotEmpty) histories[entry.key] = list;
        }
      } catch (_) {}
    }

    _savedContent
      ..clear()
      ..addEntries(notes.map(
        (note) => MapEntry(note.id, _SavedNoteContent(note.title, note.body)),
      ));

    final modeIndex = prefs.getInt('mode') ?? 0;
    mode = ThemeMode.values[
      modeIndex.clamp(0, ThemeMode.values.length - 1).toInt()
    ];

    final brandMigrated = prefs.getBool('notoBrandMigrated') ?? false;
    if (!brandMigrated) {
      accent = 9;
      await prefs.setInt('accent', accent);
      await prefs.setBool('notoBrandMigrated', true);
    } else {
      accent = (prefs.getInt('accent') ?? 9)
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
    wallpaperDarkness =
        (prefs.getDouble('wallpaperDarkness') ?? .25).clamp(0, .8).toDouble();
    wallpaperBlur =
        (prefs.getDouble('wallpaperBlur') ?? 0).clamp(0, 16).toDouble();
    widgetNoteId = prefs.getString('widgetNoteId');
    onboardingDone = prefs.getBool('onboardingDone') ?? false;

    homeShowToday = prefs.getBool('homeShowToday') ?? true;
    homeShowPulse = prefs.getBool('homeShowPulse') ?? true;
    homeShowRecents = prefs.getBool('homeShowRecents') ?? true;

    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    if (_skipRevisionCapture) {
      _skipRevisionCapture = false;
      _refreshSavedContent();
    } else {
      _captureRevisions();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'notes',
      jsonEncode(notes.map((e) => e.toJson()).toList()),
    );
    await prefs.setString(
      'noteHistories',
      jsonEncode(histories.map(
        (key, value) => MapEntry(key, value.map((e) => e.toJson()).toList()),
      )),
    );
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
    await prefs.setBool('homeShowToday', homeShowToday);
    await prefs.setBool('homeShowPulse', homeShowPulse);
    await prefs.setBool('homeShowRecents', homeShowRecents);

    await _syncWidget();
    notifyListeners();
  }

  void _captureRevisions() {
    for (final note in notes) {
      final previous = _savedContent[note.id];
      if (previous != null &&
          (previous.title != note.title || previous.body != note.body)) {
        _addRevision(
          note.id,
          NoteRevision(
            title: previous.title,
            body: previous.body,
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
      ..addEntries(notes.map(
        (note) => MapEntry(note.id, _SavedNoteContent(note.title, note.body)),
      ));
  }

  void _addRevision(String noteId, NoteRevision revision) {
    final list = histories.putIfAbsent(noteId, () => <NoteRevision>[]);
    if (list.isNotEmpty &&
        list.first.title == revision.title &&
        list.first.body == revision.body) {
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
        savedAt: DateTime.now(),
      ),
    );
    note.title = revision.title;
    note.body = revision.body;
    note.updatedAt = DateTime.now();
    _skipRevisionCapture = true;
    await save();
  }

  Future<void> clearHistory(Note note) async {
    histories.remove(note.id);
    await save();
  }

  Future<void> _syncWidget() async {
    final active = notes.where((n) => n.deletedAt == null && !n.archived).toList()
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
          : (selected.title.trim().isEmpty ? 'Sem título' : selected.title),
    );
    await HomeWidget.saveWidgetData<String>(
      'note_body',
      selected == null
          ? 'Toca para criar tua primeira nota'
          : selected.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'),
    );
    await HomeWidget.updateWidget(
      name: 'NotoWidgetProvider',
      androidName: 'NotoWidgetProvider',
    );
  }

  void delete(Note note) {
    note.deletedAt = DateTime.now();
    save();
  }

  void restore(Note note) {
    note.deletedAt = null;
    save();
  }

  void deleteForever(Note note) {
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

  void duplicate(Note note) {
    notes.add(Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: '${note.title} — cópia',
      body: note.body,
      updatedAt: DateTime.now(),
      color: note.color,
      wallpaper: note.wallpaper,
      customWallpaper: note.customWallpaper,
      textColor: note.textColor,
      font: note.font,
      favorite: note.favorite,
      folder: note.folder,
      tags: List.of(note.tags),
      checklist: note.checklist,
      wallpaperDarkness: note.wallpaperDarkness,
      wallpaperBlur: note.wallpaperBlur,
    ));
    save();
  }
}
