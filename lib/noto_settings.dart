import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_library.dart';
import 'noto_store.dart';
import 'noto_theme.dart';
import 'noto_tutorial.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.store});

  final AppStore store;

  Future<void> _pickTheme(BuildContext context) async {
    final selected = await showModalBottomSheet<ThemeMode>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHeader('Tema'),
          RadioListTile<ThemeMode>(
            value: ThemeMode.system,
            groupValue: store.mode,
            title: const Text('Seguir o sistema'),
            onChanged: (value) => Navigator.pop(sheetContext, value),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.light,
            groupValue: store.mode,
            title: const Text('Claro'),
            onChanged: (value) => Navigator.pop(sheetContext, value),
          ),
          RadioListTile<ThemeMode>(
            value: ThemeMode.dark,
            groupValue: store.mode,
            title: const Text('Escuro'),
            onChanged: (value) => Navigator.pop(sheetContext, value),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (selected != null) {
      store.mode = selected;
      await store.save();
    }
  }

  Future<void> _pickAccent(BuildContext context) async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHeader('Cor de destaque'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: List.generate(NotoAppearance.accents.length, (index) {
                  final accent = NotoAppearance.accents[index];
                  final active = index == store.accent;
                  return Tooltip(
                    message: accent.name,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(sheetContext, index),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accent.color,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: active
                            ? Icon(
                                Icons.check_rounded,
                                color: accent.color.computeLuminance() > .4
                                    ? Colors.black
                                    : Colors.white,
                                size: 19,
                              )
                            : null,
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null) {
      store.accent = selected;
      await store.save();
    }
  }

  Future<void> _pickTextSize(BuildContext context) async {
    var value = store.fontSize;
    final selected = await showModalBottomSheet<double>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SheetHeader('Tamanho do texto'),
              Text('O texto fica assim.', style: TextStyle(fontSize: value)),
              Slider(
                value: value,
                min: 14,
                max: 26,
                divisions: 6,
                label: '${value.round()}',
                onChanged: (next) => setModalState(() => value = next),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, value),
                  child: const Text('Aplicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      store.fontSize = selected;
      await store.save();
    }
  }

  List<Note> get _activeNotes =>
      store.notes
          .where((n) => n.deletedAt == null && !n.archived && !n.locked)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  String _widgetNoteLabel() {
    for (final note in _activeNotes) {
      if (note.id == store.widgetNoteId) {
        return displayTitle(note);
      }
    }
    return 'A mais recente';
  }

  Future<void> _pickWidgetNote(BuildContext context) async {
    final notes = _activeNotes;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const _SheetHeader('Nota do widget'),
            RadioListTile<String>(
              value: '',
              groupValue: store.widgetNoteId ?? '',
              title: const Text('Sempre a mais recente'),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
            for (final note in notes)
              RadioListTile<String>(
                value: note.id,
                groupValue: store.widgetNoteId ?? '',
                title: Text(
                  displayTitle(note),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (value) => Navigator.pop(sheetContext, value),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected == null) return;
    store.widgetNoteId = selected.isEmpty ? null : selected;
    await store.save();
  }

  static const _radiusOptions = [
    (4, 'Retos'),
    (10, 'Suaves'),
    (16, 'Arredondados (padrão)'),
    (26, 'Bem redondos'),
  ];
  static const _previewOptions = [
    (0, 'Sem prévia, só o título'),
    (2, '2 linhas'),
    (4, '4 linhas (padrão)'),
    (6, '6 linhas'),
  ];
  static const _spacingOptions = [
    (13, 'Compacto'),
    (16, 'Normal (padrão)'),
    (20, 'Largo'),
  ];

  String _label(List<(int, String)> options, int value) {
    for (final option in options) {
      if (option.$1 == value) return option.$2;
    }
    return options.first.$2;
  }

  Future<int?> _choose(
    BuildContext context,
    String title,
    List<(int, String)> options,
    int current,
  ) => showModalBottomSheet<int>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(title),
          for (final option in options)
            RadioListTile<int>(
              value: option.$1,
              groupValue: current,
              title: Text(option.$2),
              onChanged: (value) => Navigator.pop(sheetContext, value),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  Future<void> _editHomeTitle(BuildContext context) async {
    final controller = TextEditingController(text: store.homeTitle);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Nome no topo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex.: Notas da Ju',
            helperText: 'Deixe vazio para mostrar "Noto"',
          ),
          onSubmitted: (text) => Navigator.pop(dialogContext, text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    store.homeTitle = value.trim();
    await store.save();
  }

  Future<void> _showStats(BuildContext context) async {
    final visible = store.notes.where((n) => !n.locked).toList();
    final active = visible.where((n) => n.deletedAt == null && !n.archived);
    final archived = visible.where((n) => n.deletedAt == null && n.archived);
    var words = 0;
    var pending = 0;
    var done = 0;
    final folders = <String, int>{};
    DateTime? oldest;
    for (final note in active) {
      final text = readablePreview(note.body).trim();
      if (text.isNotEmpty) words += text.split(RegExp(r'\s+')).length;
      pending += countPendingTasks(note.body);
      done += countDoneTasks(note.body);
      folders[note.folder] = (folders[note.folder] ?? 0) + 1;
      if (oldest == null || note.createdAt.isBefore(oldest)) {
        oldest = note.createdAt;
      }
    }
    final topFolder = folders.entries.isEmpty
        ? null
        : (folders.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;
    final rows = <(String, String)>[
      ('Notas', '${active.length}'),
      ('Arquivadas', '${archived.length}'),
      ('Palavras escritas', '$words'),
      ('Tarefas feitas', '$done de ${done + pending}'),
      if (topFolder != null)
        ('Pasta mais usada', '${topFolder.key} (${topFolder.value})'),
      if (oldest != null)
        ('Primeira nota', DateFormat('dd/MM/yyyy').format(oldest)),
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SheetHeader('Estatísticas'),
              for (final row in rows)
                ListTile(
                  title: Text(row.$1),
                  trailing: Text(
                    row.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          final hasWallpaper = store.customWallpaper != null || store.wallpaper > 0;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Ajustes'),
              actions: [
                IconButton(
                  tooltip: 'Sobre',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => showAboutNoto(context),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 42),
              children: [
                const SectionTitle('Aparência'),
                NotoTile(
                  icon: Icons.brightness_6_outlined,
                  title: 'Tema',
                  subtitle: switch (store.mode) {
                    ThemeMode.system => 'Sistema',
                    ThemeMode.light => 'Claro',
                    ThemeMode.dark => 'Escuro',
                  },
                  onTap: () => _pickTheme(context),
                ),
                NotoTile(
                  icon: Icons.circle,
                  iconColor: NotoAppearance.accents[store.accent].color,
                  title: 'Cor de destaque',
                  subtitle: NotoAppearance.accents[store.accent].name,
                  onTap: () => _pickAccent(context),
                ),
                NotoTile(
                  icon: Icons.text_fields_rounded,
                  title: 'Fonte',
                  subtitle: NotoAppearance.fonts[store.font].name,
                  onTap: () async {
                    final selected = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => FontPickerSheet(selected: store.font),
                    );
                    if (selected != null) {
                      store.font = selected;
                      await store.save();
                    }
                  },
                ),
                NotoTile(
                  icon: Icons.format_size_rounded,
                  title: 'Tamanho do texto',
                  subtitle: '${store.fontSize.round()}',
                  onTap: () => _pickTextSize(context),
                ),
                NotoTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Fundo do aplicativo',
                  subtitle: hasWallpaper ? 'Personalizado' : 'Padrão',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => WallpaperSheet(store: store),
                  ),
                ),
                if (hasWallpaper) _WallpaperTuning(store: store),
                NotoTile(
                  icon: store.layoutMode == 1
                      ? Icons.view_agenda_outlined
                      : Icons.grid_view_rounded,
                  title: 'Visualização das notas',
                  subtitle: store.layoutMode == 1 ? 'Lista' : 'Grade',
                  onTap: () {
                    store.layoutMode = store.layoutMode == 1 ? 0 : 1;
                    store.save();
                  },
                ),
                const SizedBox(height: 28),
                const SectionTitle('Personalização'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Preto puro no tema escuro'),
                  subtitle: const Text('Fundo totalmente preto, bom para telas OLED'),
                  value: store.pureBlack,
                  onChanged: (value) {
                    store.pureBlack = value;
                    store.save();
                  },
                ),
                NotoTile(
                  icon: Icons.badge_outlined,
                  title: 'Nome no topo da tela inicial',
                  subtitle: store.homeTitle.trim().isEmpty
                      ? 'Noto'
                      : store.homeTitle.trim(),
                  onTap: () => _editHomeTitle(context),
                ),
                NotoTile(
                  icon: Icons.rounded_corner_rounded,
                  title: 'Cantos dos cards',
                  subtitle: _label(_radiusOptions, store.cardRadius),
                  onTap: () async {
                    final value = await _choose(
                      context,
                      'Cantos dos cards',
                      _radiusOptions,
                      store.cardRadius,
                    );
                    if (value != null) {
                      store.cardRadius = value;
                      await store.save();
                    }
                  },
                ),
                if (store.layoutMode != 1)
                  NotoTile(
                    icon: Icons.view_column_outlined,
                    title: 'Colunas na grade',
                    subtitle: '${store.gridColumns} colunas',
                    onTap: () async {
                      final value = await _choose(
                        context,
                        'Colunas na grade',
                        const [(2, '2 colunas'), (3, '3 colunas')],
                        store.gridColumns,
                      );
                      if (value != null) {
                        store.gridColumns = value;
                        await store.save();
                      }
                    },
                  ),
                NotoTile(
                  icon: Icons.short_text_rounded,
                  title: 'Prévia do texto nos cards',
                  subtitle: _label(_previewOptions, store.previewLines),
                  onTap: () async {
                    final value = await _choose(
                      context,
                      'Prévia do texto nos cards',
                      _previewOptions,
                      store.previewLines,
                    );
                    if (value != null) {
                      store.previewLines = value;
                      await store.save();
                    }
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mostrar nos cards',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Pasta'),
                            selected: store.cardShowFolder,
                            onSelected: (value) {
                              store.cardShowFolder = value;
                              store.save();
                            },
                          ),
                          FilterChip(
                            label: const Text('Tags'),
                            selected: store.cardShowTags,
                            onSelected: (value) {
                              store.cardShowTags = value;
                              store.save();
                            },
                          ),
                          FilterChip(
                            label: const Text('Data'),
                            selected: store.cardShowDate,
                            onSelected: (value) {
                              store.cardShowDate = value;
                              store.save();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                NotoTile(
                  icon: Icons.format_line_spacing_rounded,
                  title: 'Espaço entre as linhas do texto',
                  subtitle: _label(
                    _spacingOptions,
                    (store.editorLineHeight * 10).round(),
                  ),
                  onTap: () async {
                    final value = await _choose(
                      context,
                      'Espaço entre as linhas',
                      _spacingOptions,
                      (store.editorLineHeight * 10).round(),
                    );
                    if (value != null) {
                      store.editorLineHeight = value / 10;
                      await store.save();
                    }
                  },
                ),
                const SizedBox(height: 28),
                const SectionTitle('Tela inicial'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resumo de hoje'),
                  subtitle: const Text('Tarefas, lembretes e notas editadas hoje'),
                  value: store.homeShowToday,
                  onChanged: (value) {
                    store.homeShowToday = value;
                    store.save();
                  },
                ),
                // Só faz sentido escolher quando há notas para escolher.
                if (_activeNotes.isNotEmpty)
                  NotoTile(
                  icon: Icons.widgets_outlined,
                  title: 'Nota do widget',
                  subtitle: _widgetNoteLabel(),
                  onTap: () => _pickWidgetNote(context),
                ),
                const SizedBox(height: 28),
                const SectionTitle('Dados e ajuda'),
                NotoTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Fazer backup',
                  onTap: () => exportBackup(context, store),
                ),
                NotoTile(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Restaurar backup',
                  onTap: () => importBackup(context, store),
                ),
                NotoTile(
                  icon: Icons.ios_share_rounded,
                  title: 'Exportar todas as notas',
                  subtitle: 'Um arquivo de texto fácil de ler em qualquer lugar',
                  onTap: () => exportAllNotes(store),
                ),
                NotoTile(
                  icon: Icons.insights_outlined,
                  title: 'Estatísticas',
                  onTap: () => _showStats(context),
                ),
                NotoTile(
                  icon: Icons.school_outlined,
                  title: 'Ver tutorial de novo',
                  subtitle: 'Como usar o Noto em 5 telas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TutorialPage(
                        onDone: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
        ),
      );
}

class _WallpaperTuning extends StatefulWidget {
  const _WallpaperTuning({required this.store});
  final AppStore store;

  @override
  State<_WallpaperTuning> createState() => _WallpaperTuningState();
}

class _WallpaperTuningState extends State<_WallpaperTuning> {
  late double darkness = widget.store.wallpaperDarkness;
  late double blur = widget.store.wallpaperBlur;

  void _apply() {
    widget.store
      ..wallpaperDarkness = darkness
      ..wallpaperBlur = blur;
    widget.store.save();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Escurecer fundo · ${(darkness * 100).round()}%'),
        Slider(
          value: darkness,
          max: .8,
          onChanged: (value) => setState(() => darkness = value),
          onChangeEnd: (_) => _apply(),
        ),
        Text('Desfocar fundo · ${blur.round()}'),
        Slider(
          value: blur,
          max: 16,
          divisions: 16,
          onChanged: (value) => setState(() => blur = value),
          onChangeEnd: (_) => _apply(),
        ),
      ],
    ),
  );
}
