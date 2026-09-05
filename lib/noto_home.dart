import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_editor.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_settings.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(
        index: index,
        children: [
          NotesHomePage(store: widget.store),
          NotesHomePage(store: widget.store, favoritesOnly: true),
          SettingsPage(store: widget.store),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.sticky_note_2_outlined),
            selectedIcon: Icon(Icons.sticky_note_2_rounded),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.star_outline_rounded),
            selectedIcon: Icon(Icons.star_rounded),
            label: 'Favoritas',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({
    super.key,
    required this.store,
    this.favoritesOnly = false,
  });

  final AppStore store;
  final bool favoritesOnly;

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  String query = '';
  String folder = 'Todas';
  String tag = 'Todas';
  int sort = 0;

  List<Note> get activeNotes => widget.store.notes
      .where((note) => note.deletedAt == null && !note.archived)
      .toList();

  List<String> get folders {
    final values = <String>{
      for (final note in activeNotes)
        if (note.folder.trim().isNotEmpty) note.folder.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Todas', ...values];
  }

  List<String> get tags {
    final values = <String>{
      for (final note in activeNotes)
        for (final item in note.tags)
          if (item.trim().isNotEmpty) item.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['Todas', ...values];
  }

  List<Note> get visible {
    final normalized = query.trim().toLowerCase();
    final list = widget.store.notes.where((note) {
      if (note.deletedAt != null || note.archived) return false;
      if (widget.favoritesOnly && !note.favorite) return false;
      if (folder != 'Todas' && note.folder != folder) return false;
      if (tag != 'Todas' && !note.tags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
        return false;
      }
      if (normalized.isEmpty) return true;
      return note.title.toLowerCase().contains(normalized) ||
          note.body.toLowerCase().contains(normalized) ||
          note.folder.toLowerCase().contains(normalized) ||
          note.tags.any((item) => item.toLowerCase().contains(normalized));
    }).toList();

    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      if (sort == 1) return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (sort == 2) return a.updatedAt.compareTo(b.updatedAt);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  Future<void> openNote([Note? note, String template = 'normal']) async {
    final templates = <String, Map<String, dynamic>>{
      'normal': {'title': '', 'body': '', 'check': false},
      'checklist': {'title': 'Minha lista', 'body': '[ ] Primeiro item', 'check': true},
      'estudo': {
        'title': 'Resumo de estudo',
        'body': 'Tema:\n\nPontos principais:\n• \n\nDúvidas:\n',
        'check': false,
      },
      'rpg': {
        'title': 'Sessão de RPG',
        'body': 'Personagens:\n\nAcontecimentos:\n\nPistas e ideias:\n',
        'check': false,
      },
      'diario': {
        'title': DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'body': 'Como foi meu dia?\n\n',
        'check': false,
      },
    };
    final templateData = templates[template]!;
    final fresh = note ??
        Note(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: templateData['title'],
          body: templateData['body'],
          checklist: templateData['check'],
          updatedAt: DateTime.now(),
          folder: folder == 'Todas' ? 'Geral' : folder,
          tags: tag == 'Todas' ? const [] : [tag],
          font: widget.store.font,
        );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPage(
          store: widget.store,
          note: fresh,
          isNew: note == null,
        ),
      ),
    );
  }

  Future<void> createNote() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Criar',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text('Escolhe um ponto de partida.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _CreateOption(
                icon: Icons.note_add_outlined,
                title: 'Nota',
                subtitle: 'Começa em branco',
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNote();
                },
              ),
              _CreateOption(
                icon: Icons.checklist_rounded,
                title: 'Checklist',
                subtitle: 'Lista com itens marcáveis',
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNote(null, 'checklist');
                },
              ),
              _CreateOption(
                icon: Icons.school_outlined,
                title: 'Estudo',
                subtitle: 'Resumo já estruturado',
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNote(null, 'estudo');
                },
              ),
              _CreateOption(
                icon: Icons.auto_awesome_outlined,
                title: 'RPG',
                subtitle: 'Sessão, personagens e pistas',
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNote(null, 'rpg');
                },
              ),
              _CreateOption(
                icon: Icons.menu_book_outlined,
                title: 'Diário',
                subtitle: 'Entrada com a data de hoje',
                onTap: () {
                  Navigator.pop(sheetContext);
                  openNote(null, 'diario');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openLayoutSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personalizar início',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text('Deixa só o que realmente te ajuda.'),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.bolt_rounded),
                  title: const Text('Noto Pulse'),
                  subtitle: const Text('Padrões e pendências úteis'),
                  value: widget.store.homeShowPulse,
                  onChanged: (value) {
                    setModalState(() => widget.store.homeShowPulse = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.query_stats_rounded),
                  title: const Text('Resumo rápido'),
                  subtitle: const Text('Ativas, fixadas, favoritas e tarefas'),
                  value: widget.store.homeShowSummary,
                  onChanged: (value) {
                    setModalState(() => widget.store.homeShowSummary = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.folder_copy_outlined),
                  title: const Text('Pastas'),
                  value: widget.store.homeShowFolders,
                  onChanged: (value) {
                    setModalState(() => widget.store.homeShowFolders = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.tag_rounded),
                  title: const Text('Tags'),
                  value: widget.store.homeShowTags,
                  onChanged: (value) {
                    setModalState(() => widget.store.homeShowTags = value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await widget.store.save();
  }

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = widget.store.wallpaper > 0 ||
        (widget.store.customWallpaper != null &&
            File(widget.store.customWallpaper!).existsSync());
    final notes = visible;
    final availableTags = tags;

    return Scaffold(
      backgroundColor: hasWallpaper ? Colors.transparent : null,
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('assets/app_icon.png', width: 36, height: 36),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.favoritesOnly ? 'Favoritas' : 'Noto',
                  style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900),
                ),
                Text(
                  widget.favoritesOnly
                      ? '${notes.length} salvas por ti'
                      : '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!widget.favoritesOnly)
            IconButton(
              tooltip: 'Personalizar início',
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: _openLayoutSheet,
            ),
          IconButton(
            tooltip: widget.store.grid ? 'Usar lista' : 'Usar grade',
            icon: Icon(
              widget.store.grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
            ),
            onPressed: () {
              widget.store.grid = !widget.store.grid;
              widget.store.save();
            },
          ),
          PopupMenuButton<int>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.swap_vert_rounded),
            onSelected: (value) => setState(() => sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 0, child: Text('Mais recentes')),
              PopupMenuItem(value: 1, child: Text('Por nome')),
              PopupMenuItem(value: 2, child: Text('Mais antigas')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (!widget.favoritesOnly && widget.store.homeShowPulse)
              _PulseStrip(notes: activeNotes),
            if (!widget.favoritesOnly && widget.store.homeShowSummary)
              _HomeSummary(notes: activeNotes),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Buscar notas, tags ou conteúdo',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => query = value),
              ),
            ),
            if (widget.store.homeShowFolders)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: folders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final value = folders[index];
                    return ChoiceChip(
                      avatar: value == 'Todas'
                          ? const Icon(Icons.folder_copy_outlined, size: 17)
                          : value.contains('/')
                              ? const Icon(Icons.subdirectory_arrow_right_rounded, size: 17)
                              : null,
                      label: Text(value),
                      selected: folder == value,
                      onSelected: (_) => setState(() => folder = value),
                    );
                  },
                ),
              ),
            if (widget.store.homeShowTags && availableTags.length > 1) ...[
              const SizedBox(height: 7),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: availableTags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) {
                    final value = availableTags[index];
                    return FilterChip(
                      label: Text(value == 'Todas' ? 'Todas as tags' : '#$value'),
                      selected: tag == value,
                      onSelected: (_) => setState(() => tag = value),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Expanded(
              child: notes.isEmpty
                  ? _EmptyState(
                      favorites: widget.favoritesOnly,
                      searching: query.trim().isNotEmpty ||
                          folder != 'Todas' ||
                          tag != 'Todas',
                      onCreate: createNote,
                    )
                  : widget.store.grid
                      ? GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: .84,
                          ),
                          itemCount: notes.length,
                          itemBuilder: (_, index) => NoteCard(
                            note: notes[index],
                            store: widget.store,
                            onOpen: () => openNote(notes[index]),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                          itemCount: notes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, index) => NoteCard(
                            note: notes[index],
                            store: widget.store,
                            wide: true,
                            onOpen: () => openNote(notes[index]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.favoritesOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: createNote,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Nova nota',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
    );
  }
}

class _PulseStrip extends StatelessWidget {
  const _PulseStrip({required this.notes});
  final List<Note> notes;

  IconData _icon(PulseKind kind) => switch (kind) {
        PulseKind.checklist => Icons.checklist_rounded,
        PulseKind.stale => Icons.history_toggle_off_rounded,
        PulseKind.folder => Icons.folder_special_outlined,
        PulseKind.links => Icons.hub_outlined,
        PulseKind.momentum => Icons.bolt_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final insights = buildPulseInsights(notes);
    final primary = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: insights.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final insight = insights[index];
            return Container(
              width: 255,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHigh
                    .withValues(alpha: .92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: primary.withValues(alpha: .18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon(insight.kind), color: primary),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          insight.detail,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HomeSummary extends StatelessWidget {
  const _HomeSummary({required this.notes});
  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final pinned = notes.where((note) => note.pinned).length;
    final favorites = notes.where((note) => note.favorite).length;
    var pending = 0;
    for (final note in notes.where((note) => note.checklist)) {
      pending += note.body.split('\n').where((line) => line.trim().startsWith('[ ]')).length;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          _SummaryPill(icon: Icons.notes_rounded, value: '${notes.length}', label: 'ativas'),
          const SizedBox(width: 8),
          _SummaryPill(icon: Icons.push_pin_outlined, value: '$pinned', label: 'fixadas'),
          const SizedBox(width: 8),
          _SummaryPill(icon: Icons.star_outline_rounded, value: '$favorites', label: 'favoritas'),
          const SizedBox(width: 8),
          _SummaryPill(icon: Icons.check_box_outlined, value: '$pending', label: 'pendentes'),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14),
                  const SizedBox(width: 4),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        ),
      );
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        onTap: onTap,
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.favorites,
    required this.searching,
    required this.onCreate,
  });

  final bool favorites;
  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final icon = searching
        ? Icons.search_off_rounded
        : (favorites ? Icons.star_outline_rounded : Icons.note_alt_outlined);
    final title = searching
        ? 'Nada por aqui'
        : (favorites ? 'Nenhuma favorita ainda' : 'Teu espaço começa aqui');
    final subtitle = searching
        ? 'Tenta outra busca ou muda os filtros.'
        : (favorites
            ? 'Marca uma nota com estrela e ela aparece aqui.'
            : 'Cria a primeira nota. O resto tu ajeita depois.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 70,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .65),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center),
            if (!searching && !favorites) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar nota'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({
    super.key,
    required this.note,
    required this.store,
    required this.onOpen,
    this.wide = false,
  });

  final Note note;
  final AppStore store;
  final VoidCallback onOpen;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final wallpaper = noteWallpaper(note);
    final colorIndex = note.color.clamp(0, NotoAppearance.noteColors.length - 1);
    final baseColor = colorIndex == 0
        ? Theme.of(context).cardTheme.color!
        : NotoAppearance.noteColors[colorIndex];
    final automaticText = wallpaper != null
        ? Colors.white
        : (colorIndex == 0
            ? Theme.of(context).colorScheme.onSurface
            : const Color(0xFF171717));
    final textIndex = note.textColor.clamp(0, NotoAppearance.textColors.length - 1);
    final foreground = textIndex == 0
        ? automaticText
        : NotoAppearance.textColors[textIndex];
    final family = NotoAppearance.familyAt(note.font);
    final checklistLines = note.body
        .split('\n')
        .where((line) => line.trim().startsWith('['))
        .toList();
    final checked = checklistLines
        .where((line) => line.trim().startsWith('[x]'))
        .length;
    final links = extractWikiLinks(note.body).length;
    final revisions = store.historyFor(note).length;

    final preview = Text(
      note.body.trim().isEmpty
          ? 'Nota vazia'
          : note.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'),
      maxLines: wide ? 2 : 7,
      overflow: TextOverflow.fade,
      style: TextStyle(
        fontFamily: family,
        color: foreground.withValues(alpha: .88),
        height: 1.42,
      ),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      color: baseColor,
      child: Ink(
        decoration: BoxDecoration(
          color: baseColor,
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
          onTap: onOpen,
          onLongPress: () => _showActions(context),
          child: Padding(
            padding: EdgeInsets.all(wide ? 16 : 17),
            child: Column(
              mainAxisSize: wide ? MainAxisSize.min : MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isEmpty ? 'Sem título' : note.title,
                        maxLines: wide ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: family,
                          color: foreground,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (note.favorite)
                      Icon(
                        Icons.star_rounded,
                        size: 17,
                        color: foreground.withValues(alpha: .85),
                      ),
                    if (note.pinned) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.push_pin_rounded,
                        size: 16,
                        color: foreground.withValues(alpha: .7),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                if (wide) preview else Expanded(child: preview),
                if (note.checklist && checklistLines.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: checked / checklistLines.length,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: foreground.withValues(alpha: .8),
                    backgroundColor: foreground.withValues(alpha: .18),
                  ),
                ],
                if (note.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    note.tags.take(3).map((item) => '#$item').join('  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground.withValues(alpha: .72),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.folder,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground.withValues(alpha: .65),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (links > 0) ...[
                      Icon(Icons.link_rounded, size: 12, color: foreground.withValues(alpha: .62)),
                      Text('$links', style: TextStyle(color: foreground.withValues(alpha: .62), fontSize: 10)),
                      const SizedBox(width: 7),
                    ],
                    if (revisions > 0) ...[
                      Icon(Icons.history_rounded, size: 12, color: foreground.withValues(alpha: .62)),
                      Text('$revisions', style: TextStyle(color: foreground.withValues(alpha: .62), fontSize: 10)),
                      const SizedBox(width: 7),
                    ],
                    Text(
                      DateFormat('dd/MM').format(note.updatedAt),
                      style: TextStyle(
                        color: foreground.withValues(alpha: .65),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
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

  void _showActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.drive_file_move_outline),
              title: const Text('Organizar'),
              subtitle: const Text('Pasta, subpasta e tags'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showOrganize(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: const Text('Conexões'),
              subtitle: const Text('Links e backlinks entre notas'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showConnections(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Histórico'),
              subtitle: Text('${store.historyFor(note).length} versões guardadas'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showHistory(context);
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(note.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(
                note.favorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                note.favorite = !note.favorite;
                store.save();
              },
            ),
            ListTile(
              leading: Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded),
              title: Text(note.pinned ? 'Desafixar' : 'Fixar no topo'),
              onTap: () {
                Navigator.pop(sheetContext);
                store.togglePin(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicar'),
              onTap: () {
                Navigator.pop(sheetContext);
                store.duplicate(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Arquivar'),
              onTap: () {
                Navigator.pop(sheetContext);
                store.archive(note);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
              title: const Text(
                'Mover para lixeira',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                store.delete(note);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Nota movida para a lixeira'),
                    action: SnackBarAction(
                      label: 'DESFAZER',
                      onPressed: () => store.restore(note),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOrganize(BuildContext context) async {
    final folderController = TextEditingController(text: note.folder);
    final tagsController = TextEditingController(text: note.tags.join(', '));
    final existingFolders = <String>{
      for (final item in store.notes)
        if (item.deletedAt == null && item.folder.trim().isNotEmpty) item.folder.trim(),
    }.toList()
      ..sort();

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Organizar nota',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text('Usa / para criar subpastas. Ex.: Escola/Química'),
              const SizedBox(height: 16),
              TextField(
                controller: folderController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Pasta ou caminho',
                  prefixIcon: Icon(Icons.folder_outlined),
                ),
              ),
              if (existingFolders.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: existingFolders.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 7),
                    itemBuilder: (_, index) => ActionChip(
                      label: Text(existingFolders[index]),
                      onPressed: () => folderController.text = existingFolders[index],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags',
                  hintText: 'escola, química, prova',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Salvar organização'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (shouldSave == true) {
      final cleanFolder = folderController.text
          .split('/')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join('/');
      final values = tagsController.text
          .split(RegExp(r'[,#\n]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty);
      final seen = <String>{};
      final cleanTags = <String>[];
      for (final value in values) {
        if (seen.add(value.toLowerCase())) cleanTags.add(value);
        if (cleanTags.length == 12) break;
      }
      note.folder = cleanFolder.isEmpty ? 'Geral' : cleanFolder;
      note.tags = cleanTags;
      note.updatedAt = DateTime.now();
      await store.save();
    }
    folderController.dispose();
    tagsController.dispose();
  }

  Future<void> _showConnections(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final outbound = extractWikiLinks(note.body);
          final backlinks = backlinksFor(note, store.notes);
          final candidates = store.notes
              .where((item) =>
                  item.deletedAt == null &&
                  item.id != note.id &&
                  item.title.trim().isNotEmpty)
              .toList()
            ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .74,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Conexões',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: candidates.isEmpty
                            ? null
                            : () async {
                                final target = await showModalBottomSheet<Note>(
                                  context: context,
                                  builder: (pickerContext) => SafeArea(
                                    child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: candidates.length,
                                      itemBuilder: (_, index) {
                                        final target = candidates[index];
                                        return ListTile(
                                          leading: const Icon(Icons.note_alt_outlined),
                                          title: Text(target.title),
                                          subtitle: Text(target.folder),
                                          onTap: () => Navigator.pop(pickerContext, target),
                                        );
                                      },
                                    ),
                                  ),
                                );
                                if (target == null) return;
                                final marker = '[[${target.title.trim()}]]';
                                if (!extractWikiLinks(note.body).any(
                                  (item) => item.toLowerCase() == target.title.trim().toLowerCase(),
                                )) {
                                  final separator = note.body.trim().isEmpty ? '' : '\n\n';
                                  note.body = '${note.body}$separator$marker';
                                  note.updatedAt = DateTime.now();
                                  await store.save();
                                  setModalState(() {});
                                }
                              },
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Conectar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Também dá pra escrever [[Nome da nota]] direto no texto.'),
                  const SizedBox(height: 20),
                  Text(
                    'SAINDO DESTA NOTA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  if (outbound.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.link_off_rounded),
                      title: Text('Nenhum link ainda'),
                    )
                  else
                    ...outbound.map((title) {
                      final target = noteByTitle(store.notes, title);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          target == null ? Icons.link_off_rounded : Icons.arrow_outward_rounded,
                        ),
                        title: Text(title),
                        subtitle: Text(target == null ? 'Nota não encontrada' : target.folder),
                        onTap: target == null
                            ? null
                            : () {
                                Navigator.pop(sheetContext);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditorPage(
                                      store: store,
                                      note: target,
                                      isNew: false,
                                    ),
                                  ),
                                );
                              },
                      );
                    }),
                  const Divider(height: 28),
                  Text(
                    'APONTANDO PRA ESTA NOTA',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 7),
                  if (backlinks.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.call_received_rounded),
                      title: Text('Nenhum backlink ainda'),
                    )
                  else
                    ...backlinks.map(
                      (source) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.call_received_rounded),
                        title: Text(source.title.trim().isEmpty ? 'Sem título' : source.title),
                        subtitle: Text(source.folder),
                        onTap: () {
                          Navigator.pop(sheetContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditorPage(
                                store: store,
                                note: source,
                                isNew: false,
                              ),
                            ),
                          );
                        },
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

  Future<void> _showHistory(BuildContext context) async {
    final history = store.historyFor(note);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Histórico',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          Text('${history.length} de até 20 versões guardadas'),
                        ],
                      ),
                    ),
                    if (history.isNotEmpty)
                      IconButton(
                        tooltip: 'Limpar histórico',
                        icon: const Icon(Icons.delete_sweep_outlined),
                        onPressed: () async {
                          await store.clearHistory(note);
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: history.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text(
                            'Ainda não tem versão anterior. Depois da próxima edição ela aparece aqui.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                        itemCount: history.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final revision = history[index];
                          return ListTile(
                            leading: const Icon(Icons.restore_page_outlined),
                            title: Text(
                              revision.title.trim().isEmpty ? 'Sem título' : revision.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${DateFormat('dd/MM/yyyy HH:mm').format(revision.savedAt)}\n'
                              '${revision.body.trim().isEmpty ? 'Nota vazia' : revision.body.replaceAll('\n', ' ')}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Restaurar esta versão',
                              icon: const Icon(Icons.history_rounded),
                              onPressed: () async {
                                await store.restoreRevision(note, revision);
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Versão restaurada')),
                                  );
                                }
                              },
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
