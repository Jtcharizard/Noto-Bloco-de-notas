import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_extras.dart';
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

  static const _swipeOptions = [
    (0, 'Arquivar'),
    (1, 'Mandar para a lixeira'),
    (2, 'Fixar no topo'),
    (3, 'Favoritar'),
    (4, 'Não fazer nada'),
  ];
  static const _plusOptions = [
    (0, 'Perguntar o tipo de nota'),
    (1, 'Criar nota em branco direto'),
    (2, 'Criar lista de tarefas direto'),
  ];
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
  static const _cornerOptions = [
    (0, 'Retos'),
    (1, 'Suaves (padrão)'),
    (2, 'Redondos'),
  ];
  // Em porcentagem: 90 = 0,9.
  static const _uiScaleOptions = [
    (90, 'Pequeno'),
    (100, 'Normal (padrão)'),
    (110, 'Grande'),
    (120, 'Maior'),
  ];
  static const _titleSizeOptions = [
    (0, 'Pequeno'),
    (1, 'Médio (padrão)'),
    (2, 'Grande'),
  ];
  static const _marginOptions = [
    (0, 'Estreitas'),
    (1, 'Normais (padrão)'),
    (2, 'Largas'),
  ];
  static const _cardDateOptions = [
    (0, 'Relativa (ontem, 14:30)'),
    (1, 'Completa (02/11/2026)'),
  ];
  static const _doneStyleOptions = [
    (0, 'Riscadas e apagadas (padrão)'),
    (1, 'Só apagadas'),
    (2, 'Só riscadas'),
  ];
  static const _weekStartOptions = [
    (0, 'Domingo'),
    (1, 'Segunda (padrão)'),
  ];
  static const _trashOptions = [
    (7, '7 dias'),
    (15, '15 dias'),
    (30, '30 dias (padrão)'),
    (60, '60 dias'),
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

  Future<void> _pickNewNoteColor(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHeader('Cor das notas novas'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < NotoAppearance.noteColors.length; i++)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(sheetContext, i),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: i == 0
                          ? Theme.of(sheetContext).colorScheme.surfaceContainerHighest
                          : NotoAppearance.noteColors[i],
                      child: store.newNoteColor == i
                          ? const Icon(Icons.check_rounded, color: Colors.black87)
                          : i == 0
                          ? const Icon(Icons.block_rounded, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    store.newNoteColor = picked;
    await store.save();
  }

  /// Cartões de temas prontos: um toque muda tema, cor, fonte e cantos.
  Widget _presetRow(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: notoPresets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final preset = notoPresets[index];
          final accent = NotoAppearance.accents[preset.accent].color;
          final dark = preset.mode == ThemeMode.dark ||
              (preset.mode == ThemeMode.system && brightness == Brightness.dark);
          final bg = dark
              ? (preset.pureBlack ? Colors.black : const Color(0xFF1C1B22))
              : const Color(0xFFF8F6FB);
          final fg = dark ? Colors.white : const Color(0xFF1B1B1F);
          final active = store.accent == preset.accent &&
              store.font == preset.font &&
              store.mode == preset.mode &&
              store.pureBlack == preset.pureBlack;
          return GestureDetector(
            onTap: () {
              store
                ..mode = preset.mode
                ..accent = preset.accent
                ..font = preset.font
                ..pureBlack = preset.pureBlack
                ..cardRadius = preset.cardRadius;
              store.save();
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Tema ${preset.name} aplicado')),
              );
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 104,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? accent : fg.withValues(alpha: .12),
                  width: active ? 3 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const Spacer(),
                      if (active)
                        Icon(Icons.check_circle_rounded, size: 18, color: accent),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    'Aa',
                    style: TextStyle(
                      fontFamily: NotoAppearance.fonts[preset.font].family,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: fg.withValues(alpha: .8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _editHeaderPhrase(BuildContext context) async {
    final controller = TextEditingController(text: store.headerPhrase);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Frase abaixo da saudação'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex.: Um passo de cada vez',
            helperText: 'Deixe vazio para mostrar a data',
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value == null) return;
    store.headerPhrase = value.trim();
    await store.save();
  }

  Future<void> _editUserName(BuildContext context) async {
    final controller = TextEditingController(text: store.userName);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Como quer ser chamado?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Seu nome ou apelido',
            helperText: 'Aparece na saudação da tela inicial',
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
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (value == null) return;
    store.userName = value.trim();
    await store.save();
  }

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

  Future<void> _clearAllHistory(BuildContext context) async {
    final count = store.histories.values.fold<int>(0, (n, list) => n + list.length);
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há versões antigas guardadas.')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Limpar versões antigas?'),
        content: Text(
          'Apaga $count ${count == 1 ? 'versão guardada' : 'versões guardadas'} '
          'do histórico. As notas continuam como estão agora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    store.histories.clear();
    await store.save();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Histórico limpo.')),
      );
    }
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
    final dataSize = utf8
        .encode(jsonEncode(store.notes.map((n) => n.toJson()).toList()))
        .length;
    final historySize = utf8
        .encode(
          jsonEncode(
            store.histories.map(
              (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
            ),
          ),
        )
        .length;
    String size(int bytes) => bytes < 1024 * 1024
        ? '${(bytes / 1024).toStringAsFixed(0)} KB'
        : '${(bytes / 1048576).toStringAsFixed(1)} MB';
    final rows = <(String, String)>[
      ('Notas', '${active.length}'),
      ('Espaço das notas', size(dataSize)),
      ('Espaço do histórico', size(historySize)),
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

  List<Widget> _appearanceItems(BuildContext context) {
    final hasWallpaper = store.customWallpaper != null || store.wallpaper > 0;
    return [
      const SectionTitle('Temas prontos'),
      _presetRow(context),
      const SizedBox(height: 24),
      const SectionTitle('Tema e cores'),
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
        icon: Icons.crop_square_rounded,
        title: 'Cantos do app',
        subtitle: _label(_cornerOptions, store.appCorners),
        onTap: () async {
          final value = await _choose(
            context,
            'Cantos do app',
            _cornerOptions,
            store.appCorners,
          );
          if (value != null) {
            store.appCorners = value;
            await store.save();
          }
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Texto'),
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
      NotoTile(
        icon: Icons.text_increase_rounded,
        title: 'Tamanho das letras do app',
        subtitle: _label(_uiScaleOptions, (store.uiScale * 100).round()),
        onTap: () async {
          final value = await _choose(
            context,
            'Tamanho das letras do app',
            _uiScaleOptions,
            (store.uiScale * 100).round(),
          );
          if (value != null) {
            store.uiScale = value / 100;
            await store.save();
          }
        },
      ),
      NotoTile(
        icon: Icons.title_rounded,
        title: 'Tamanho do título da nota',
        subtitle: _label(_titleSizeOptions, store.titleSize),
        onTap: () async {
          final value = await _choose(
            context,
            'Tamanho do título da nota',
            _titleSizeOptions,
            store.titleSize,
          );
          if (value != null) {
            store.titleSize = value;
            await store.save();
          }
        },
      ),
      NotoTile(
        icon: Icons.format_indent_increase_rounded,
        title: 'Margens do editor',
        subtitle: _label(_marginOptions, store.editorMargin),
        onTap: () async {
          final value = await _choose(
            context,
            'Margens do editor',
            _marginOptions,
            store.editorMargin,
          );
          if (value != null) {
            store.editorMargin = value;
            await store.save();
          }
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Fundo'),
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
    ];
  }

  List<Widget> _homeItems(BuildContext context) {
    return [
      const SectionTitle('Saudação'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cartão de saudação no topo'),
        subtitle: const Text('Avatar, "Bom dia" e o resumo do dia'),
        value: store.showGreeting,
        onChanged: (value) {
          store.showGreeting = value;
          store.save();
        },
      ),
      NotoTile(
        icon: Icons.face_rounded,
        title: 'Seu avatar',
        subtitle: avatarAsset(store.userAvatar) != null
            ? notoAvatars
                  .firstWhere((a) => 'av:${a.$1}' == store.userAvatar)
                  .$2
            : store.userAvatar.trim().isEmpty
            ? 'Inicial do nome · toque para escolher'
            : store.userAvatar.trim(),
        onTap: () async {
          final picked = await pickAvatar(context, current: store.userAvatar);
          if (picked == null) return;
          store.userAvatar = picked;
          await store.save();
        },
      ),
      NotoTile(
        icon: Icons.format_quote_rounded,
        title: 'Frase abaixo da saudação',
        subtitle: store.headerPhrase.trim().isEmpty
            ? 'Mostra a data de hoje'
            : store.headerPhrase.trim(),
        onTap: () => _editHeaderPhrase(context),
      ),
      NotoTile(
        icon: Icons.waving_hand_outlined,
        title: 'Seu nome na saudação',
        subtitle: store.userName.trim().isEmpty
            ? 'Toque para o Noto te cumprimentar pelo nome'
            : store.userName.trim(),
        onTap: () => _editUserName(context),
      ),
      const SizedBox(height: 24),
      const SectionTitle('Tela inicial'),
      NotoTile(
        icon: Icons.badge_outlined,
        title: 'Nome no topo da tela inicial',
        subtitle: store.homeTitle.trim().isEmpty
            ? 'Noto'
            : store.homeTitle.trim(),
        onTap: () => _editHomeTitle(context),
      ),
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
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Atalhos de pastas e filtros'),
        subtitle: const Text('Todas, Favoritas, Atrasadas e suas pastas'),
        value: store.showFolderChips,
        onChanged: (value) {
          store.showFolderChips = value;
          store.save();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Barra de atalhos no topo'),
        subtitle: const Text('Arquivadas, Lixeira, Pastas e Tags'),
        value: store.showShortcutsBar,
        onChanged: (value) {
          store.showShortcutsBar = value;
          store.save();
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Cards das notas'),
      NotoTile(
        icon: Icons.style_outlined,
        title: 'Estilo dos cards',
        subtitle: const ['Com borda', 'Com sombra', 'Lisos'][store.cardStyle],
        onTap: () async {
          final value = await _choose(
            context,
            'Estilo dos cards',
            const [(0, 'Com borda'), (1, 'Com sombra'), (2, 'Lisos')],
            store.cardStyle,
          );
          if (value != null) {
            store.cardStyle = value;
            await store.save();
          }
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cards de vidro'),
        subtitle: const Text(
          'Translúcidos, deixando o fundo do app aparecer (com um fundo escolhido)',
        ),
        value: store.glassCards,
        onChanged: (value) {
          store.glassCards = value;
          store.save();
        },
      ),
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
      NotoTile(
        icon: Icons.event_outlined,
        title: 'Data nos cards',
        subtitle: _label(_cardDateOptions, store.cardDateFull ? 1 : 0),
        onTap: () async {
          final value = await _choose(
            context,
            'Data nos cards',
            _cardDateOptions,
            store.cardDateFull ? 1 : 0,
          );
          if (value != null) {
            store.cardDateFull = value == 1;
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
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Cards compactos'),
        subtitle: const Text('Mais notas na tela de uma vez'),
        value: store.compactCards,
        onChanged: (value) {
          store.compactCards = value;
          store.save();
        },
      ),
    ];
  }

  List<Widget> _notesItems(BuildContext context) {
    return [
      const SectionTitle('Listas de tarefas'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Caixas redondas'),
        subtitle: const Text('Bolinhas no lugar dos quadrados, como no Lembretes do iPhone'),
        value: store.roundChecks,
        onChanged: (value) {
          store.roundChecks = value;
          store.save();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Comemorar ao terminar a lista'),
        subtitle: const Text('Um confete quando a última tarefa é marcada'),
        value: store.celebrate,
        onChanged: (value) {
          store.celebrate = value;
          store.save();
        },
      ),
      NotoTile(
        icon: Icons.check_circle_outline_rounded,
        title: 'Tarefas feitas',
        subtitle: _label(_doneStyleOptions, store.doneStyle),
        onTap: () async {
          final value = await _choose(
            context,
            'Tarefas feitas',
            _doneStyleOptions,
            store.doneStyle,
          );
          if (value != null) {
            store.doneStyle = value;
            await store.save();
          }
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Feitas descem para o fim'),
        subtitle: const Text('Ao marcar, a tarefa vai para o fim da lista'),
        value: store.doneToBottom,
        onChanged: (value) {
          store.doneToBottom = value;
          store.save();
        },
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Nota de hoje traz o que faltou'),
        subtitle: const Text('Copia as tarefas não feitas da última nota do dia'),
        value: store.carryTasksToToday,
        onChanged: (value) {
          store.carryTasksToToday = value;
          store.save();
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Notas novas'),
      NotoTile(
        icon: Icons.add_circle_outline_rounded,
        title: 'Botão +',
        subtitle: _label(_plusOptions, store.plusAction),
        onTap: () async {
          final value = await _choose(
            context,
            'O que o botão + faz',
            _plusOptions,
            store.plusAction,
          );
          if (value != null) {
            store.plusAction = value;
            await store.save();
          }
        },
      ),
      NotoTile(
        icon: Icons.format_color_fill_rounded,
        iconColor: store.newNoteColor == 0
            ? null
            : NotoAppearance.noteColors[store.newNoteColor],
        title: 'Cor das notas novas',
        subtitle: store.newNoteColor == 0 ? 'Sem cor' : 'Personalizada',
        onTap: () => _pickNewNoteColor(context),
      ),
      const SizedBox(height: 24),
      const SectionTitle('Deslizar os cards'),
      NotoTile(
        icon: Icons.swipe_right_alt_rounded,
        title: 'Deslizar o card para a direita',
        subtitle: _label(_swipeOptions, store.swipeRight),
        onTap: () async {
          final value = await _choose(
            context,
            'Deslizar para a direita',
            _swipeOptions,
            store.swipeRight,
          );
          if (value != null) {
            store.swipeRight = value;
            await store.save();
          }
        },
      ),
      NotoTile(
        icon: Icons.swipe_left_alt_rounded,
        title: 'Deslizar o card para a esquerda',
        subtitle: _label(_swipeOptions, store.swipeLeft),
        onTap: () async {
          final value = await _choose(
            context,
            'Deslizar para a esquerda',
            _swipeOptions,
            store.swipeLeft,
          );
          if (value != null) {
            store.swipeLeft = value;
            await store.save();
          }
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Toque e calendário'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Vibrar ao tocar'),
        subtitle: const Text('Vibração curta ao marcar tarefas e selecionar notas'),
        value: store.haptics,
        onChanged: (value) {
          store.haptics = value;
          NotoHaptics.enabled = value;
          store.save();
        },
      ),
      NotoTile(
        icon: Icons.calendar_view_week_outlined,
        title: 'Semana começa no',
        subtitle: _label(_weekStartOptions, store.weekStartsSunday ? 0 : 1),
        onTap: () async {
          final value = await _choose(
            context,
            'Semana começa no',
            _weekStartOptions,
            store.weekStartsSunday ? 0 : 1,
          );
          if (value != null) {
            store.weekStartsSunday = value == 0;
            await store.save();
          }
        },
      ),
      // Só faz sentido escolher quando há notas para escolher.
      if (_activeNotes.isNotEmpty) ...[
        const SizedBox(height: 24),
        const SectionTitle('Widget'),
        NotoTile(
          icon: Icons.widgets_outlined,
          title: 'Nota do widget',
          subtitle: _widgetNoteLabel(),
          onTap: () => _pickWidgetNote(context),
        ),
      ],
    ];
  }

  List<Widget> _dataItems(BuildContext context) {
    return [
      const SectionTitle('Backup'),
      NotoTile(
        icon: Icons.upload_file_outlined,
        title: 'Fazer backup',
        subtitle: store.lastBackupAt == null
            ? 'Você ainda não fez nenhum backup'
            : 'Último: ${DateFormat('dd/MM/yyyy').format(store.lastBackupAt!)}',
        onTap: () => exportBackup(context, store),
      ),
      NotoTile(
        icon: Icons.settings_backup_restore_rounded,
        title: 'Restaurar backup',
        onTap: () => importBackup(context, store),
      ),
      const SizedBox(height: 24),
      const SectionTitle('Importar e exportar'),
      NotoTile(
        icon: Icons.file_open_outlined,
        title: 'Importar notas',
        subtitle: 'Arquivos .txt e .md, ou os .json do Google Keep (Google Takeout)',
        onTap: () => importTextFiles(context, store),
      ),
      NotoTile(
        icon: Icons.ios_share_rounded,
        title: 'Exportar todas as notas',
        subtitle: 'Um arquivo de texto fácil de ler em qualquer lugar',
        onTap: () => exportAllNotes(store),
      ),
      const SizedBox(height: 24),
      const SectionTitle('Lixeira'),
      NotoTile(
        icon: Icons.auto_delete_outlined,
        title: 'Esvaziar a lixeira depois de',
        subtitle: _label(_trashOptions, store.trashDays),
        onTap: () async {
          final value = await _choose(
            context,
            'Esvaziar a lixeira depois de',
            _trashOptions,
            store.trashDays,
          );
          if (value != null) {
            store.trashDays = safeTrashDays(value);
            // Prazo menor: o que já passou dele sai agora, não só ao reabrir.
            store.purgeOldTrash();
            await store.save();
          }
        },
      ),
      const SizedBox(height: 24),
      const SectionTitle('Espaço e números'),
      NotoTile(
        icon: Icons.history_toggle_off_rounded,
        title: 'Limpar versões antigas',
        subtitle: 'Apaga o histórico de todas as notas (as notas ficam)',
        onTap: () => _clearAllHistory(context),
      ),
      NotoTile(
        icon: Icons.insights_outlined,
        title: 'Estatísticas',
        onTap: () => _showStats(context),
      ),
    ];
  }

  List<Widget> _helpItems(BuildContext context) {
    return [
      const SectionTitle('Ajuda'),
      NotoTile(
        icon: Icons.info_outline_rounded,
        title: 'Sobre o Noto',
        subtitle: 'Versão, créditos e licenças',
        onTap: () => showAboutNoto(context),
      ),
      NotoTile(
        icon: Icons.school_outlined,
        title: 'Ver tutorial de novo',
        subtitle: 'Como usar o Noto, passo a passo',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TutorialPage(
              onDone: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
    ];
  }

  void _open(
    BuildContext context,
    String title,
    List<Widget> Function(BuildContext) items,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SettingsSubpage(store: store, title: title, items: items),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) {
      final cs = Theme.of(context).colorScheme;
      final accent = NotoAppearance.accents[store.accent];
      final theme = switch (store.mode) {
        ThemeMode.system => 'Tema do sistema',
        ThemeMode.light => 'Tema claro',
        ThemeMode.dark => 'Tema escuro',
      };
      final backup = store.lastBackupAt == null
          ? 'Nenhum backup ainda'
          : 'Último backup: ${DateFormat('dd/MM').format(store.lastBackupAt!)}';
      return Scaffold(
        appBar: AppBar(title: const Text('Ajustes')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _CategoryCard(
              icon: Icons.palette_outlined,
              color: accent.color,
              title: 'Aparência',
              subtitle: '$theme · ${accent.name} · ${NotoAppearance.fonts[store.font].name}',
              onTap: () => _open(context, 'Aparência', _appearanceItems),
            ),
            _CategoryCard(
              icon: Icons.dashboard_customize_outlined,
              color: cs.tertiary,
              title: 'Tela inicial e cards',
              subtitle: store.layoutMode == 1 ? 'Lista · resumo, atalhos e cards' : 'Grade · resumo, atalhos e cards',
              onTap: () => _open(context, 'Tela inicial e cards', _homeItems),
            ),
            _CategoryCard(
              icon: Icons.swipe_rounded,
              color: cs.secondary,
              title: 'Notas, gestos e widget',
              subtitle: 'Listas, botão +, deslizar e calendário',
              onTap: () => _open(context, 'Notas, gestos e widget', _notesItems),
            ),
            _CategoryCard(
              icon: Icons.cloud_upload_outlined,
              color: store.lastBackupAt == null ? cs.error : cs.primary,
              title: 'Backup e dados',
              subtitle: '$backup · importar, exportar',
              onTap: () => _open(context, 'Backup e dados', _dataItems),
            ),
            _CategoryCard(
              icon: Icons.help_outline_rounded,
              color: cs.outline,
              title: 'Ajuda e sobre',
              subtitle: 'Tutorial, versão e créditos',
              onTap: () => _open(context, 'Ajuda e sobre', _helpItems),
            ),
          ],
        ),
      );
    },
  );
}

class _SettingsSubpage extends StatelessWidget {
  const _SettingsSubpage({
    required this.store,
    required this.title,
    required this.items,
  });

  final AppStore store;
  final String title;
  final List<Widget> Function(BuildContext) items;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 42),
        children: items(context),
      ),
    ),
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: .62),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
