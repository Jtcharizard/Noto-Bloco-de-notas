import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_models.dart';

final notifications = FlutterLocalNotificationsPlugin();

class AppStore extends ChangeNotifier {
  final List<Note> notes = [];
  ThemeMode mode = ThemeMode.system;
  int accent = 0;
  int font = 0;
  double fontSize = 17;
  bool grid = true;
  int wallpaper = 0;
  String? customWallpaper;
  double wallpaperDarkness = .25;
  double wallpaperBlur = 0;
  String? widgetNoteId;
  bool onboardingDone = false;
  bool loaded = false;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notes');
    if (raw != null) {
      try {
        notes
          ..clear()
          ..addAll((jsonDecode(raw) as List).map((e) => Note.fromJson(Map<String, dynamic>.from(e))));
      } catch (_) {}
    }

    final modeIndex = prefs.getInt('mode') ?? 0;
    mode = ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1).toInt()];
    accent = (prefs.getInt('accent') ?? 0).clamp(0, NotoAppearance.accents.length - 1).toInt();
    font = (prefs.getInt('font') ?? 0).clamp(0, NotoAppearance.fonts.length - 1).toInt();
    fontSize = (prefs.getDouble('fontSize') ?? 17).clamp(14, 26).toDouble();
    grid = prefs.getBool('grid') ?? true;
    wallpaper = (prefs.getInt('wallpaper') ?? 0).clamp(0, NotoAppearance.wallpaperPaths.length - 1).toInt();
    customWallpaper = prefs.getString('customWallpaper');
    wallpaperDarkness = (prefs.getDouble('wallpaperDarkness') ?? .25).clamp(0, .8).toDouble();
    wallpaperBlur = (prefs.getDouble('wallpaperBlur') ?? 0).clamp(0, 16).toDouble();
    widgetNoteId = prefs.getString('widgetNoteId');
    onboardingDone = prefs.getBool('onboardingDone') ?? false;
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notes', jsonEncode(notes.map((e) => e.toJson()).toList()));
    await prefs.setInt('mode', mode.index);
    await prefs.setInt('accent', accent);
    await prefs.setInt('font', font);
    await prefs.setDouble('fontSize', fontSize);
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

    await _syncWidget();
    notifyListeners();
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
      selected == null ? 'Noto' : (selected.title.trim().isEmpty ? 'Sem título' : selected.title),
    );
    await HomeWidget.saveWidgetData<String>(
      'note_body',
      selected == null
          ? 'Toca para criar tua primeira nota'
          : selected.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'),
    );
    await HomeWidget.updateWidget(name: 'NotoWidgetProvider', androidName: 'NotoWidgetProvider');
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
