import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'noto_editor.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_rich_editor.dart';
import 'noto_store.dart';

class FontPickerSheet extends StatefulWidget {
  const FontPickerSheet({super.key, required this.selected});
  final int selected;

  @override
  State<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends State<FontPickerSheet> {
  String query = '';
  String preview = 'Minha próxima grande ideia';

  @override
  Widget build(BuildContext context) {
    final visible = List.generate(NotoAppearance.fonts.length, (i) => i)
        .where(
          (i) => NotoAppearance.fonts[i].name.toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fontes',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${NotoAppearance.fonts.length} estilos para escolher',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Pesquisar fonte',
                    ),
                    onChanged: (value) => setState(() => query = value),
                  ),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Texto de exemplo',
                      hintText: 'Minha próxima grande ideia',
                    ),
                    onChanged: (value) => setState(() => preview = value),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: visible.length,
                itemBuilder: (_, position) {
                  final index = visible[position];
                  final font = NotoAppearance.fonts[index];
                  final selected = widget.selected == index;
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    selected: selected,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: .55),
                    title: Text(
                      font.name,
                      style: TextStyle(
                        fontFamily: font.family,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      preview.trim().isEmpty ? font.subtitle : preview,
                      style: TextStyle(fontFamily: font.family),
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle_rounded)
                        : null,
                    onTap: () => Navigator.pop(context, index),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WallpaperSheet extends StatelessWidget {
  const WallpaperSheet({super.key, required this.store, this.note});
  final AppStore store;
  final Note? note;

  Future<void> _pickCustom(BuildContext context) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (picked == null || !context.mounted) return;
    final directory = await getApplicationDocumentsDirectory();
    final saved = await File(picked.path).copy(
      '${directory.path}/noto_wallpaper_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    if (note == null) {
      store.customWallpaper = saved.path;
      store.wallpaper = 0;
    } else {
      note!.customWallpaper = saved.path;
      note!.wallpaper = 0;
    }
    await store.save();
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final selected = note?.wallpaper ?? store.wallpaper;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .66,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note == null ? 'Fundo do aplicativo' : 'Fundo da nota',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _pickCustom(context),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Escolher imagem da galeria'),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 12,
                    childAspectRatio: .78,
                  ),
                  itemCount: NotoAppearance.wallpaperPaths.length,
                  itemBuilder: (_, index) {
                    final isSelected =
                        selected == index &&
                        (note?.customWallpaper ?? store.customWallpaper) ==
                            null;
                    return GestureDetector(
                      onTap: () {
                        if (note == null) {
                          store.wallpaper = index;
                          store.customWallpaper = null;
                        } else {
                          note!.wallpaper = index;
                          note!.customWallpaper = null;
                        }
                        store.save();
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                border: isSelected
                                    ? Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 3,
                                      )
                                    : null,
                                image: index == 0
                                    ? null
                                    : DecorationImage(
                                        image: AssetImage(
                                          NotoAppearance.wallpaperPaths[index],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                              ),
                              child: index == 0
                                  ? const Center(
                                      child: Icon(
                                        Icons.block_rounded,
                                        size: 30,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            NotoAppearance.wallpaperNames[index],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArchivePage extends StatelessWidget {
  const ArchivePage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) {
      final items = store.notes
          .where((n) => n.archived && n.deletedAt == null && !n.locked)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Arquivadas',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: items.isEmpty
            ? const Center(child: Text('Nenhuma nota arquivada.'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final note = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.archive_outlined),
                      title: Text(
                        displayTitle(note),
                      ),
                      subtitle: Text(note.folder),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditorPage(
                            store: store,
                            note: note,
                            isNew: false,
                          ),
                        ),
                      ),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Opções',
                        onSelected: (value) {
                          if (value == 'unarchive') store.unarchive(note);
                          if (value == 'trash') store.delete(note);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'unarchive',
                            child: Text('Desarquivar'),
                          ),
                          PopupMenuItem(
                            value: 'trash',
                            child: Text('Mover para a lixeira'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}

String _trashSubtitle(DateTime deletedAt) {
  final left = 30 - DateTime.now().difference(deletedAt).inDays;
  final when = DateFormat('dd/MM').format(deletedAt);
  if (left <= 1) return 'Apagada em $when · some amanhã';
  return 'Apagada em $when · some em $left dias';
}

class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) {
      final items = store.notes.where((n) => n.deletedAt != null).toList()
        ..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Lixeira',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            if (items.length > 1)
              TextButton(
                onPressed: () {
                  for (final note in items) {
                    note.deletedAt = null;
                  }
                  store.save();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${items.length} notas restauradas'),
                    ),
                  );
                },
                child: const Text('Restaurar tudo'),
              ),
            if (items.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Esvaziar a lixeira?'),
                      content: Text(
                        items.length == 1
                            ? 'A nota será apagada de vez. Não dá para desfazer.'
                            : 'As ${items.length} notas serão apagadas de vez. Não dá para desfazer.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Esvaziar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) store.emptyTrash();
                },
                child: const Text('Esvaziar'),
              ),
          ],
        ),
        body: items.isEmpty
            ? const Center(
                child: Text(
                  'A lixeira está vazia.\nO que fica aqui por mais de 30 dias é apagado sozinho.',
                  textAlign: TextAlign.center,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final note = items[index];
                  return Card(
                    child: ListTile(
                      title: Text(
                        note.locked
                            ? 'Nota do cofre'
                            : displayTitle(note),
                      ),
                      subtitle: Text(
                        _trashSubtitle(note.deletedAt!),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'restore') store.restore(note);
                          if (value == 'delete') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Apagar de vez?'),
                                content: const Text(
                                  'Essa nota some para sempre. Não dá para desfazer.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Cancelar'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Apagar'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) store.deleteForever(note);
                          }

                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'restore',
                            child: Text('Restaurar'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Apagar de vez',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      );
    },
  );
}

Future<void> exportBackup(BuildContext context, AppStore store) async {
  final images = <String, String>{};
  for (final note in store.notes) {
    final path = note.customWallpaper;
    if (path != null && await File(path).exists()) {
      images['note_${note.id}'] = base64Encode(await File(path).readAsBytes());
    }
    final cover = note.coverImage;
    if (cover != null && await File(cover).exists()) {
      images['cover_${note.id}'] = base64Encode(await File(cover).readAsBytes());
    }
  }
  if (store.customWallpaper != null &&
      await File(store.customWallpaper!).exists()) {
    images['global'] = base64Encode(
      await File(store.customWallpaper!).readAsBytes(),
    );
  }

  final data = {
    'format': 'noto-backup',
    'version': 3,
    'createdAt': DateTime.now().toIso8601String(),
    'notes': store.notes.map((n) => n.toJson()).toList(),
    'templates': store.templates.map((t) => t.toJson()).toList(),
    'settings': {
      'mode': store.mode.index,
      'accent': store.accent,
      'font': store.font,
      'fontSize': store.fontSize,
      'grid': store.grid,
      'wallpaper': store.wallpaper,
      'wallpaperDarkness': store.wallpaperDarkness,
      'wallpaperBlur': store.wallpaperBlur,
      'widgetNoteId': store.widgetNoteId,
      'layoutMode': store.layoutMode,
      'homeShowToday': store.homeShowToday,
      'pureBlack': store.pureBlack,
      'cardRadius': store.cardRadius,
      'gridColumns': store.gridColumns,
      'previewLines': store.previewLines,
      'cardShowFolder': store.cardShowFolder,
      'cardShowDate': store.cardShowDate,
      'cardShowTags': store.cardShowTags,
      'editorLineHeight': store.editorLineHeight,
      'homeTitle': store.homeTitle,
      'plusAction': store.plusAction,
      'newNoteColor': store.newNoteColor,
      'showShortcutsBar': store.showShortcutsBar,
      // Só o resumo da senha, nunca a senha: o cofre continua funcionando
      // ao restaurar em outro celular.
      'vaultPinHash': store.vaultPinHash,
      'vaultSalt': store.vaultSalt,
      'vaultQuestion': store.vaultQuestion,
      'vaultAnswerHash': store.vaultAnswerHash,
      'vaultLockSeconds': store.vaultLockSeconds,
    },
    'images': images,
  };

  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/Noto-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.noto',
  );
  await file.writeAsString(jsonEncode(data));
  final result = await Share.shareXFiles(
    [XFile(file.path)],
    text: 'Backup completo do Noto',
  );
  if (result.status != ShareResultStatus.dismissed) {
    store.lastBackupAt = DateTime.now();
    await store.save();
  }
}

Future<void> importBackup(BuildContext context, AppStore store) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.any,
    allowMultiple: false,
  );
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return;

  try {
    final data =
        jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if (data['format'] != 'noto-backup') throw const FormatException();
    final notes = (data['notes'] as List)
        .map((e) => Note.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final images = Map<String, dynamic>.from(data['images'] ?? {});
    final settings = Map<String, dynamic>.from(data['settings'] ?? {});
    final dir = await getApplicationDocumentsDirectory();

    for (final note in notes) {
      final encoded = images['note_${note.id}'];
      if (encoded != null) {
        final file = File('${dir.path}/restored_${note.id}.jpg');
        await file.writeAsBytes(base64Decode(encoded));
        note.customWallpaper = file.path;
      }
      final cover = images['cover_${note.id}'];
      if (cover != null) {
        final file = File('${dir.path}/restored_cover_${note.id}.jpg');
        await file.writeAsBytes(base64Decode(cover));
        note.coverImage = file.path;
      }
    }
    final templates = data['templates'] is List
        ? (data['templates'] as List)
              .map((e) => NotoTemplate.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : null;

    if (!context.mounted) return;
    final currentCount = store.notes.where((n) => n.deletedAt == null).length;
    final choice = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar este backup?'),
        content: Text(
          'O backup tem ${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}. '
          'Você tem $currentCount no app agora.\n\n'
          '"Juntar" mantém as suas e adiciona as do backup (a versão mais nova '
          'de cada nota vale). "Substituir" troca tudo pelo backup, inclusive '
          'os ajustes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'replace'),
            child: const Text('Substituir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'merge'),
            child: const Text('Juntar'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'merge') {
      final byId = {for (final note in store.notes) note.id: note};
      var added = 0;
      var updated = 0;
      for (final note in notes) {
        final current = byId[note.id];
        if (current == null) {
          store.notes.add(note);
          added++;
        } else if (note.updatedAt.isAfter(current.updatedAt)) {
          store.notes[store.notes.indexOf(current)] = note;
          updated++;
        }
      }
      for (final template in templates ?? const <NotoTemplate>[]) {
        if (!store.templates.any((t) => t.id == template.id)) {
          store.templates.add(template);
        }
      }
      // Notas do cofre vindas do backup precisam de um cofre para abrir.
      if (!store.hasVault && settings['vaultPinHash'] is String) {
        store.vaultPinHash = settings['vaultPinHash'] as String;
        store.vaultSalt = settings['vaultSalt']?.toString() ?? '';
        store.vaultQuestion = settings['vaultQuestion']?.toString() ?? '';
        store.vaultAnswerHash = settings['vaultAnswerHash']?.toString();
      }
      FileCache.clear();
      await store.save();
      for (final note in store.notes.where((n) => n.reminderAt != null)) {
        await store.refreshReminder(note);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              added + updated == 0
                  ? 'Nada novo: você já tinha tudo deste backup.'
                  : '$added ${added == 1 ? 'nota adicionada' : 'notas adicionadas'}'
                        '${updated > 0 ? ', $updated ${updated == 1 ? 'atualizada' : 'atualizadas'}' : ''}.',
            ),
          ),
        );
      }
      return;
    }

    store.notes
      ..clear()
      ..addAll(notes);
    if (templates != null) {
      store.templates
        ..clear()
        ..addAll(templates);
    }
    T pick<T>(String key, T fallback) =>
        settings[key] is T ? settings[key] as T : fallback;
    store.layoutMode = pick<num>('layoutMode', store.layoutMode).toInt().clamp(0, 2).toInt();
    store.homeShowToday = pick('homeShowToday', store.homeShowToday);
    store.pureBlack = pick('pureBlack', store.pureBlack);
    store.cardRadius = pick<num>('cardRadius', store.cardRadius).toInt().clamp(0, 28).toInt();
    store.gridColumns = pick<num>('gridColumns', store.gridColumns).toInt().clamp(2, 3).toInt();
    store.previewLines = pick<num>('previewLines', store.previewLines).toInt().clamp(0, 8).toInt();
    store.cardShowFolder = pick('cardShowFolder', store.cardShowFolder);
    store.cardShowDate = pick('cardShowDate', store.cardShowDate);
    store.cardShowTags = pick('cardShowTags', store.cardShowTags);
    store.editorLineHeight = pick<num>('editorLineHeight', store.editorLineHeight)
        .toDouble()
        .clamp(1.2, 2.2)
        .toDouble();
    store.homeTitle = pick('homeTitle', store.homeTitle);
    store.plusAction = pick<num>('plusAction', store.plusAction).toInt().clamp(0, 2).toInt();
    store.newNoteColor = pick<num>('newNoteColor', store.newNoteColor)
        .toInt()
        .clamp(0, NotoAppearance.noteColors.length - 1)
        .toInt();
    store.showShortcutsBar = pick('showShortcutsBar', store.showShortcutsBar);
    if (settings['vaultPinHash'] is String) {
      store.vaultPinHash = settings['vaultPinHash'] as String;
      store.vaultSalt = pick('vaultSalt', store.vaultSalt);
      store.vaultQuestion = pick('vaultQuestion', store.vaultQuestion);
      store.vaultAnswerHash = settings['vaultAnswerHash']?.toString();
      store.vaultLockSeconds =
          pick<num>('vaultLockSeconds', store.vaultLockSeconds).toInt();
    }
    store.mode =
        ThemeMode.values[((settings['mode'] as num?)?.toInt() ?? 0).clamp(
          0,
          ThemeMode.values.length - 1,
        )];
    store.accent = ((settings['accent'] as num?)?.toInt() ?? 0).clamp(
      0,
      NotoAppearance.accents.length - 1,
    );
    store.font = ((settings['font'] as num?)?.toInt() ?? 0).clamp(
      0,
      NotoAppearance.fonts.length - 1,
    );
    store.fontSize = ((settings['fontSize'] as num?)?.toDouble() ?? 17).clamp(
      14,
      26,
    );
    store.grid = settings['grid'] ?? true;
    store.wallpaper = ((settings['wallpaper'] as num?)?.toInt() ?? 0).clamp(
      0,
      NotoAppearance.wallpaperPaths.length - 1,
    );
    store.wallpaperDarkness =
        ((settings['wallpaperDarkness'] as num?)?.toDouble() ?? .25).clamp(
          0,
          .8,
        );
    store.wallpaperBlur = ((settings['wallpaperBlur'] as num?)?.toDouble() ?? 0)
        .clamp(0, 16);
    store.widgetNoteId = settings['widgetNoteId'];
    store.customWallpaper = null;
    if (images['global'] != null) {
      final file = File('${dir.path}/restored_global.jpg');
      await file.writeAsBytes(base64Decode(images['global']));
      store.customWallpaper = file.path;
    }
    FileCache.clear();
    await store.save();
    // Os lembretes do backup precisam ser marcados de novo neste aparelho.
    for (final note in store.notes.where((n) => n.reminderAt != null)) {
      await store.refreshReminder(note);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notes.length == 1 ? '1 nota restaurada.' : '${notes.length} notas restauradas.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esse arquivo não é um backup do Noto.'),
        ),
      );
    }
  }
}

void showAboutNoto(BuildContext context) => showAboutDialog(
  context: context,
  applicationName: 'Noto',
  applicationVersion: '2.5.1',
  applicationIcon: ClipRRect(
    borderRadius: BorderRadius.circular(18),
    child: Image.asset('assets/noto_mark.png', width: 68, height: 68),
  ),
  children: const [
    Text('Um bloco de notas simples, offline e do seu jeito.'),
  ],
);

/// Exporta todas as notas (fora do cofre e da lixeira) num único arquivo Markdown.
Future<void> exportAllNotes(AppStore store) async {
  final notes = store.notes
      .where((n) => n.deletedAt == null && !n.locked)
      .toList()
    ..sort((a, b) {
      final folder = a.folder.toLowerCase().compareTo(b.folder.toLowerCase());
      return folder != 0 ? folder : b.updatedAt.compareTo(a.updatedAt);
    });
  final buffer = StringBuffer()
    ..writeln('# Minhas notas do Noto')
    ..writeln()
    ..writeln(
      'Exportado em ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now())} · ${notes.length} notas',
    );
  String? folder;
  for (final note in notes) {
    if (note.folder != folder) {
      folder = note.folder;
      buffer
        ..writeln()
        ..writeln('---')
        ..writeln()
        ..writeln('# 📁 $folder');
    }
    buffer
      ..writeln()
      ..writeln('## ${displayTitle(note)}')
      ..writeln();
    final meta = [
      if (note.archived) 'arquivada',
      if (note.tags.isNotEmpty) note.tags.map((t) => '#$t').join(' '),
      'editada em ${DateFormat('dd/MM/yyyy').format(note.updatedAt)}',
    ];
    buffer
      ..writeln('_${meta.join(' · ')}_')
      ..writeln();
    if (note.body.trim().isNotEmpty) buffer.writeln(note.body.trim());
    for (final table in (note.editor['tables'] as List?) ?? const []) {
      buffer
        ..writeln()
        ..writeln(
          NotoTable.fromJson(Map<String, dynamic>.from(table as Map)).markdown,
        );
    }
    for (final code in (note.editor['code'] as List?) ?? const []) {
      final data = Map<String, dynamic>.from(code as Map);
      buffer
        ..writeln()
        ..writeln('```${data['language'] ?? ''}')
        ..writeln(data['text'] ?? '')
        ..writeln('```');
    }
  }
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/Noto-todas-as-notas-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.md',
  );
  await file.writeAsString(buffer.toString());
  await Share.shareXFiles([XFile(file.path)], text: 'Minhas notas do Noto');
}

/// Importa vários arquivos .txt ou .md de uma vez, cada um vira uma nota.
Future<void> importTextFiles(BuildContext context, AppStore store) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['txt', 'md', 'markdown'],
    allowMultiple: true,
    withData: true,
  );
  if (result == null || result.files.isEmpty) return;
  var count = 0;
  for (final file in result.files) {
    try {
      final content = file.bytes != null
          ? utf8.decode(file.bytes!, allowMalformed: true)
          : await File(file.path!).readAsString();
      var title = file.name.replaceFirst(
        RegExp(r'\.(txt|md|markdown)$', caseSensitive: false),
        '',
      );
      var body = content;
      final lines = content.split('\n');
      if (lines.isNotEmpty && lines.first.trim().startsWith('# ')) {
        title = lines.first.trim().substring(2).trim();
        body = lines.skip(1).join('\n').trimLeft();
      }
      store.notes.add(
        Note(
          id: '${DateTime.now().microsecondsSinceEpoch}$count',
          title: title,
          body: body,
          updatedAt: DateTime.now(),
          folder: 'Importadas',
          font: store.font,
          checklist: hasTaskLines(body),
        ),
      );
      count++;
    } catch (_) {
      /* Arquivo ilegível: pula e segue com os outros. */
    }
  }
  await store.save();
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'Não consegui ler esses arquivos.'
              : count == 1
              ? '1 nota importada na pasta Importadas'
              : '$count notas importadas na pasta Importadas',
        ),
      ),
    );
  }
}
