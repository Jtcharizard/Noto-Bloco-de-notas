import 'package:flutter/material.dart';

import 'noto_models.dart';
import 'noto_settings.dart' as legacy;
import 'noto_store.dart';
import 'noto_theme.dart';

class SettingsPageV4 extends StatelessWidget {
  const SettingsPageV4({super.key, required this.store});

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
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
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
                  onPressed: () => legacy.showAboutNoto(context),
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
                      builder: (_) => legacy.FontPickerSheet(selected: store.font),
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
                  subtitle: hasWallpaper ? 'Personalizado' : 'Tema Noto',
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (_) => legacy.WallpaperSheet(store: store),
                  ),
                ),
                const SizedBox(height: 28),
                const SectionTitle('Tela de notas'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Resumo de hoje'),
                  subtitle: const Text('Pendências e lembretes em uma linha'),
                  value: store.homeShowToday,
                  onChanged: (value) {
                    store.homeShowToday = value;
                    store.save();
                  },
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Noto Pulse'),
                  subtitle: const Text('Mostra um padrão útil quando houver'),
                  value: store.homeShowPulse,
                  onChanged: (value) {
                    store.homeShowPulse = value;
                    store.save();
                  },
                ),
                const SizedBox(height: 28),
                const SectionTitle('Dados'),
                NotoTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Fazer backup',
                  onTap: () => legacy.exportBackup(context, store),
                ),
                NotoTile(
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Restaurar backup',
                  onTap: () => legacy.importBackup(context, store),
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
