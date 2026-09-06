import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_editor_v2.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_settings.dart' as legacy;
import 'noto_settings_v4.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

enum _NoteScope { all, favorites, pinned }

class HomeShellV4 extends StatefulWidget {
  const HomeShellV4({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShellV4> createState() => _HomeShellV4State();
}

class _HomeShellV4State extends State<HomeShellV4> {
  bool searching = false;
  String query = '';
  _NoteScope scope = _NoteScope.all;
  String? folder;
  String? tag;

  final Set<String> savedFolders = {'Geral', 'Entrada'};
  final Set<String> savedTags = {};

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList('notoSavedFolders') ?? const <String>[];
    final tags = prefs.getStringList('notoSavedTags') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      savedFolders.addAll(folders.where((item) => item.trim().isNotEmpty));
      savedTags.addAll(tags.where((item) => item.trim().isNotEmpty));
    });
  }

  Future<void> _saveCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final folders = savedFolders.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final tags = savedTags.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    await prefs.setStringList('notoSavedFolders', folders);
    await prefs.setStringList('notoSavedTags', tags);
  }

  List<Note> get _active => widget.store.notes
      .where((note) => note.deletedAt == null && !note.archived)
      .toList();

  List<Note> get _visible {
    final normalized = query.trim().toLowerCase();
    final list = _active.where((note) {
      if (scope == _NoteScope.favorites && !note.favorite) return false;
      if (scope == _NoteScope.pinned && !note.pinned) return false;
      if (folder != null && note.folder != folder) return false;
      if (tag != null &&
          !note.tags.any((item) => item.toLowerCase() == tag!.toLowerCase())) {
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
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  bool get _hasFilters =>
      scope != _NoteScope.all || folder != null || tag != null;

  bool get _hasWallpaper {
    final custom = widget.store.customWallpaper;
    return widget.store.wallpaper > 0 ||
        (custom != null && File(custom).existsSync());
  }

  List<String> get _allFolders {
    final values = <String>{...savedFolders};
    for (final note in _active) {
      if (note.folder.trim().isNotEmpty) values.add(note.folder.trim());
    }
    return values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> get _allTags {
    final values = <String>{...savedTags};
    for (final note in _active) {
      for (final item in note.tags) {
        if (item.trim().isNotEmpty) values.add(item.trim());
      }
    }
    return values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _openNote(Note note, {bool isNew = false}) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditorPageV2(
          store: widget.store,
          note: note,
          isNew: isNew,
        ),
      ),
    );
  }

  Future<void> _quickCapture() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Captura rápida',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('Vai direto pra Entrada.'),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Escreve e salva.'),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(sheetContext, value);
                },
                child: const Text('Salvar'),
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;

    final firstLine = text.split('\n').first.trim();
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: firstLine.length <= 48
          ? firstLine
          : '${firstLine.substring(0, 45)}…',
      body: text,
      updatedAt: DateTime.now(),
      folder: 'Entrada',
      font: widget.store.font,
    );
    widget.store.notes.add(note);
    savedFolders.add('Entrada');
    await _saveCollections();
    await widget.store.save();
  }

  Future<void> _createNote() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final bottom = MediaQuery.viewPaddingOf(sheetContext).bottom;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(20, 14, 20, bottom + 30),
            children: [
              Text(
                'Nova nota',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              _CreateRow(
                title: 'Captura rápida',
                subtitle: 'Anota sem abrir o editor',
                onTap: () => Navigator.pop(sheetContext, 'quick'),
              ),
              _CreateRow(
                title: 'Em branco',
                subtitle: folder != null
                    ? 'Já entra em $folder'
                    : tag != null
                        ? 'Já recebe #$tag'
                        : 'Começa do zero',
                onTap: () => Navigator.pop(sheetContext, 'blank'),
              ),
              _CreateRow(
                title: 'Checklist',
                subtitle: 'Lista marcável',
                onTap: () => Navigator.pop(sheetContext, 'checklist'),
              ),
              _CreateRow(
                title: 'Estudo',
                subtitle: 'Tema, pontos principais e dúvidas',
                onTap: () => Navigator.pop(sheetContext, 'study'),
              ),
              _CreateRow(
                title: 'RPG',
                subtitle: 'Sessão, acontecimentos e pistas',
                onTap: () => Navigator.pop(sheetContext, 'rpg'),
              ),
              _CreateRow(
                title: 'Diário',
                subtitle: 'Entrada com a data de hoje',
                onTap: () => Navigator.pop(sheetContext, 'diary'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || choice == null) return;
    if (choice == 'quick') {
      await _quickCapture();
      return;
    }

    var title = '';
    var body = '';
    var checklist = false;
    if (choice == 'checklist') {
      title = 'Minha lista';
      body = '[ ] Primeiro item';
      checklist = true;
    } else if (choice == 'study') {
      title = 'Resumo de estudo';
      body = 'Tema:\n\nPontos principais:\n• \n\nDúvidas:\n';
    } else if (choice == 'rpg') {
      title = 'Sessão de RPG';
      body = 'Personagens:\n\nAcontecimentos:\n\nPistas e ideias:\n';
    } else if (choice == 'diary') {
      title = DateFormat('dd/MM/yyyy').format(DateTime.now());
      body = 'Como foi meu dia?\n\n';
    }

    final targetFolder = folder ?? 'Geral';
    final targetTags = tag == null ? <String>[] : <String>[tag!];
    savedFolders.add(targetFolder);
    savedTags.addAll(targetTags);
    await _saveCollections();

    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      folder: targetFolder,
      tags: targetTags,
      checklist: checklist,
      font: widget.store.font,
    );
    await _openNote(note, isNew: true);
  }

  Future<String?> _askName(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (text) {
            final clean = text.trim();
            if (clean.isNotEmpty) Navigator.pop(dialogContext, clean);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final clean = controller.text.trim();
              if (clean.isNotEmpty) Navigator.pop(dialogContext, clean);
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _createFolder() async {
    final raw = await _askName('Nova pasta', 'Ex.: Escola/Química');
    if (raw == null) return;
    final clean = raw
        .split('/')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .join('/');
    if (clean.isEmpty) return;
    savedFolders.add(clean);
    await _saveCollections();
    if (!mounted) return;
    setState(() {
      scope = _NoteScope.all;
      folder = clean;
      tag = null;
    });
  }

  Future<void> _createTag() async {
    final raw = await _askName('Nova tag', 'Ex.: prova');
    if (raw == null) return;
    final clean = raw.replaceAll('#', '').trim();
    if (clean.isEmpty) return;
    savedTags.add(clean);
    await _saveCollections();
    if (!mounted) return;
    setState(() {
      scope = _NoteScope.all;
      tag = clean;
      folder = null;
    });
  }

  Future<void> _showFilters() async {
    var draftScope = scope;
    var draftFolder = folder;
    var draftTag = tag;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
          ),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              MediaQuery.viewPaddingOf(sheetContext).bottom + 28,
            ),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filtrar notas',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setModalState(() {
                      draftScope = _NoteScope.all;
                      draftFolder = null;
                      draftTag = null;
                    }),
                    child: const Text('Limpar'),
                  ),
                ],
              ),
              RadioListTile<_NoteScope>(
                contentPadding: EdgeInsets.zero,
                value: _NoteScope.all,
                groupValue: draftScope,
                title: const Text('Todas'),
                onChanged: (value) =>
                    setModalState(() => draftScope = value ?? _NoteScope.all),
              ),
              RadioListTile<_NoteScope>(
                contentPadding: EdgeInsets.zero,
                value: _NoteScope.favorites,
                groupValue: draftScope,
                title: const Text('Favoritas'),
                onChanged: (value) => setModalState(
                  () => draftScope = value ?? _NoteScope.favorites,
                ),
              ),
              RadioListTile<_NoteScope>(
                contentPadding: EdgeInsets.zero,
                value: _NoteScope.pinned,
                groupValue: draftScope,
                title: const Text('Fixadas'),
                onChanged: (value) => setModalState(
                  () => draftScope = value ?? _NoteScope.pinned,
                ),
              ),
              if (_allFolders.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: draftFolder,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Pasta'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Qualquer pasta'),
                    ),
                    ..._allFolders.map(
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
              if (_allTags.isNotEmpty) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<String?>(
                  initialValue: draftTag,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Tag'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Qualquer tag'),
                    ),
                    ..._allTags.map(
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
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext, true),
                child: const Text('Aplicar'),
              ),
            ],
          ),
        ),
      ),
    );

    if (apply == true) {
      setState(() {
        scope = draftScope;
        folder = draftFolder;
        tag = draftTag;
      });
    }
  }

  void _openSettings() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SettingsPageV4(store: widget.store)),
      );

  void _openArchive() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => legacy.ArchivePage(store: widget.store)),
      );

  void _openTrash() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => legacy.TrashPage(store: widget.store)),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (_, __) {
          final active = _active;
          final notes = _visible;
          final snapshot = buildTodaySnapshot(active);
          final insights = buildPulseInsights(active);
          final inbox = active.where((note) => note.folder == 'Entrada').length;
          final archived = widget.store.notes
              .where((note) => note.archived && note.deletedAt == null)
              .length;
          final trash =
              widget.store.notes.where((note) => note.deletedAt != null).length;

          return Scaffold(
            backgroundColor: _hasWallpaper ? Colors.transparent : null,
            appBar: AppBar(
              titleSpacing: 20,
              title: Row(
                children: [
                  const NotoMark(size: 34),
                  const SizedBox(width: 8),
                  const Text('Noto'),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: searching ? 'Fechar busca' : 'Buscar',
                  onPressed: () => setState(() {
                    searching = !searching;
                    if (!searching) query = '';
                  }),
                  icon: Icon(
                    searching ? Icons.close_rounded : Icons.search_rounded,
                  ),
                ),
                IconButton(
                  tooltip: 'Filtrar',
                  onPressed: _showFilters,
                  icon: Badge(
                    isLabelVisible: _hasFilters,
                    smallSize: 7,
                    child: const Icon(Icons.filter_list_rounded),
                  ),
                ),
                IconButton(
                  tooltip: 'Ajustes',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 6),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  if (searching)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: TextField(
                        autofocus: true,
                        decoration:
                            const InputDecoration(hintText: 'Buscar no Noto'),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                  if (widget.store.homeShowToday)
                    _TodayLine(snapshot: snapshot, inbox: inbox),
                  if (widget.store.homeShowPulse && insights.isNotEmpty)
                    _PulseLine(insight: insights.first),
                  _LibraryShelf(
                    archived: archived,
                    trash: trash,
                    onArchive: _openArchive,
                    onTrash: _openTrash,
                    onCreateFolder: _createFolder,
                    onCreateTag: _createTag,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hasFilters
                                ? '${notes.length} filtradas'
                                : '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        if (folder != null)
                          Flexible(
                            child: Text(
                              folder!,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                        if (tag != null)
                          Text(
                            '#$tag',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w800,
                                    ),
                          ),
                        if (_hasFilters)
                          TextButton(
                            onPressed: () => setState(() {
                              scope = _NoteScope.all;
                              folder = null;
                              tag = null;
                            }),
                            child: const Text('Limpar'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: notes.isEmpty
                        ? _EmptyNotes(
                            filtered: _hasFilters || query.trim().isNotEmpty,
                          )
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 760 ? 3 : 2;
                              return GridView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 0, 20, 110),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 190,
                                ),
                                itemCount: notes.length,
                                itemBuilder: (_, index) => _NoteCard(
                                  note: notes[index],
                                  onTap: () => _openNote(notes[index]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: _createNote,
              tooltip: 'Nova nota',
              child: const Icon(Icons.add_rounded),
            ),
          );
        },
      );
}

class _LibraryShelf extends StatelessWidget {
  const _LibraryShelf({
    required this.archived,
    required this.trash,
    required this.onArchive,
    required this.onTrash,
    required this.onCreateFolder,
    required this.onCreateTag,
  });

  final int archived;
  final int trash;
  final VoidCallback onArchive;
  final VoidCallback onTrash;
  final VoidCallback onCreateFolder;
  final VoidCallback onCreateTag;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: .72),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: .55)),
          bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: .55)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ShelfAction(
              icon: Icons.archive_outlined,
              label: 'Arquivadas',
              detail: '$archived',
              onTap: onArchive,
            ),
          ),
          Expanded(
            child: _ShelfAction(
              icon: Icons.delete_outline_rounded,
              label: 'Lixeira',
              detail: '$trash',
              onTap: onTrash,
            ),
          ),
          Expanded(
            child: _ShelfAction(
              icon: Icons.create_new_folder_outlined,
              label: 'Pasta',
              detail: 'nova',
              onTap: onCreateFolder,
            ),
          ),
          Expanded(
            child: _ShelfAction(
              icon: Icons.new_label_outlined,
              label: 'Tag',
              detail: 'nova',
              onTap: onCreateTag,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShelfAction extends StatelessWidget {
  const _ShelfAction({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Column(
          children: [
            Icon(icon, size: 20, color: cs.onSurface.withValues(alpha: .76)),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
            ),
            Text(
              detail,
              style: TextStyle(
                fontSize: 9,
                color: cs.onSurface.withValues(alpha: .48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.snapshot, required this.inbox});

  final TodaySnapshot snapshot;
  final int inbox;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final parts = <String>[];
    if (snapshot.pendingTasks > 0) parts.add('${snapshot.pendingTasks} pendentes');
    if (snapshot.remindersToday > 0) parts.add('${snapshot.remindersToday} lembretes');
    if (snapshot.overdueReminders > 0) parts.add('${snapshot.overdueReminders} atrasados');
    if (snapshot.touched > 0) parts.add('${snapshot.touched} mexidas hoje');
    if (inbox > 0) parts.add('$inbox na Entrada');
    if (parts.isEmpty) parts.add('nada pendente por aqui');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Hoje  ',
              style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: parts.join(' · '),
              style: TextStyle(color: cs.onSurface.withValues(alpha: .68)),
            ),
          ],
        ),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _PulseLine extends StatelessWidget {
  const _PulseLine({required this.insight});

  final PulseInsight insight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pulse',
            style: TextStyle(
              color: cs.primary,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${insight.title} — ${insight.detail}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withValues(alpha: .72),
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wallpaper = noteWallpaper(note);
    final hasWallpaper = wallpaper != null;
    final noteColor = NotoAppearance.noteColors[
      NotoAppearance.safeNoteColorIndex(note.color)
    ];
    final background = note.color == 0 ? cs.surfaceContainerLow : noteColor;
    final foreground = hasWallpaper ? Colors.white : cs.onSurface;
    final secondary =
        hasWallpaper ? Colors.white70 : cs.onSurface.withValues(alpha: .58);
    final preview = note.body
        .replaceAll('[ ]', '☐')
        .replaceAll('[x]', '☑')
        .replaceAll('\n', ' ')
        .trim();
    final pending = note.checklist
        ? note.body
            .split('\n')
            .where((line) => line.trim().startsWith('[ ]'))
            .length
        : 0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasWallpaper
                ? Colors.white.withValues(alpha: .14)
                : cs.outlineVariant.withValues(alpha: .6),
          ),
          image: hasWallpaper
              ? DecorationImage(
                  image: wallpaper,
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(
                      alpha: (note.wallpaperDarkness + .18).clamp(0.0, .85),
                    ),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title.trim().isEmpty ? 'Sem título' : note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: foreground,
                          fontSize: 16,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (note.pinned)
                      Icon(Icons.push_pin_outlined, size: 15, color: secondary),
                    if (note.favorite) ...[
                      const SizedBox(width: 5),
                      Icon(
                        Icons.star_rounded,
                        size: 15,
                        color: hasWallpaper ? Colors.white : cs.primary,
                      ),
                    ],
                  ],
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
                const Spacer(),
                if (pending > 0)
                  Text(
                    '$pending pendentes',
                    style: TextStyle(
                      color: hasWallpaper ? Colors.white : cs.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  [
                    note.folder,
                    if (note.tags.isNotEmpty) '#${note.tags.first}',
                    DateFormat('dd/MM').format(note.updatedAt),
                  ].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            filtered
                ? 'Nada por aqui com esse filtro.'
                : 'Ainda não tem nota aqui.\nToca no + pra começar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color:
                    Theme.of(context).colorScheme.onSurface.withValues(alpha: .36),
              ),
            ],
          ),
        ),
      );
}
