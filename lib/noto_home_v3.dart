import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'noto_editor_v2.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_settings_v3.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

enum _NoteScope { all, favorites, pinned }

class HomeShellV3 extends StatefulWidget {
  const HomeShellV3({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShellV3> createState() => _HomeShellV3State();
}

class _HomeShellV3State extends State<HomeShellV3> {
  bool searching = false;
  String query = '';
  _NoteScope scope = _NoteScope.all;
  String? folder;
  String? tag;

  List<Note> get _active => widget.store.notes
      .where((note) => note.deletedAt == null && !note.archived)
      .toList();

  List<Note> get _visible {
    final normalized = query.trim().toLowerCase();
    final list = _active.where((note) {
      if (scope == _NoteScope.favorites && !note.favorite) return false;
      if (scope == _NoteScope.pinned && !note.pinned) return false;
      if (folder != null && note.folder != folder) return false;
      if (tag != null && !note.tags.any((item) => item.toLowerCase() == tag!.toLowerCase())) {
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

  bool get _hasFilters => scope != _NoteScope.all || folder != null || tag != null;

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
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Captura rápida',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vai direto pra Entrada.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Escreve e salva.'),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) Navigator.pop(sheetContext, value.trim());
                },
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
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty) return;

    final firstLine = text.split('\n').first.trim();
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: firstLine.length <= 48 ? firstLine : '${firstLine.substring(0, 45)}…',
      body: text,
      updatedAt: DateTime.now(),
      folder: 'Entrada',
      font: widget.store.font,
    );
    widget.store.notes.add(note);
    await widget.store.save();
  }

  Future<void> _createNote() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nova nota',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
              ),
              const SizedBox(height: 8),
              _CreateRow(
                title: 'Captura rápida',
                subtitle: 'Anota sem abrir o editor',
                onTap: () => Navigator.pop(sheetContext, 'quick'),
              ),
              _CreateRow(
                title: 'Em branco',
                subtitle: 'Começa do zero',
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
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'quick') {
      await _quickCapture();
      return;
    }

    var title = '';
    var body = '';
    var checklist = false;

    switch (choice) {
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
      case 'blank':
        break;
    }

    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      updatedAt: DateTime.now(),
      checklist: checklist,
      font: widget.store.font,
    );
    await _openNote(note, isNew: true);
  }

  Future<void> _showFilters() async {
    final folders = <String>{
      for (final note in _active)
        if (note.folder.trim().isNotEmpty) note.folder.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final tags = <String>{
      for (final note in _active)
        for (final item in note.tags)
          if (item.trim().isNotEmpty) item.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    var draftScope = scope;
    var draftFolder = folder;
    var draftTag = tag;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      onPressed: () {
                        setModalState(() {
                          draftScope = _NoteScope.all;
                          draftFolder = null;
                          draftTag = null;
                        });
                      },
                      child: const Text('Limpar'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                RadioListTile<_NoteScope>(
                  contentPadding: EdgeInsets.zero,
                  value: _NoteScope.all,
                  groupValue: draftScope,
                  title: const Text('Todas'),
                  onChanged: (value) => setModalState(() => draftScope = value!),
                ),
                RadioListTile<_NoteScope>(
                  contentPadding: EdgeInsets.zero,
                  value: _NoteScope.favorites,
                  groupValue: draftScope,
                  title: const Text('Favoritas'),
                  onChanged: (value) => setModalState(() => draftScope = value!),
                ),
                RadioListTile<_NoteScope>(
                  contentPadding: EdgeInsets.zero,
                  value: _NoteScope.pinned,
                  groupValue: draftScope,
                  title: const Text('Fixadas'),
                  onChanged: (value) => setModalState(() => draftScope = value!),
                ),
                if (folders.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Pasta', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: draftFolder,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Qualquer pasta')),
                      ...folders.map((value) => DropdownMenuItem<String?>(value: value, child: Text(value))),
                    ],
                    onChanged: (value) => setModalState(() => draftFolder = value),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text('Tag', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    initialValue: draftTag,
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('Qualquer tag')),
                      ...tags.map((value) => DropdownMenuItem<String?>(value: value, child: Text('#$value'))),
                    ],
                    onChanged: (value) => setModalState(() => draftTag = value),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
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

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsPageV3(store: widget.store)),
    );
  }

  bool get _hasWallpaper {
    final custom = widget.store.customWallpaper;
    return widget.store.wallpaper > 0 ||
        (custom != null && File(custom).existsSync());
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: widget.store,
        builder: (_, __) {
          final active = _active;
          final notes = _visible;
          final snapshot = buildTodaySnapshot(active);
          final insights = buildPulseInsights(active);
          final inbox = active.where((note) => note.folder == 'Entrada').length;

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
                  icon: Icon(searching ? Icons.close_rounded : Icons.search_rounded),
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
                        decoration: const InputDecoration(hintText: 'Buscar no Noto'),
                        onChanged: (value) => setState(() => query = value),
                      ),
                    ),
                  if (widget.store.homeShowToday)
                    _TodayLine(snapshot: snapshot, inbox: inbox),
                  if (widget.store.homeShowPulse && insights.isNotEmpty)
                    _PulseLine(insight: insights.first),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _hasFilters ? '${notes.length} filtradas' : '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: .58),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        if (_hasFilters)
                          TextButton(
                            onPressed: () => setState(() {
                              scope = _NoteScope.all;
                              folder = null;
                              tag = null;
                            }),
                            child: const Text('Limpar filtros'),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: notes.isEmpty
                        ? _EmptyNotes(filtered: _hasFilters || query.trim().isNotEmpty)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                            itemCount: notes.length,
                            separatorBuilder: (_, __) => Divider(
                              color: Theme.of(context).colorScheme.outlineVariant,
                            ),
                            itemBuilder: (_, index) => _NoteRow(
                              note: notes[index],
                              onTap: () => _openNote(notes[index]),
                            ),
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
              style: TextStyle(color: cs.onSurface.withValues(alpha: .62)),
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
                    color: cs.onSurface.withValues(alpha: .68),
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wallpaper = noteWallpaper(note);
    final preview = note.body
        .replaceAll('[ ]', '☐')
        .replaceAll('[x]', '☑')
        .replaceAll('\n', ' ')
        .trim();
    final pending = note.checklist
        ? note.body.split('\n').where((line) => line.trim().startsWith('[ ]')).length
        : 0;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w750,
                          ),
                        ),
                      ),
                      if (note.pinned)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.push_pin_outlined,
                            size: 15,
                            color: cs.onSurface.withValues(alpha: .42),
                          ),
                        ),
                      if (note.favorite)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: cs.primary,
                          ),
                        ),
                    ],
                  ),
                  if (preview.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: .58),
                            height: 1.35,
                          ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        note.folder,
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: .48),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (pending > 0)
                        Text(
                          '$pending pendentes',
                          style: TextStyle(
                            color: cs.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ...note.tags.take(2).map(
                            (item) => Text(
                              '#$item',
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: .48),
                                fontSize: 10,
                              ),
                            ),
                          ),
                      Text(
                        DateFormat('dd/MM').format(note.updatedAt),
                        style: TextStyle(
                          color: cs.onSurface.withValues(alpha: .42),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (wallpaper != null) ...[
              const SizedBox(width: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image(
                  image: wallpaper,
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                  color: Colors.black.withValues(alpha: note.wallpaperDarkness * .35),
                  colorBlendMode: BlendMode.darken,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
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
              bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .36),
              ),
            ],
          ),
        ),
      );
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({required this.filtered});

  final bool filtered;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                filtered ? 'Nada nesse recorte.' : 'Ainda não tem nada aqui.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                filtered
                    ? 'Limpa os filtros ou tenta outra busca.'
                    : 'Toca no + e escreve a primeira nota.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}
