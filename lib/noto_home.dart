import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_editor.dart';
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
          NavigationDestination(icon: Icon(Icons.sticky_note_2_outlined), selectedIcon: Icon(Icons.sticky_note_2_rounded), label: 'Notas'),
          NavigationDestination(icon: Icon(Icons.star_outline_rounded), selectedIcon: Icon(Icons.star_rounded), label: 'Favoritas'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({super.key, required this.store, this.favoritesOnly = false});
  final AppStore store;
  final bool favoritesOnly;

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  String query = '';
  String folder = 'Todas';
  int sort = 0;

  List<String> get folders => [
        'Todas',
        ...{
          for (final note in widget.store.notes.where((n) => n.deletedAt == null && !n.archived)) note.folder,
        }
      ];

  List<Note> get visible {
    final normalized = query.trim().toLowerCase();
    final list = widget.store.notes.where((note) {
      if (note.deletedAt != null || note.archived) return false;
      if (widget.favoritesOnly && !note.favorite) return false;
      if (folder != 'Todas' && note.folder != folder) return false;
      if (normalized.isEmpty) return true;
      return note.title.toLowerCase().contains(normalized) ||
          note.body.toLowerCase().contains(normalized) ||
          note.tags.any((tag) => tag.toLowerCase().contains(normalized));
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
      'estudo': {'title': 'Resumo de estudo', 'body': 'Tema:\n\nPontos principais:\n• \n\nDúvidas:\n', 'check': false},
      'rpg': {'title': 'Sessão de RPG', 'body': 'Personagens:\n\nAcontecimentos:\n\nPistas e ideias:\n', 'check': false},
      'diario': {'title': DateFormat('dd/MM/yyyy').format(DateTime.now()), 'body': 'Como foi meu dia?\n\n', 'check': false},
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
          font: widget.store.font,
        );

    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditorPage(store: widget.store, note: fresh, isNew: note == null)),
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
              Text('Criar', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Escolhe um ponto de partida.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _CreateOption(icon: Icons.note_add_outlined, title: 'Nota', subtitle: 'Começa em branco', onTap: () { Navigator.pop(sheetContext); openNote(); }),
              _CreateOption(icon: Icons.checklist_rounded, title: 'Checklist', subtitle: 'Lista com itens marcáveis', onTap: () { Navigator.pop(sheetContext); openNote(null, 'checklist'); }),
              _CreateOption(icon: Icons.school_outlined, title: 'Estudo', subtitle: 'Resumo já estruturado', onTap: () { Navigator.pop(sheetContext); openNote(null, 'estudo'); }),
              _CreateOption(icon: Icons.auto_awesome_outlined, title: 'RPG', subtitle: 'Sessão, personagens e pistas', onTap: () { Navigator.pop(sheetContext); openNote(null, 'rpg'); }),
              _CreateOption(icon: Icons.menu_book_outlined, title: 'Diário', subtitle: 'Entrada com a data de hoje', onTap: () { Navigator.pop(sheetContext); openNote(null, 'diario'); }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasWallpaper = widget.store.wallpaper > 0 ||
        (widget.store.customWallpaper != null && File(widget.store.customWallpaper!).existsSync());
    final notes = visible;

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
                Text(widget.favoritesOnly ? 'Favoritas' : 'Noto', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                Text(
                  widget.favoritesOnly ? '${notes.length} salvas por ti' : '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: widget.store.grid ? 'Usar lista' : 'Usar grade',
            icon: Icon(widget.store.grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded),
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
                    label: Text(value),
                    selected: folder == value,
                    onSelected: (_) => setState(() => folder = value),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: notes.isEmpty
                  ? _EmptyState(
                      favorites: widget.favoritesOnly,
                      searching: query.trim().isNotEmpty,
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
              label: const Text('Nova nota', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({required this.icon, required this.title, required this.subtitle, required this.onTap});
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
  const _EmptyState({required this.favorites, required this.searching, required this.onCreate});
  final bool favorites;
  final bool searching;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final icon = searching ? Icons.search_off_rounded : (favorites ? Icons.star_outline_rounded : Icons.note_alt_outlined);
    final title = searching ? 'Nada por aqui' : (favorites ? 'Nenhuma favorita ainda' : 'Teu espaço começa aqui');
    final subtitle = searching
        ? 'Tenta outra busca ou muda a pasta.'
        : (favorites ? 'Marca uma nota com estrela e ela aparece aqui.' : 'Cria a primeira nota. O resto tu ajeita depois.');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 70, color: Theme.of(context).colorScheme.primary.withValues(alpha: .65)),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            Text(subtitle, textAlign: TextAlign.center),
            if (!searching && !favorites) ...[
              const SizedBox(height: 18),
              FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text('Criar nota')),
            ],
          ],
        ),
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.store, required this.onOpen, this.wide = false});
  final Note note;
  final AppStore store;
  final VoidCallback onOpen;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final wallpaper = noteWallpaper(note);
    final colorIndex = note.color.clamp(0, NotoAppearance.noteColors.length - 1);
    final baseColor = colorIndex == 0 ? Theme.of(context).cardTheme.color! : NotoAppearance.noteColors[colorIndex];
    final automaticText = wallpaper != null
        ? Colors.white
        : (colorIndex == 0 ? Theme.of(context).colorScheme.onSurface : const Color(0xFF171717));
    final textIndex = note.textColor.clamp(0, NotoAppearance.textColors.length - 1);
    final foreground = textIndex == 0 ? automaticText : NotoAppearance.textColors[textIndex];
    final family = NotoAppearance.familyAt(note.font);
    final checklistLines = note.body.split('\n').where((line) => line.trim().startsWith('[')).toList();
    final checked = checklistLines.where((line) => line.trim().startsWith('[x]')).length;

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
                  colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: note.wallpaperDarkness), BlendMode.darken),
                ),
        ),
        child: InkWell(
          onTap: onOpen,
          onLongPress: () => _showActions(context),
          child: Padding(
            padding: EdgeInsets.all(wide ? 16 : 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isEmpty ? 'Sem título' : note.title,
                        maxLines: wide ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: family, color: foreground, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    if (note.favorite) Icon(Icons.star_rounded, size: 17, color: foreground.withValues(alpha: .85)),
                    if (note.pinned) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.push_pin_rounded, size: 16, color: foreground.withValues(alpha: .7)),
                    ],
                  ],
                ),
                const SizedBox(height: 9),
                Expanded(
                  child: Text(
                    note.body.trim().isEmpty ? 'Nota vazia' : note.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'),
                    maxLines: wide ? 2 : 7,
                    overflow: TextOverflow.fade,
                    style: TextStyle(fontFamily: family, color: foreground.withValues(alpha: .88), height: 1.42),
                  ),
                ),
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
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.folder,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: foreground.withValues(alpha: .65), fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      DateFormat('dd/MM').format(note.updatedAt),
                      style: TextStyle(color: foreground.withValues(alpha: .65), fontSize: 10, fontWeight: FontWeight.w700),
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
              leading: Icon(note.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
              title: Text(note.favorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos'),
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
              title: const Text('Mover para lixeira', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(sheetContext);
                store.delete(note);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Nota movida para a lixeira'),
                    action: SnackBarAction(label: 'DESFAZER', onPressed: () => store.restore(note)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
