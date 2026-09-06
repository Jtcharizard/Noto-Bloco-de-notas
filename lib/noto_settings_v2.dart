import 'package:flutter/material.dart';

import 'noto_models.dart';
import 'noto_settings.dart' as legacy;
import 'noto_store.dart';
import 'noto_theme.dart';

class SettingsPageV2 extends StatelessWidget {
  const SettingsPageV2({super.key, required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          final active = store.notes
              .where((n) => n.deletedAt == null && !n.archived)
              .toList();
          final selectedWidgetId = active.any((n) => n.id == store.widgetNoteId)
              ? store.widgetNoteId
              : null;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Ajustes'),
              actions: [
                IconButton(
                  tooltip: 'Sobre o Noto',
                  icon: const Icon(Icons.info_outline_rounded),
                  onPressed: () => legacy.showAboutNoto(context),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
              children: [
                const SectionTitle('Identidade do Noto'),
                NotoSurface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const NotoMark(size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tema Noto',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Papel quente, tinta escura e cor de destaque.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('Sistema'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Claro'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Escuro'),
                            ),
                          ],
                          selected: {store.mode},
                          onSelectionChanged: (value) {
                            store.mode = value.first;
                            store.save();
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Cor de destaque',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            NotoAppearance.accents[store.accent].name,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: List.generate(
                          NotoAppearance.accents.length,
                          (index) {
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
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: option.color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NotoTile(
                  icon: Icons.font_download_outlined,
                  title: 'Fonte do aplicativo',
                  subtitle:
                      '${NotoAppearance.fonts[store.font].name} • ${NotoAppearance.fonts.length} opções',
                  onTap: () async {
                    final selected = await showModalBottomSheet<int>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => legacy.FontPickerSheet(
                        selected: store.font,
                      ),
                    );
                    if (selected != null) {
                      store.font = selected;
                      await store.save();
                    }
                  },
                ),
                const SizedBox(height: 12),
                NotoSurface(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.text_fields_rounded),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tamanho do texto',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
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
                const SizedBox(height: 28),
                const SectionTitle('Início'),
                NotoSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.today_rounded),
                        title: const Text(
                          'Hoje',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Tarefas, lembretes e atividade do dia',
                        ),
                        value: store.homeShowToday,
                        onChanged: (value) {
                          store.homeShowToday = value;
                          store.save();
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        secondary: const Icon(Icons.bolt_rounded),
                        title: const Text(
                          'Noto Pulse',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        subtitle: const Text(
                          'Padrões e pendências que merecem atenção',
                        ),
                        value: store.homeShowPulse,
                        onChanged: (value) {
                          store.homeShowPulse = value;
                          store.save();
                        },
                      ),
                      const Divider(),
                      SwitchListTile(
                        secondary: const Icon(Icons.history_rounded),
                        title: const Text(
                          'Notas recentes',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        value: store.homeShowRecents,
                        onChanged: (value) {
                          store.homeShowRecents = value;
                          store.save();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                NotoTile(
                  icon: Icons.wallpaper_outlined,
                  title: 'Fundo do aplicativo',
                  subtitle: store.customWallpaper != null || store.wallpaper > 0
                      ? 'Imagem personalizada ativa'
                      : 'Usando o tema Noto puro',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => legacy.WallpaperSheet(store: store),
                  ),
                ),
                if (store.customWallpaper != null || store.wallpaper > 0) ...[
                  const SizedBox(height: 12),
                  NotoSurface(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.brightness_6_outlined),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 78,
                              child: Text('Escurecer'),
                            ),
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
                          ],
                        ),
                        Row(
                          children: [
                            const Icon(Icons.blur_on_outlined),
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 78,
                              child: Text('Desfoque'),
                            ),
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                const SectionTitle('Biblioteca'),
                NotoTile(
                  icon: Icons.archive_outlined,
                  title: 'Notas arquivadas',
                  subtitle:
                      '${store.notes.where((n) => n.archived && n.deletedAt == null).length} arquivadas',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => legacy.ArchivePage(store: store),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                NotoTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Lixeira',
                  subtitle:
                      '${store.notes.where((n) => n.deletedAt != null).length} itens',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => legacy.TrashPage(store: store),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionTitle('Widget'),
                NotoSurface(
                  padding: const EdgeInsets.all(14),
                  child: DropdownButtonFormField<String?>(
                    value: selectedWidgetId,
                    decoration: const InputDecoration(
                      labelText: 'Nota exibida no widget',
                      prefixIcon: Icon(Icons.widgets_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Nota mais recente'),
                      ),
                      ...active.map(
                        (note) => DropdownMenuItem<String?>(
                          value: note.id,
                          child: Text(
                            note.title.trim().isEmpty
                                ? 'Sem título'
                                : note.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      store.widgetNoteId = value;
                      store.save();
                    },
                  ),
                ),
                const SizedBox(height: 28),
                const SectionTitle('Seus dados'),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => legacy.exportBackup(context, store),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('Backup'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => legacy.importBackup(context, store),
                        icon: const Icon(Icons.settings_backup_restore_rounded),
                        label: const Text('Restaurar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
