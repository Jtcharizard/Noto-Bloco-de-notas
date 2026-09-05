import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'noto_models.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          final active = store.notes.where((n) => n.deletedAt == null && !n.archived).toList();
          final selectedWidgetId = active.any((n) => n.id == store.widgetNoteId) ? store.widgetNoteId : null;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ajustes', style: TextStyle(fontWeight: FontWeight.w900)),
              actions: [
                IconButton(
                  tooltip: 'Sobre o Noto',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => showAboutNoto(context),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                const SectionTitle('Aparência'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tema', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: const [
                              ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_outlined), label: Text('Sistema')),
                              ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Claro')),
                              ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Escuro')),
                            ],
                            selected: {store.mode},
                            onSelectionChanged: (value) {
                              store.mode = value.first;
                              store.save();
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Text('Cor do app', style: TextStyle(fontWeight: FontWeight.w800))),
                            Text(NotoAppearance.accents[store.accent].name, style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: List.generate(NotoAppearance.accents.length, (index) {
                            final option = NotoAppearance.accents[index];
                            final selected = store.accent == index;
                            return Tooltip(
                              message: option.name,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  store.accent = index;
                                  store.save();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: option.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: selected ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                NotoTile(
                  icon: Icons.font_download_outlined,
                  title: 'Fonte do aplicativo',
                  subtitle: '${NotoAppearance.fonts[store.font].name} • ${NotoAppearance.fonts.length} opções',
                  onTap: () async {
                    final selected = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => FontPickerSheet(selected: store.font),
                    );
                    if (selected != null) {
                      store.font = selected;
                      await store.save();
                    }
                  },
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.text_fields_rounded),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Tamanho do texto', style: TextStyle(fontWeight: FontWeight.w800))),
                            Text('${store.fontSize.round()}'),
                          ],
                        ),
                        Slider(
                          value: store.fontSize,
                          min: 14,
                          max: 26,
                          divisions: 6,
                          onChanged: (value) {
                            store.fontSize = value;
                            store.save();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionTitle('Tela inicial'),
                NotoTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Fundo da tela inicial',
                  subtitle: store.customWallpaper != null || store.wallpaper > 0 ? 'Fundo personalizado ativo' : 'Sem imagem de fundo',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => WallpaperSheet(store: store),
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(children: [
                          const Icon(Icons.brightness_6_outlined),
                          const SizedBox(width: 8),
                          const SizedBox(width: 78, child: Text('Escurecer')),
                          Expanded(
                            child: Slider(
                              value: store.wallpaperDarkness,
                              min: 0,
                              max: .8,
                              onChanged: (value) {
                                store.wallpaperDarkness = value;
                                store.save();
                              },
                            ),
                          ),
                        ]),
                        Row(children: [
                          const Icon(Icons.blur_on_outlined),
                          const SizedBox(width: 8),
                          const SizedBox(width: 78, child: Text('Desfoque')),
                          Expanded(
                            child: Slider(
                              value: store.wallpaperBlur,
                              min: 0,
                              max: 16,
                              divisions: 16,
                              onChanged: (value) {
                                store.wallpaperBlur = value;
                                store.save();
                              },
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionTitle('Organização'),
                NotoTile(
                  icon: Icons.archive_outlined,
                  title: 'Notas arquivadas',
                  subtitle: '${store.notes.where((n) => n.archived && n.deletedAt == null).length} arquivadas',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivePage(store: store))),
                ),
                const SizedBox(height: 10),
                NotoTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Lixeira',
                  subtitle: '${store.notes.where((n) => n.deletedAt != null).length} itens',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrashPage(store: store))),
                ),
                const SizedBox(height: 26),
                const SectionTitle('Widget'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: DropdownButtonFormField<String?>(
                      value: selectedWidgetId,
                      decoration: const InputDecoration(
                        labelText: 'Nota exibida no widget',
                        prefixIcon: Icon(Icons.widgets_outlined),
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Nota mais recente')),
                        ...active.map(
                          (note) => DropdownMenuItem<String?>(
                            value: note.id,
                            child: Text(note.title.trim().isEmpty ? 'Sem título' : note.title, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        store.widgetNoteId = value;
                        store.save();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                const SectionTitle('Seus dados'),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => exportBackup(context, store),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Backup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => importBackup(context, store),
                        icon: const Icon(Icons.settings_backup_restore_rounded),
                        label: const Text('Restaurar'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                NotoTile(
                  icon: Icons.slideshow_outlined,
                  title: 'Ver apresentação novamente',
                  onTap: () {
                    store.onboardingDone = false;
                    store.save();
                  },
                ),
              ],
            ),
          );
        },
      );
}

class FontPickerSheet extends StatefulWidget {
  const FontPickerSheet({super.key, required this.selected});
  final int selected;

  @override
  State<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends State<FontPickerSheet> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final visible = List.generate(NotoAppearance.fonts.length, (i) => i)
        .where((i) => NotoAppearance.fonts[i].name.toLowerCase().contains(query.toLowerCase()))
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
                  Text('Fontes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${NotoAppearance.fonts.length} estilos para escolher', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 14),
                  TextField(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Pesquisar fonte'),
                    onChanged: (value) => setState(() => query = value),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    selected: selected,
                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .55),
                    title: Text(font.name, style: TextStyle(fontFamily: font.family, fontSize: 20, fontWeight: FontWeight.w700)),
                    subtitle: Text(font.subtitle, style: TextStyle(fontFamily: font.family)),
                    trailing: selected ? const Icon(Icons.check_circle_rounded) : null,
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
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (picked == null || !context.mounted) return;
    final directory = await getApplicationDocumentsDirectory();
    final saved = await File(picked.path).copy('${directory.path}/noto_wallpaper_${DateTime.now().microsecondsSinceEpoch}.jpg');
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
              Text(note == null ? 'Fundo da tela inicial' : 'Fundo da nota', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
                    final isSelected = selected == index && (note?.customWallpaper ?? store.customWallpaper) == null;
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
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                border: isSelected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
                                image: index == 0
                                    ? null
                                    : DecorationImage(image: AssetImage(NotoAppearance.wallpaperPaths[index]), fit: BoxFit.cover),
                              ),
                              child: index == 0 ? const Center(child: Icon(Icons.block_rounded, size: 30)) : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(NotoAppearance.wallpaperNames[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
          final items = store.notes.where((n) => n.archived && n.deletedAt == null).toList();
          return Scaffold(
            appBar: AppBar(title: const Text('Arquivadas', style: TextStyle(fontWeight: FontWeight.w900))),
            body: items.isEmpty
                ? const Center(child: Text('Nenhuma nota arquivada'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = items[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.archive_outlined),
                          title: Text(note.title.trim().isEmpty ? 'Sem título' : note.title),
                          subtitle: Text(note.folder),
                          trailing: IconButton(
                            tooltip: 'Desarquivar',
                            icon: const Icon(Icons.unarchive_outlined),
                            onPressed: () => store.unarchive(note),
                          ),
                        ),
                      );
                    },
                  ),
          );
        },
      );
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
            appBar: AppBar(title: const Text('Lixeira', style: TextStyle(fontWeight: FontWeight.w900))),
            body: items.isEmpty
                ? const Center(child: Text('A lixeira está vazia'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final note = items[index];
                      return Card(
                        child: ListTile(
                          title: Text(note.title.trim().isEmpty ? 'Sem título' : note.title),
                          subtitle: Text('Apagada em ${DateFormat('dd/MM • HH:mm').format(note.deletedAt!)}'),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'restore') store.restore(note);
                              if (value == 'delete') store.deleteForever(note);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'restore', child: Text('Restaurar')),
                              PopupMenuItem(value: 'delete', child: Text('Excluir para sempre', style: TextStyle(color: Colors.red))),
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
  }
  if (store.customWallpaper != null && await File(store.customWallpaper!).exists()) {
    images['global'] = base64Encode(await File(store.customWallpaper!).readAsBytes());
  }

  final data = {
    'format': 'noto-backup',
    'version': 2,
    'createdAt': DateTime.now().toIso8601String(),
    'notes': store.notes.map((n) => n.toJson()).toList(),
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
    },
    'images': images,
  };

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/Noto-backup-${DateFormat('yyyy-MM-dd').format(DateTime.now())}.noto');
  await file.writeAsString(jsonEncode(data));
  await Share.shareXFiles([XFile(file.path)], text: 'Backup completo do Noto');
}

Future<void> importBackup(BuildContext context, AppStore store) async {
  final picked = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
  final path = picked?.files.single.path;
  if (path == null || !context.mounted) return;

  try {
    final data = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
    if (data['format'] != 'noto-backup') throw const FormatException();
    final notes = (data['notes'] as List).map((e) => Note.fromJson(Map<String, dynamic>.from(e))).toList();
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
    }

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurar este backup?'),
        content: Text('As notas atuais serão substituídas pelas ${notes.length} notas deste arquivo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Restaurar')),
        ],
      ),
    );
    if (confirmed != true) return;

    store.notes
      ..clear()
      ..addAll(notes);
    store.mode = ThemeMode.values[((settings['mode'] as num?)?.toInt() ?? 0).clamp(0, ThemeMode.values.length - 1)];
    store.accent = ((settings['accent'] as num?)?.toInt() ?? 0).clamp(0, NotoAppearance.accents.length - 1);
    store.font = ((settings['font'] as num?)?.toInt() ?? 0).clamp(0, NotoAppearance.fonts.length - 1);
    store.fontSize = ((settings['fontSize'] as num?)?.toDouble() ?? 17).clamp(14, 26);
    store.grid = settings['grid'] ?? true;
    store.wallpaper = ((settings['wallpaper'] as num?)?.toInt() ?? 0).clamp(0, NotoAppearance.wallpaperPaths.length - 1);
    store.wallpaperDarkness = ((settings['wallpaperDarkness'] as num?)?.toDouble() ?? .25).clamp(0, .8);
    store.wallpaperBlur = ((settings['wallpaperBlur'] as num?)?.toDouble() ?? 0).clamp(0, 16);
    store.widgetNoteId = settings['widgetNoteId'];
    store.customWallpaper = null;
    if (images['global'] != null) {
      final file = File('${dir.path}/restored_global.jpg');
      await file.writeAsBytes(base64Decode(images['global']));
      store.customWallpaper = file.path;
    }
    await store.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${notes.length} notas restauradas.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esse arquivo não é um backup válido do Noto.')));
    }
  }
}

void showAboutNoto(BuildContext context) => showAboutDialog(
      context: context,
      applicationName: 'Noto',
      applicationVersion: '2.0 UI',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset('assets/app_icon.png', width: 68, height: 68),
      ),
      children: const [Text('Um bloco de notas simples por fora e personalizável por dentro.')],
    );
