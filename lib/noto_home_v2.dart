import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_editor_v2.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_settings_v2.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

class HomeShellV2 extends StatefulWidget {
  const HomeShellV2({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeShellV2> createState() => _HomeShellV2State();
}

class _HomeShellV2State extends State<HomeShellV2> {
  int index = 0;

  Future<void> _openNote(Note note) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPageV2(
          store: widget.store,
          note: note,
          isNew: false,
        ),
      ),
    );
  }

  Future<void> _createNote() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NotoMark(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nova coisa',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const Text('Um caminho só pra criar qualquer nota.'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _CreateChoice(
                icon: Icons.bolt_rounded,
                title: 'Captura rápida',
                subtitle: 'Vai pra Entrada pra tu organizar depois',
                onTap: () => Navigator.pop(sheetContext, 'quick'),
              ),
              _CreateChoice(
                icon: Icons.note_add_outlined,
                title: 'Nota em branco',
                subtitle: 'Só abre o editor',
                onTap: () => Navigator.pop(sheetContext, 'normal'),
              ),
              _CreateChoice(
                icon: Icons.checklist_rounded,
                title: 'Checklist',
                subtitle: 'Lista marcável com progresso',
                onTap: () => Navigator.pop(sheetContext, 'checklist'),
              ),
              _CreateChoice(
                icon: Icons.school_outlined,
                title: 'Estudo',
                subtitle: 'Tema, pontos principais e dúvidas',
                onTap: () => Navigator.pop(sheetContext, 'study'),
              ),
              _CreateChoice(
                icon: Icons.auto_awesome_outlined,
                title: 'RPG',
                subtitle: 'Sessão, acontecimentos e pistas',
                onTap: () => Navigator.pop(sheetContext, 'rpg'),
              ),
              _CreateChoice(
                icon: Icons.menu_book_outlined,
                title: 'Diário',
                subtitle: 'Entrada já marcada com a data de hoje',
                onTap: () => Navigator.pop(sheetContext, 'diary'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    var title = '';
    var body = '';
    var checklist = false;
    var folder = 'Geral';

    switch (choice) {
      case 'quick':
        folder = 'Entrada';
      case 'checklist':
        title = 'Minha lista';
        body = '[ ] Primeiro item';
        checklist = true;
      case 'study':
        title = 'Resumo de estudo';
        body = 'Tema:\n\nPontos principais:\n• \n\nDúvidas:\n';
      case 'rpg':
        title = 'Sessão de RPG';
        body = 'Personagens:\n\nAcontecimentos:\n\nPistas e ideias:\n';
      case 'diary':
        title = DateFormat('dd/MM/yyyy').format(DateTime.now());
        body = 'Como foi meu dia?\n\n';
      case 'normal':
        break;
    }

    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      folder: folder,
      checklist: checklist,
      font: widget.store.font,
    );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPageV2(
          store: widget.store,
          note: note,
          isNew: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      NotoHomePageV2(
        store: widget.store,
        onOpenNote: _openNote,
        onOpenLibrary: () => setState(() => index = 1),
      ),
      LibraryPageV2(store: widget.store, onOpenNote: _openNote),
      SettingsPageV2(store: widget.store),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: _NotoDock(
        selected: index,
        onSelect: (value) => setState(() => index = value),
        onCreate: _createNote,
      ),
    );
  }
}

class _NotoDock extends StatelessWidget {
  const _NotoDock({
    required this.selected,
    required this.onSelect,
    required this.onCreate,
  });

  final int selected;
  final ValueChanged<int> onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow.withValues(alpha: .97),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: .55),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .13),
              blurRadius: 26,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _DockButton(
                selected: selected == 0,
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: 'Início',
                onTap: () => onSelect(0),
              ),
            ),
            Expanded(
              child: _DockButton(
                selected: selected == 1,
                icon: Icons.folder_copy_outlined,
                selectedIcon: Icons.folder_copy_rounded,
                label: 'Biblioteca',
                onTap: () => onSelect(1),
              ),
            ),
            Expanded(
              child: _DockButton(
                selected: false,
                icon: Icons.add_rounded,
                selectedIcon: Icons.add_rounded,
                label: 'Novo',
                accent: true,
                onTap: onCreate,
              ),
            ),
            Expanded(
              child: _DockButton(
                selected: selected == 2,
                icon: Icons.tune_outlined,
                selectedIcon: Icons.tune_rounded,
                label: 'Ajustes',
                onTap: () => onSelect(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = accent || selected;
    return InkWell(
      borderRadius: BorderRadius.circular(19),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: accent ? 40 : 34,
              height: accent ? 34 : 28,
              decoration: BoxDecoration(
                color: accent
                    ? cs.primary
                    : selected
                        ? cs.primary.withValues(alpha: .14)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                selected ? selectedIcon : icon,
                size: accent ? 22 : 20,
                color: accent
                    ? Colors.white
                    : active
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: .6),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                color: active
                    ? cs.primary
                    : cs.onSurface.withValues(alpha: .58),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotoHomePageV2 extends StatelessWidget {
  const NotoHomePageV2({
    super.key,
    required this.store,
    required this.onOpenNote,
    required this.onOpenLibrary,
  });

  final AppStore store;
  final ValueChanged<Note> onOpenNote;
  final VoidCallback onOpenLibrary;

  bool get _hasWallpaper {
    final custom = store.customWallpaper;
    return store.wallpaper > 0 ||
        (custom != null && File(custom).existsSync());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: store,
        builder: (_, __) {
          final active = store.notes
              .where((n) => n.deletedAt == null && !n.archived)
              .toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          final snapshot = buildTodaySnapshot(active);
          final insights = buildPulseInsights(active);
          final recent = active.take(5).toList();
          final inbox = active.where((n) => n.folder == 'Entrada').length;

          return Scaffold(
            backgroundColor: _hasWallpaper ? Colors.transparent : null,
            body: SafeArea(
              bottom: false,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 118),
                children: [
                  Row(
                    children: [
                      const NotoMark(size: 50),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'NOTO',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            Text(
                              'Guarda o que merece ficar.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      if (inbox > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$inbox na Entrada',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  if (store.homeShowToday) ...[
                    _TodayHero(snapshot: snapshot),
                    const SizedBox(height: 24),
                  ],
                  if (store.homeShowPulse) ...[
                    Row(
                      children: [
                        const Expanded(child: SectionTitle('Pulse')),
                        Text(
                          'LOCAL • PRIVADO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: .45),
                            letterSpacing: .7,
                          ),
                        ),
                      ],
                    ),
                    _PulsePanel(insights: insights),
                    const SizedBox(height: 24),
                  ],
                  if (store.homeShowRecents) ...[
                    SectionTitle(
                      'Recentes',
                      trailing: TextButton(
                        onPressed: onOpenLibrary,
                        child: const Text('Ver biblioteca'),
                      ),
                    ),
                    if (recent.isEmpty)
                      NotoSurface(
                        child: Column(
                          children: [
                            Icon(
                              Icons.edit_note_rounded,
                              size: 44,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Teu Noto tá em branco',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Usa Novo ali embaixo e começa sem cerimônia.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      SizedBox(
                        height: 168,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: recent.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 10),
                          itemBuilder: (_, index) => _RecentCard(
                            note: recent[index],
                            onTap: () => onOpenNote(recent[index]),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      );
}

class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.snapshot});
  final TodaySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quiet = snapshot.pendingTasks == 0 &&
        snapshot.remindersToday == 0 &&
        snapshot.overdueReminders == 0;

    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withValues(alpha: .96),
            Color.lerp(cs.primary, NotoPalette.cocoa, .58)!,
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: .2),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'HOJE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('dd MMM').format(DateTime.now()).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            quiet
                ? 'Nada te perseguindo.'
                : snapshot.overdueReminders > 0
                    ? 'Tem coisa pedindo atenção.'
                    : 'Teu dia dentro do Noto.',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _TodayMetric(
                value: '${snapshot.pendingTasks}',
                label: 'pendentes',
              ),
              _TodayMetric(
                value: '${snapshot.remindersToday}',
                label: 'lembretes',
              ),
              _TodayMetric(
                value: '${snapshot.touched}',
                label: 'mexidas hoje',
              ),
            ],
          ),
          if (snapshot.overdueReminders > 0) ...[
            const SizedBox(height: 14),
            Text(
              '${snapshot.overdueReminders} ${snapshot.overdueReminders == 1 ? 'lembrete está atrasado' : 'lembretes estão atrasados'}.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _PulsePanel extends StatelessWidget {
  const _PulsePanel({required this.insights});
  final List<PulseInsight> insights;

  IconData _icon(PulseKind kind) => switch (kind) {
        PulseKind.checklist => Icons.checklist_rounded,
        PulseKind.stale => Icons.history_toggle_off_rounded,
        PulseKind.folder => Icons.folder_special_outlined,
        PulseKind.links => Icons.hub_outlined,
        PulseKind.momentum => Icons.bolt_rounded,
        PulseKind.reminder => Icons.notification_important_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return NotoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: insights.take(3).map((insight) {
          final last = insight == insights.take(3).last;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon(insight.kind), color: primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            insight.detail,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!last) const Divider(),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wallpaper = noteWallpaper(note);
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 210,
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            image: wallpaper == null
                ? null
                : DecorationImage(
                    image: wallpaper,
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withValues(alpha: note.wallpaperDarkness),
                      BlendMode.darken,
                    ),
                  ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.folder,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: wallpaper == null
                                ? cs.primary
                                : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (note.pinned)
                        Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: wallpaper == null ? cs.primary : Colors.white,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    note.title.trim().isEmpty ? 'Sem título' : note.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: wallpaper == null ? cs.onSurface : Colors.white,
                      fontSize: 18,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    note.body.trim().isEmpty
                        ? 'Nota vazia'
                        : note.body.replaceAll('\n', ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: wallpaper == null
                          ? cs.onSurface.withValues(alpha: .6)
                          : Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LibraryPageV2 extends StatefulWidget {
  const LibraryPageV2({
    super.key,
    required this.store,
    required this.onOpenNote,
  });

  final AppStore store;
  final ValueChanged<Note> onOpenNote;

  @override
  State<LibraryPageV2> createState() => _LibraryPageV2State();
}

class _LibraryPageV2State extends State<LibraryPageV2> {
  String query = '';
  String? folder;
  String? tag;
  bool favoritesOnly = false;
  bool pinnedOnly = false;
  int sort = 0;

  List<Note> get active => widget.store.notes
      .where((note) => note.deletedAt == null && !note.archived)
      .toList();

  List<String> get folders {
    final values = <String>{
      for (final note in active)
        if (note.folder.trim().isNotEmpty) note.folder.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  List<String> get tags {
    final values = <String>{
      for (final note in active)
        for (final value in note.tags)
          if (value.trim().isNotEmpty) value.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  int get activeFilterCount =>
      (folder == null ? 0 : 1) +
      (tag == null ? 0 : 1) +
      (favoritesOnly ? 1 : 0) +
      (pinnedOnly ? 1 : 0);

  List<Note> get visible {
    final normalized = query.trim().toLowerCase();
    final result = active.where((note) {
      if (favoritesOnly && !note.favorite) return false;
      if (pinnedOnly && !note.pinned) return false;
      if (folder != null && note.folder != folder) return false;
      if (tag != null &&
          !note.tags.any((value) => value.toLowerCase() == tag!.toLowerCase())) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return note.title.toLowerCase().contains(normalized) ||
          note.body.toLowerCase().contains(normalized) ||
          note.folder.toLowerCase().contains(normalized) ||
          note.tags.any((value) => value.toLowerCase().contains(normalized));
    }).toList();

    result.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      if (sort == 1) {
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      }
      if (sort == 2) return a.updatedAt.compareTo(b.updatedAt);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return result;
  }

  Future<void> _filters() async {
    var draftFolder = folder;
    var draftTag = tag;
    var draftFavorites = favoritesOnly;
    var draftPinned = pinnedOnly;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filtrar biblioteca',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 5),
                const Text('Favoritos, pastas e tags vivem só aqui.'),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.star_outline_rounded),
                  title: const Text('Só favoritas'),
                  value: draftFavorites,
                  onChanged: (value) =>
                      setModalState(() => draftFavorites = value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.push_pin_outlined),
                  title: const Text('Só fixadas'),
                  value: draftPinned,
                  onChanged: (value) =>
                      setModalState(() => draftPinned = value),
                ),
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: draftFolder,
                    decoration: const InputDecoration(
                      labelText: 'Pasta',
                      prefixIcon: Icon(Icons.folder_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas as pastas'),
                      ),
                      ...folders.map(
                        (value) => DropdownMenuItem<String?>(
                          value: value,
                          child: Text(value),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => draftFolder = value),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: draftTag,
                    decoration: const InputDecoration(
                      labelText: 'Tag',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas as tags'),
                      ),
                      ...tags.map(
                        (value) => DropdownMenuItem<String?>(
                          value: value,
                          child: Text('#$value'),
                        ),
                      ),
                    ],
                    onChanged: (value) =>
                        setModalState(() => draftTag = value),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            draftFolder = null;
                            draftTag = null;
                            draftFavorites = false;
                            draftPinned = false;
                          });
                        },
                        child: const Text('Limpar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () {
                          setState(() {
                            folder = draftFolder;
                            tag = draftTag;
                            favoritesOnly = draftFavorites;
                            pinnedOnly = draftPinned;
                          });
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Aplicar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _cycleLayout() {
    widget.store.layoutMode = (widget.store.layoutMode + 1) % 3;
    widget.store.save();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (_, __) {
          final notes = visible;
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Biblioteca',
                                    style: TextStyle(
                                      fontSize: 27,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -.7,
                                    ),
                                  ),
                                  Text('Todas as tuas notas num lugar só.'),
                                ],
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Modo de visualização',
                              onPressed: _cycleLayout,
                              icon: Icon(
                                switch (widget.store.layoutMode) {
                                  0 => Icons.grid_view_rounded,
                                  1 => Icons.view_agenda_outlined,
                                  _ => Icons.view_headline_rounded,
                                },
                              ),
                            ),
                            const SizedBox(width: 5),
                            PopupMenuButton<int>(
                              tooltip: 'Ordenar',
                              icon: const Icon(Icons.swap_vert_rounded),
                              onSelected: (value) => setState(() => sort = value),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 0,
                                  child: Text('Mais recentes'),
                                ),
                                PopupMenuItem(
                                  value: 1,
                                  child: Text('Por nome'),
                                ),
                                PopupMenuItem(
                                  value: 2,
                                  child: Text('Mais antigas'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  hintText: 'Buscar em tudo',
                                  prefixIcon: Icon(Icons.search_rounded),
                                ),
                                onChanged: (value) =>
                                    setState(() => query = value),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Badge(
                              isLabelVisible: activeFilterCount > 0,
                              label: Text('$activeFilterCount'),
                              child: IconButton.filledTonal(
                                tooltip: 'Filtros',
                                onPressed: _filters,
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            ),
                          ],
                        ),
                        if (activeFilterCount > 0) ...[
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (favoritesOnly)
                                  _ActiveFilter(
                                    label: 'Favoritas',
                                    onClear: () =>
                                        setState(() => favoritesOnly = false),
                                  ),
                                if (pinnedOnly)
                                  _ActiveFilter(
                                    label: 'Fixadas',
                                    onClear: () =>
                                        setState(() => pinnedOnly = false),
                                  ),
                                if (folder != null)
                                  _ActiveFilter(
                                    label: folder!,
                                    onClear: () => setState(() => folder = null),
                                  ),
                                if (tag != null)
                                  _ActiveFilter(
                                    label: '#$tag',
                                    onClear: () => setState(() => tag = null),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Expanded(
                    child: notes.isEmpty
                        ? _LibraryEmpty(filtered: activeFilterCount > 0 || query.isNotEmpty)
                        : switch (widget.store.layoutMode) {
                            0 => GridView.builder(
                                padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 11,
                                  mainAxisSpacing: 11,
                                  childAspectRatio: .86,
                                ),
                                itemCount: notes.length,
                                itemBuilder: (_, i) => _LibraryCard(
                                  note: notes[i],
                                  onTap: () => widget.onOpenNote(notes[i]),
                                ),
                              ),
                            1 => ListView.separated(
                                padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
                                itemCount: notes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) => _LibraryCard(
                                  note: notes[i],
                                  wide: true,
                                  onTap: () => widget.onOpenNote(notes[i]),
                                ),
                              ),
                            _ => ListView.separated(
                                padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
                                itemCount: notes.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (_, i) => _CompactNote(
                                  note: notes[i],
                                  onTap: () => widget.onOpenNote(notes[i]),
                                ),
                              ),
                          },
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _ActiveFilter extends StatelessWidget {
  const _ActiveFilter({required this.label, required this.onClear});
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 7),
        child: InputChip(
          label: Text(label),
          onDeleted: onClear,
        ),
      );
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.note,
    required this.onTap,
    this.wide = false,
  });

  final Note note;
  final VoidCallback onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final wallpaper = noteWallpaper(note);
    final colorIndex = NotoAppearance.safeNoteColorIndex(note.color);
    final customColor = colorIndex == 0 ? null : NotoAppearance.noteColors[colorIndex];
    final cs = Theme.of(context).colorScheme;
    final base = customColor ?? cs.surfaceContainerLow;
    final foreground = wallpaper == null
        ? (customColor == null ? cs.onSurface : NotoPalette.ink)
        : Colors.white;
    final family = NotoAppearance.familyAt(note.font);
    final checklist = note.body
        .split('\n')
        .where((line) => line.trim().startsWith('['))
        .toList();
    final checked = checklist
        .where((line) => line.trim().startsWith('[x]'))
        .length;

    return Material(
      color: base,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          image: wallpaper == null
              ? null
              : DecorationImage(
                  image: wallpaper,
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: note.wallpaperDarkness),
                    BlendMode.darken,
                  ),
                ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.folder,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: .65),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (note.favorite)
                      Icon(Icons.star_rounded, size: 15, color: foreground),
                    if (note.pinned) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.push_pin_rounded, size: 14, color: foreground),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  note.title.trim().isEmpty ? 'Sem título' : note.title,
                  maxLines: wide ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: family,
                    color: foreground,
                    fontSize: 17,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    note.body.trim().isEmpty
                        ? 'Nota vazia'
                        : note.body
                            .replaceAll('[ ]', '☐')
                            .replaceAll('[x]', '☑'),
                    maxLines: wide ? 2 : 6,
                    overflow: TextOverflow.fade,
                    style: TextStyle(
                      fontFamily: family,
                      color: foreground.withValues(alpha: .78),
                      height: 1.38,
                    ),
                  ),
                ),
                if (note.checklist && checklist.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: checked / checklist.length,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: foreground.withValues(alpha: .85),
                    backgroundColor: foreground.withValues(alpha: .18),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (note.tags.isNotEmpty)
                      Expanded(
                        child: Text(
                          note.tags.take(2).map((e) => '#$e').join('  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground.withValues(alpha: .56),
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      DateFormat('dd/MM').format(note.updatedAt),
                      style: TextStyle(
                        color: foreground.withValues(alpha: .56),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactNote extends StatelessWidget {
  const _CompactNote({required this.note, required this.onTap});
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NotoSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                note.checklist
                    ? Icons.checklist_rounded
                    : Icons.sticky_note_2_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.trim().isEmpty ? 'Sem título' : note.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (note.favorite)
                        const Icon(Icons.star_rounded, size: 15),
                      if (note.pinned)
                        const Icon(Icons.push_pin_rounded, size: 14),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${note.folder} • ${DateFormat('dd/MM HH:mm').format(note.updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _LibraryEmpty extends StatelessWidget {
  const _LibraryEmpty({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                filtered ? Icons.filter_alt_off_rounded : Icons.notes_rounded,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                filtered ? 'Nenhuma nota bateu' : 'Biblioteca vazia',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              Text(
                filtered
                    ? 'Limpa os filtros ou tenta outra busca.'
                    : 'Usa Novo na barra de baixo pra começar.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _CreateChoice extends StatelessWidget {
  const _CreateChoice({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle),
        onTap: onTap,
      );
}
