import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_editor.dart';
import 'noto_features.dart';
import 'noto_models.dart';
import 'noto_power_tools.dart';
import 'noto_library.dart';
import 'noto_settings.dart';
import 'noto_smart.dart';
import 'noto_store.dart';
import 'noto_theme.dart';
import 'noto_dictation.dart';
import 'noto_tasks.dart';
import 'noto_vault.dart';

enum _NoteScope { all, favorites, pinned }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int sortOrder = 0;
  final Set<String> selectedIds = {};
  void _select(Note note) => setState(() {
    HapticFeedback.selectionClick();
    if (!selectedIds.add(note.id)) selectedIds.remove(note.id);
  });
  Future<String?> _askText(String title, String label, String action) async {
    var value = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) => value = v.trim(),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) Navigator.pop(ctx, v.trim());
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (value.isNotEmpty) Navigator.pop(ctx, value);
            },
            child: Text(action),
          ),
        ],
      ),
    );
  }

  /// Lista para escolher uma pasta ou tag que já existe, ou criar outra.
  Future<String?> _pickFromList(
    String title,
    List<String> items,
    IconData icon,
    String createLabel,
    Future<String?> Function() create,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(createLabel),
              onTap: () => Navigator.pop(ctx, '\u0000novo'),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.only(
                  bottom: MediaQuery.viewPaddingOf(ctx).bottom + 12,
                ),
                children: [
                  for (final item in items)
                    ListTile(
                      leading: Icon(icon),
                      title: Text(item),
                      onTap: () => Navigator.pop(ctx, item),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == '\u0000novo') return create();
    return picked;
  }

  /// Barra que aparece ao selecionar notas: ações principais com ícone e
  /// nome, e o resto em "Mais".
  Widget _selectionBar() {
    final cs = Theme.of(context).colorScheme;
    final chosen = _active.where((n) => selectedIds.contains(n.id)).toList();
    final allPinned = chosen.isNotEmpty && chosen.every((n) => n.pinned);
    final allSelected = _visible.every((n) => selectedIds.contains(n.id));
    Widget action(String id, IconData icon, String label, {bool danger = false}) =>
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => id == 'more' ? _moreBulk(chosen) : _bulk(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: danger ? cs.error : cs.onSurface),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: danger ? cs.error : cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
    return Material(
      color: cs.surfaceContainerHigh,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Cancelar seleção',
                    onPressed: () => setState(selectedIds.clear),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  Expanded(
                    child: Text(
                      selectedIds.length == 1
                          ? '1 nota selecionada'
                          : '${selectedIds.length} notas selecionadas',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (allSelected) {
                        selectedIds.clear();
                      } else {
                        selectedIds.addAll(_visible.map((n) => n.id));
                      }
                    }),
                    child: Text(allSelected ? 'Desmarcar' : 'Todas'),
                  ),
                ],
              ),
              Row(
                children: [
                  action('move', Icons.drive_file_move_outline, 'Pasta'),
                  action(
                    'pin',
                    allPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    allPinned ? 'Desfixar' : 'Fixar',
                  ),
                  action('archive', Icons.archive_outlined, 'Arquivar'),
                  action(
                    'trash',
                    Icons.delete_outline_rounded,
                    'Lixeira',
                    danger: true,
                  ),
                  action('more', Icons.more_horiz_rounded, 'Mais'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moreBulk(List<Note> chosen) async {
    final allFavorite = chosen.isNotEmpty && chosen.every((n) => n.favorite);
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(String id, IconData icon, String label) => _HubTile(
          icon: icon,
          label: label,
          onTap: () => Navigator.pop(ctx, id),
        );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewPaddingOf(ctx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chosen.length == 1
                    ? 'Mais para 1 nota'
                    : 'Mais para ${chosen.length} notas',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  tile('tag', Icons.label_outline_rounded, 'Adicionar tag'),
                  tile(
                    'favorite',
                    allFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                    allFavorite ? 'Desfavoritar' : 'Favoritar',
                  ),
                  tile('share', Icons.ios_share_rounded, 'Compartilhar'),
                  if (chosen.length >= 2)
                    tile('merge', Icons.call_merge_rounded, 'Juntar'),
                  tile('vault', Icons.lock_outline_rounded, 'Cofre'),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (choice != null && mounted) await _bulk(choice);
  }

  /// Junta as notas escolhidas numa nova; as originais vão para a lixeira.
  Future<void> _mergeNotes(List<Note> chosen) async {
    if (chosen.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha pelo menos 2 notas para juntar.')),
      );
      return;
    }
    final ok = await _confirm(
      'Juntar ${chosen.length} notas?',
      'Vira uma nota nova com tudo junto. As originais vão para a lixeira, '
          'e dá para recuperar de lá.',
      'Juntar',
    );
    if (!ok || !mounted) return;
    final ordered = List.of(chosen)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final parts = <String>[];
    final tables = <dynamic>[];
    final code = <dynamic>[];
    final tags = <String>{};
    for (final note in ordered) {
      parts.add('## ${displayTitle(note)}\n${note.body.trim()}');
      tables.addAll((note.editor['tables'] as List?) ?? const []);
      code.addAll((note.editor['code'] as List?) ?? const []);
      tags.addAll(note.tags);
    }
    final merged = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: 'Notas juntas',
      body: parts.join('\n\n'),
      updatedAt: DateTime.now(),
      folder: ordered.first.folder,
      tags: tags.toList(),
      checklist: ordered.any((n) => n.checklist),
      font: widget.store.font,
      editor: {'tables': tables, 'code': code},
    );
    widget.store.notes.add(merged);
    for (final note in chosen) {
      widget.store.cancelReminder(note);
      note.deletedAt = DateTime.now();
    }
    await widget.store.save();
    if (!mounted) return;
    setState(selectedIds.clear);
    await _openNote(merged);
  }

  Future<void> _bulk(String action) async {
    final chosen = _active.where((n) => selectedIds.contains(n.id)).toList();
    if (chosen.isEmpty) return;
    if (action == 'merge') {
      await _mergeNotes(chosen);
      return;
    }
    if (action == 'share') {
      final text = chosen
          .map((n) => '${displayTitle(n)}\n${readablePreview(n.body)}')
          .join('\n\n———\n\n');
      await Share.share(text);
      if (mounted) setState(selectedIds.clear);
      return;
    }
    final allFavorite = chosen.every((n) => n.favorite);
    final allPinned = chosen.every((n) => n.pinned);
    String? destination;
    String? newTag;
    if (action == 'move') {
      destination = await _pickFromList(
        'Mover para a pasta',
        _allFolders,
        Icons.folder_outlined,
        'Nova pasta',
        () => _askText('Nova pasta', 'Nome da pasta', 'Criar'),
      );
      if (destination == null || !mounted) return;
      destination = _cleanFolder(destination);
      if (destination.isEmpty) return;
      savedFolders.add(destination);
      await _saveCollections();
    }
    if (action == 'tag') {
      newTag = await _pickFromList(
        'Adicionar tag',
        _allTags,
        Icons.label_outline_rounded,
        'Nova tag',
        () => _askText('Nova tag', 'Nome da tag', 'Criar'),
      );
      if (newTag == null || !mounted) return;
      newTag = newTag.replaceAll('#', '').trim();
      if (newTag.isEmpty) return;
      savedTags.add(newTag);
      await _saveCollections();
    }
    if (action == 'vault') {
      final ready = await ensureVault(context, widget.store);
      if (!ready || !mounted) return;
    }

    // Guarda como estava, para o "Desfazer".
    final before = [
      for (final note in chosen)
        (note, note.archived, note.deletedAt, note.reminderAt, note.reminderRepeat),
    ];
    for (final note in chosen) {
      if (action == 'move') note.folder = destination!;
      if (action == 'favorite') note.favorite = !allFavorite;
      if (action == 'pin') note.pinned = !allPinned;
      if (action == 'archive') note.archived = true;
      if (action == 'vault') note.locked = true;
      if (action == 'tag' &&
          !note.tags.any((t) => t.toLowerCase() == newTag!.toLowerCase())) {
        note.tags = [...note.tags, newTag!];
      }
      if (action == 'trash') {
        widget.store.cancelReminder(note);
        note.deletedAt = DateTime.now();
      }
      note.updatedAt = DateTime.now();
    }
    await widget.store.save();
    if (action == 'vault') {
      for (final note in chosen) {
        await widget.store.refreshReminder(note);
      }
    }
    if (!mounted) return;
    setState(selectedIds.clear);
    final count = chosen.length;
    final message = switch (action) {
      'archive' => count == 1 ? '1 nota arquivada' : '$count notas arquivadas',
      'trash' => count == 1
          ? '1 nota na lixeira'
          : '$count notas na lixeira',
      'vault' => count == 1
          ? '1 nota guardada no cofre'
          : '$count notas guardadas no cofre',
      _ => count == 1 ? '1 nota atualizada' : '$count notas atualizadas',
    };
    final undoable = action == 'archive' || action == 'trash';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: undoable
            ? SnackBarAction(
                label: 'Desfazer',
                onPressed: () async {
                  for (final item in before) {
                    item.$1
                      ..archived = item.$2
                      ..deletedAt = item.$3
                      ..reminderAt = item.$4
                      ..reminderRepeat = item.$5;
                  }
                  await widget.store.save();
                  for (final item in before) {
                    if (item.$4 != null) await widget.store.refreshReminder(item.$1);
                  }
                  if (mounted) setState(() {});
                },
              )
            : null,
      ),
    );
  }


  bool searching = false;
  String query = '';
  _NoteScope scope = _NoteScope.all;
  String? folder;
  String? tag;
  bool reminderOnly = false;
  bool checklistOnly = false;
  bool dueOnly = false;
  bool overdueOnly = false;
  int priorityFilter = 0;
  DateTime? updatedFrom;
  DateTime? updatedTo;

  final Set<String> savedFolders = {'Geral'};
  final Set<String> savedTags = {};

  StreamSubscription<Uri?>? _widgetClicks;

  @override
  void initState() {
    super.initState();
    _loadCollections();
    _listenToQuickWidget();
    _listenToShares();
    _setupShortcuts();
    _noteRequests = noteOpenRequests.stream.listen(_openById);
    _snoozes = snoozeRequests.stream.listen(_snooze);
    final snooze = pendingSnooze;
    if (snooze != null) {
      pendingSnooze = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _snooze(snooze));
    }
    final pending = pendingNoteOpen;
    if (pending != null) {
      pendingNoteOpen = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _openById(pending));
    }
  }

  StreamSubscription<String>? _noteRequests;
  StreamSubscription<(String, int)>? _snoozes;
  final _scroll = ScrollController();

  /// "Adiar" na notificação: marca de novo e avisa.
  Future<void> _snooze((String, int) request) async {
    final at = await widget.store.snoozeReminder(request.$1, request.$2);
    if (!mounted || at == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Lembrete adiado para ${DateFormat('HH:mm').format(at)}'),
      ),
    );
  }

  void _scrollToTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Note _blankNote({bool checklist = false}) => Note(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    title: '',
    body: checklist ? '- [ ] ' : '',
    updatedAt: DateTime.now(),
    checklist: checklist,
    folder: folder ?? 'Geral',
    font: widget.store.font,
    color: widget.store.newNoteColor,
  );

  /// Nota do dia (como no Obsidian e no Logseq): uma por dia, na pasta Diário.
  Future<void> _openToday() async {
    final now = DateTime.now();
    final key = dayKey(now);
    for (final note in widget.store.notes) {
      if (note.deletedAt == null && note.editor['daily'] == key) {
        if (note.locked) {
          final ok = await unlockVault(context, widget.store);
          if (!ok || !mounted) return;
        }
        await _openNote(note);
        return;
      }
    }
    savedFolders.add('Diário');
    await _saveCollections();
    if (!mounted) return;
    final weekday = DateFormat('EEEE', 'pt_BR').format(now);
    final note = Note(
      id: now.microsecondsSinceEpoch.toString(),
      title: '${weekday[0].toUpperCase()}${weekday.substring(1)}, '
          '${DateFormat('dd/MM/yyyy').format(now)}',
      body: '',
      updatedAt: now,
      folder: 'Diário',
      font: widget.store.font,
      color: widget.store.newNoteColor,
      editor: {'daily': key},
    );
    await _openNote(note, isNew: true);
  }

  void _openTasks() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AllTasksPage(store: widget.store, onOpen: _openNote),
    ),
  );

  /// Atalhos ao segurar o ícone do Noto: Nova nota, Nova lista e Buscar.
  void _setupShortcuts() {
    try {
      const actions = QuickActions();
      actions.initialize((type) {
        if (!mounted) return;
        if (type == 'buscar') {
          setState(() => searching = true);
          return;
        }
        if (type == 'hoje') {
          _openToday();
          return;
        }
        if (type == 'ultima') {
          final recent = _active
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          if (recent.isNotEmpty) _openNote(recent.first);
          return;
        }
        if (type == 'ditar') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EditorPage(
                store: widget.store,
                note: _blankNote(),
                isNew: true,
                startDictation: true,
              ),
            ),
          );
          return;
        }
        _openNote(_blankNote(checklist: type == 'nova-lista'), isNew: true);
      });
      actions.setShortcutItems(const [
        ShortcutItem(type: 'nova-nota', localizedTitle: 'Nova nota'),
        ShortcutItem(type: 'nova-lista', localizedTitle: 'Nova lista de tarefas'),
        ShortcutItem(type: 'hoje', localizedTitle: 'Nota de hoje'),
        ShortcutItem(type: 'ultima', localizedTitle: 'Última nota editada'),
        ShortcutItem(type: 'ditar', localizedTitle: 'Ditar uma nota'),
      ]);
    } catch (_) {
      /* Sem atalhos nesta plataforma. */
    }
  }
  final _searchController = TextEditingController();

  /// Abre a nota do lembrete tocado. Nota do cofre pede a senha antes.
  Future<void> _openById(String id) async {
    Note? note;
    for (final item in widget.store.notes) {
      if (item.id == id && item.deletedAt == null) {
        note = item;
        break;
      }
    }
    if (note == null || !mounted) return;
    if (note.locked) {
      final ok = await unlockVault(context, widget.store);
      if (!ok || !mounted) return;
    }
    await _openNote(note);
  }

  static const _shareChannel = MethodChannel('noto/share');

  /// Texto compartilhado de outro app ("Compartilhar > Noto") vira uma nota.
  Future<void> _listenToShares() async {
    _shareChannel.setMethodCallHandler((call) async {
      if (call.method == 'sharedText') await _takeShared();
    });
    await _takeShared();
  }

  Future<void> _takeShared() async {
    try {
      final data = await _shareChannel.invokeMapMethod<String, dynamic>(
        'takeSharedText',
      );
      final text = (data?['text'] as String?)?.trim() ?? '';
      if (text.isEmpty || !mounted) return;
      final subject = (data?['subject'] as String?)?.trim() ?? '';
      final firstLine = text.split('\n').first.trim();
      final title = subject.isNotEmpty
          ? subject
          : firstLine.length <= 60
          ? firstLine
          : '${firstLine.substring(0, 57)}…';
      final body = subject.isNotEmpty || text.contains('\n')
          ? text
          : (firstLine.length <= 60 ? '' : text);
      final note = Note(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        body: subject.isNotEmpty ? text : body,
        updatedAt: DateTime.now(),
        folder: folder ?? 'Geral',
        font: widget.store.font,
      );
      await _openNote(note, isNew: true);
    } catch (_) {
      /* Sem compartilhamento nesta plataforma. */
    }
  }

  @override
  void dispose() {
    _widgetClicks?.cancel();
    _noteRequests?.cancel();
    _snoozes?.cancel();
    _scroll.dispose();
    _searchController.dispose();
    _shareChannel.setMethodCallHandler(null);
    super.dispose();
  }

  /// O widget "Nova nota" abre o app com noto://nova-nota.
  Future<void> _listenToQuickWidget() async {
    try {
      _widgetClicks = HomeWidget.widgetClicked.listen(_handleWidgetUri);
      _handleWidgetUri(await HomeWidget.initiallyLaunchedFromHomeWidget());
    } catch (_) {
      /* Sem widgets nesta plataforma. */
    }
  }

  /// Toques nos widgets: nova nota, nova lista, abrir uma nota ou as tarefas.
  void _handleWidgetUri(Uri? uri) {
    if (uri == null || !mounted) return;
    switch (uri.host) {
      case 'nova-nota':
        _openNote(_blankNote(), isNew: true);
      case 'nova-lista':
        _openNote(_blankNote(checklist: true), isNew: true);
      case 'abrir':
        final id = uri.queryParameters['id'];
        if (id != null) _openById(id);
      case 'tarefas':
        _openTasks();
      case 'hoje':
        _openToday();
    }
  }

  Future<void> _loadCollections() async {
    final prefs = await SharedPreferences.getInstance();
    final folders = prefs.getStringList('notoSavedFolders') ?? const <String>[];
    final tags = prefs.getStringList('notoSavedTags') ?? const <String>[];
    if (!mounted) return;
    setState(() {
      sortOrder = prefs.getInt('notoSortOrder') ?? 0;
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

  bool _isOverdue(Note note) {
    final due = note.dueAt;
    if (due == null) return false;
    return DateUtils.dateOnly(due).isBefore(DateUtils.dateOnly(DateTime.now()));
  }

  List<Note> get _active => widget.store.notes
      .where((note) => note.deletedAt == null && !note.archived && !note.locked)
      .toList();

  List<Note> get _visible {
    final normalized = foldForSearch(query.trim());
    final list = _active.where((note) {
      if (scope == _NoteScope.favorites && !note.favorite) return false;
      if (scope == _NoteScope.pinned && !note.pinned) return false;
      if (folder != null && note.folder != folder) return false;
      if (tag != null &&
          !note.tags.any((item) => item.toLowerCase() == tag!.toLowerCase())) {
        return false;
      }
      if (reminderOnly && note.reminderAt == null) return false;
      if (checklistOnly && !note.checklist) return false;
      if (dueOnly && note.dueAt == null) return false;
      if (overdueOnly && !_isOverdue(note)) return false;
      if (priorityFilter > 0 && note.priority != priorityFilter) return false;
      if (updatedFrom != null) {
        final start = DateTime(
          updatedFrom!.year,
          updatedFrom!.month,
          updatedFrom!.day,
        );
        if (note.updatedAt.isBefore(start)) return false;
      }
      if (updatedTo != null) {
        final end = DateTime(
          updatedTo!.year,
          updatedTo!.month,
          updatedTo!.day,
          23,
          59,
          59,
        );
        if (note.updatedAt.isAfter(end)) return false;
      }
      if (normalized.isEmpty) return true;
      // "#escola" busca só nas tags.
      if (normalized.startsWith('#') && normalized.length > 1) {
        final wanted = normalized.substring(1);
        return note.tags.any((item) => foldForSearch(item).startsWith(wanted));
      }
      // Várias palavras: todas precisam aparecer, em qualquer ordem.
      final haystack = [
        foldForSearch(note.title),
        foldForSearch(note.body),
        foldForSearch(note.folder),
        ...note.tags.map(foldForSearch),
        _attachmentText(note),
      ].join(' ');
      return normalized
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .every(haystack.contains);
    }).toList();

    // Com busca, notas que têm a palavra no título aparecem primeiro.
    final firstWord = normalized.split(RegExp(r'\s+')).first;
    bool inTitle(Note note) =>
        firstWord.isNotEmpty && foldForSearch(note.title).contains(firstWord);
    list.sort((a, b) {
      if (normalized.isNotEmpty && inTitle(a) != inTitle(b)) {
        return inTitle(a) ? -1 : 1;
      }
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      if (sortOrder == 1) return a.updatedAt.compareTo(b.updatedAt);
      if (sortOrder == 2)
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (sortOrder == 3)
        return b.title.toLowerCase().compareTo(a.title.toLowerCase());
      if (sortOrder == 4) return b.createdAt.compareTo(a.createdAt);
      if (sortOrder == 6) {
        final ad = a.dueAt, bd = b.dueAt;
        if (ad == null && bd == null) return b.updatedAt.compareTo(a.updatedAt);
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      }
      if (sortOrder == 5) return a.createdAt.compareTo(b.createdAt);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }

  bool get _hasFilters =>
      scope != _NoteScope.all ||
      folder != null ||
      tag != null ||
      reminderOnly ||
      checklistOnly ||
      dueOnly ||
      overdueOnly ||
      priorityFilter > 0 ||
      updatedFrom != null ||
      updatedTo != null;

  void _clearFilters() => setState(() {
    scope = _NoteScope.all;
    folder = null;
    tag = null;
    reminderOnly = false;
    checklistOnly = false;
    dueOnly = false;
    overdueOnly = false;
    priorityFilter = 0;
    updatedFrom = null;
    updatedTo = null;
  });

  bool get _hasWallpaper {
    final custom = widget.store.customWallpaper;
    return widget.store.wallpaper > 0 ||
        FileCache.exists(custom);
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
    if (query.trim().isNotEmpty) widget.store.rememberSearch(query);
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditorPage(store: widget.store, note: note, isNew: isNew),
      ),
    );
  }

  Future<void> _createNote({String? direct}) async {
    final shortcut = direct ??
        switch (widget.store.plusAction) {
          1 => 'blank',
          2 => 'checklist',
          _ => null,
        };
    var canPaste = false;
    if (shortcut == null) {
      try {
        canPaste = await Clipboard.hasStrings();
      } catch (_) {
        /* Sem área de transferência (ex.: testes). */
      }
      if (!mounted) return;
    }
    final choice = shortcut ?? await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.viewPaddingOf(sheetContext).bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nova nota',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            _CreateRow(
              title: 'Em branco',
              subtitle: folder != null
                  ? 'Vai para a pasta $folder'
                  : tag != null
                  ? 'Já vem com a tag #$tag'
                  : 'Nota vazia',
              onTap: () => Navigator.pop(sheetContext, 'blank'),
            ),
            _CreateRow(
              title: 'Lista de tarefas',
              subtitle: 'Com caixas para marcar',
              onTap: () => Navigator.pop(sheetContext, 'checklist'),
            ),
            if (canPaste)
              _CreateRow(
                title: 'Colar o que copiei',
                subtitle: 'Cria a nota com o texto copiado',
                onTap: () => Navigator.pop(sheetContext, 'paste'),
              ),
            if (widget.store.templates.isNotEmpty)
              _CreateRow(
                title: 'Usar um modelo',
                subtitle: widget.store.templates.length == 1
                    ? '1 modelo salvo'
                    : '${widget.store.templates.length} modelos salvos',
                onTap: () => Navigator.pop(sheetContext, 'template'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'template') {
      await _pickTemplate();
      return;
    }

    var pasted = '';
    if (choice == 'paste') {
      pasted = ((await Clipboard.getData(Clipboard.kTextPlain))?.text ?? '')
          .replaceAll('\r\n', '\n')
          .trim();
      if (!mounted) return;
      if (pasted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não tem texto copiado.')),
        );
        return;
      }
    }
    // Texto colado: a primeira linha curta vira o título.
    var pastedTitle = '';
    if (pasted.isNotEmpty) {
      final lines = pasted.split('\n');
      if (lines.length > 1 && lines.first.trim().length <= 60) {
        pastedTitle = lines.first.trim();
        pasted = lines.skip(1).join('\n').trim();
      }
    }
    final checklist =
        choice == 'checklist' || (pasted.isNotEmpty && hasTaskLines(pasted));
    final targetFolder = folder ?? 'Geral';
    final targetTags = tag == null ? <String>[] : <String>[tag!];
    savedFolders.add(targetFolder);
    savedTags.addAll(targetTags);
    await _saveCollections();

    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: pastedTitle,
      body: pasted.isNotEmpty ? pasted : (checklist ? '- [ ] ' : ''),
      updatedAt: DateTime.now(),
      folder: targetFolder,
      tags: targetTags,
      checklist: checklist,
      font: widget.store.font,
      color: widget.store.newNoteColor,
    );
    await _openNote(note, isNew: true);
  }

  Future<void> _pickTemplate() async {
    final selected = await showModalBottomSheet<NotoTemplate>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  'Meus modelos',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              if (widget.store.templates.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Nenhum modelo salvo.'),
                ),
              for (final template in widget.store.templates)
                ListTile(
                  leading: Text(
                    template.emoji.isEmpty ? '📄' : template.emoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                  title: Text(template.name),
                  subtitle: template.title.trim().isEmpty
                      ? null
                      : Text(template.title, maxLines: 1),
                  onTap: () => Navigator.pop(sheetContext, template),
                  trailing: IconButton(
                    tooltip: 'Apagar modelo',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      await widget.store.deleteTemplate(template);
                      setModalState(() {});
                    },
                  ),
                ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(
                  'Para criar um modelo, abra uma nota e use o menu ⋮ > '
                  'Salvar como modelo.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    final note = widget.store.noteFromTemplate(
      selected,
      folder: folder ?? 'Geral',
      tags: tag == null ? const [] : [tag!],
    );
    await _openNote(note, isNew: true);
  }

  Future<String?> _askName(
    String title,
    String hint, {
    String initial = '',
    String action = 'Criar',
  }) async {
    final controller = TextEditingController(text: initial);
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
            child: Text(action),
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

  String _attachmentText(Note note) {
    final parts = <String>[];
    for (final table in (note.editor['tables'] as List?) ?? const []) {
      for (final row in ((table as Map)['cells'] as List?) ?? const []) {
        parts.addAll((row as List).map((cell) => cell.toString()));
      }
    }
    for (final code in (note.editor['code'] as List?) ?? const []) {
      parts.add(((code as Map)['text'] ?? '').toString());
    }
    return foldForSearch(parts.join(' '));
  }

  String _cleanFolder(String raw) => raw
      .split('/')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join('/');

  bool _inFolder(String value, String target) =>
      value == target || value.startsWith('$target/');

  Future<void> _renameFolder(String old) async {
    final raw = await _askName(
      'Renomear pasta',
      'Novo nome',
      initial: old,
      action: 'Salvar',
    );
    if (raw == null) return;
    final clean = _cleanFolder(raw);
    if (clean.isEmpty || clean == old) return;
    String swap(String value) =>
        _inFolder(value, old) ? clean + value.substring(old.length) : value;
    for (final note in widget.store.notes) {
      note.folder = swap(note.folder);
    }
    final renamed = savedFolders.map(swap).toSet();
    savedFolders
      ..clear()
      ..addAll(renamed);
    if (folder != null) folder = swap(folder!);
    await _saveCollections();
    await widget.store.save();
    if (mounted) setState(() {});
  }

  Future<bool> _confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _deleteFolder(String old) async {
    final ok = await _confirm(
      'Apagar a pasta "$old"?',
      'As notas não são apagadas. Elas vão para a pasta Geral.',
      'Apagar pasta',
    );
    if (!ok) return;
    for (final note in widget.store.notes) {
      if (_inFolder(note.folder, old)) note.folder = 'Geral';
    }
    savedFolders.removeWhere((value) => _inFolder(value, old));
    if (folder != null && _inFolder(folder!, old)) folder = null;
    await _saveCollections();
    await widget.store.save();
    if (mounted) setState(() {});
  }

  Future<void> _renameTag(String old) async {
    final raw = await _askName(
      'Renomear tag',
      'Novo nome',
      initial: old,
      action: 'Salvar',
    );
    if (raw == null) return;
    final clean = raw.replaceAll('#', '').trim();
    if (clean.isEmpty || clean == old) return;
    for (final note in widget.store.notes) {
      final next = <String>[];
      for (final item in note.tags) {
        final value = item.toLowerCase() == old.toLowerCase() ? clean : item;
        if (!next.any((e) => e.toLowerCase() == value.toLowerCase())) {
          next.add(value);
        }
      }
      note.tags = next;
    }
    savedTags
      ..removeWhere((value) => value.toLowerCase() == old.toLowerCase())
      ..add(clean);
    if (tag != null && tag!.toLowerCase() == old.toLowerCase()) tag = clean;
    await _saveCollections();
    await widget.store.save();
    if (mounted) setState(() {});
  }

  Future<void> _deleteTag(String old) async {
    final ok = await _confirm(
      'Apagar a tag #$old?',
      'Ela sai de todas as notas. As notas continuam.',
      'Apagar tag',
    );
    if (!ok) return;
    for (final note in widget.store.notes) {
      note.tags = note.tags
          .where((item) => item.toLowerCase() != old.toLowerCase())
          .toList();
    }
    savedTags.removeWhere((value) => value.toLowerCase() == old.toLowerCase());
    if (tag != null && tag!.toLowerCase() == old.toLowerCase()) tag = null;
    await _saveCollections();
    await widget.store.save();
    if (mounted) setState(() {});
  }

  Future<void> _manageCollection({required bool folders}) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final items = folders ? _allFolders : _allTags;
        int count(String item) => _active
            .where(
              (note) => folders
                  ? _inFolder(note.folder, item)
                  : note.tags.any((t) => t.toLowerCase() == item.toLowerCase()),
            )
            .length;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .75,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folders ? 'Pastas' : 'Tags',
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.pop(sheetContext, 'new'),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(folders ? 'Nova pasta' : 'Nova tag'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    folders ? 'Nenhuma pasta ainda.' : 'Nenhuma tag ainda.',
                    textAlign: TextAlign.center,
                  ),
                ),
              for (final item in items)
                ListTile(
                  leading: Icon(
                    folders ? Icons.folder_outlined : Icons.label_outline_rounded,
                  ),
                  title: Text(folders ? item : '#$item'),
                  subtitle: Text(
                    count(item) == 1 ? '1 nota' : '${count(item)} notas',
                  ),
                  onTap: () => Navigator.pop(sheetContext, 'open:$item'),
                  trailing: folders && item == 'Geral'
                      ? null
                      : PopupMenuButton<String>(
                          tooltip: 'Opções',
                          onSelected: (value) =>
                              Navigator.pop(sheetContext, '$value:$item'),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Renomear'),
                            ),
                            if (folders)
                              const PopupMenuItem(
                                value: 'export',
                                child: Text('Exportar a pasta'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Apagar'),
                            ),
                          ],
                        ),
                ),
            ],
          ),
        );
      },
    );
    if (action == null || !mounted) return;
    if (action == 'new') {
      await (folders ? _createFolder() : _createTag());
      return;
    }
    final split = action.indexOf(':');
    final kind = action.substring(0, split);
    final item = action.substring(split + 1);
    if (kind == 'open') {
      setState(() {
        scope = _NoteScope.all;
        folder = folders ? item : null;
        tag = folders ? null : item;
      });
    } else if (kind == 'rename') {
      await (folders ? _renameFolder(item) : _renameTag(item));
    } else if (kind == 'export') {
      await exportAllNotes(widget.store, onlyFolder: item);
    } else if (kind == 'delete') {
      await (folders ? _deleteFolder(item) : _deleteTag(item));
    }
  }

  Future<void> _showFilters() async {
    var draftScope = scope;
    var draftFolder = folder;
    var draftTag = tag;
    var draftReminder = reminderOnly;
    var draftChecklist = checklistOnly;
    var draftDue = dueOnly;
    var draftOverdue = overdueOnly;
    var draftPriority = priorityFilter;
    var draftFrom = updatedFrom;
    var draftTo = updatedTo;

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .84,
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
                      'Busca avançada',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setModalState(() {
                      draftScope = _NoteScope.all;
                      draftFolder = null;
                      draftTag = null;
                      draftReminder = false;
                      draftChecklist = false;
                      draftDue = false;
                      draftOverdue = false;
                      draftPriority = 0;
                      draftFrom = null;
                      draftTo = null;
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
              if (_allFolders.length > 1) ...[
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
                  onChanged: (value) => setModalState(() => draftTag = value),
                ),
              ],
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: draftPriority,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: const [
                  DropdownMenuItem(
                    value: 0,
                    child: Text('Qualquer prioridade'),
                  ),
                  DropdownMenuItem(value: 1, child: Text('Baixa')),
                  DropdownMenuItem(value: 2, child: Text('Média')),
                  DropdownMenuItem(value: 3, child: Text('Alta')),
                ],
                onChanged: (value) =>
                    setModalState(() => draftPriority = value ?? 0),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Só com lembrete'),
                value: draftReminder,
                onChanged: (value) =>
                    setModalState(() => draftReminder = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Só listas de tarefas'),
                value: draftChecklist,
                onChanged: (value) =>
                    setModalState(() => draftChecklist = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Só com prazo'),
                value: draftDue,
                onChanged: (value) => setModalState(() => draftDue = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Só atrasadas'),
                subtitle: const Text('Prazo já passou'),
                value: draftOverdue,
                onChanged: (value) => setModalState(() => draftOverdue = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('Editadas entre'),
                subtitle: Text(
                  '${draftFrom == null ? 'qualquer data' : DateFormat('dd/MM/yy').format(draftFrom!)}  →  ${draftTo == null ? 'hoje' : DateFormat('dd/MM/yy').format(draftTo!)}',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                    initialDateRange: draftFrom != null && draftTo != null
                        ? DateTimeRange(start: draftFrom!, end: draftTo!)
                        : null,
                  );
                  if (range != null) {
                    setModalState(() {
                      draftFrom = range.start;
                      draftTo = range.end;
                    });
                  }
                },
              ),
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
        reminderOnly = draftReminder;
        checklistOnly = draftChecklist;
        dueOnly = draftDue;
        overdueOnly = draftOverdue;
        priorityFilter = draftPriority;
        updatedFrom = draftFrom;
        updatedTo = draftTo;
      });
    }
  }

  /// Menu único da tela inicial: tudo que não é nota fica aqui.
  Future<void> _openHub({required int archived, required int trash}) async {
    final pending = _active
        .where((n) => !n.locked)
        .fold<int>(0, (sum, n) => sum + countPendingTasks(n.body));
    final reminders = widget.store.notes
        .where(
          (n) =>
              n.deletedAt == null &&
              !n.locked &&
              n.reminderAt != null &&
              (n.reminderRepeat > 0 || n.reminderAt!.isAfter(DateTime.now())),
        )
        .length;
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        Widget tile(String id, IconData icon, String label, [String? badge]) =>
            _HubTile(
              icon: icon,
              label: label,
              badge: badge,
              onTap: () => Navigator.pop(ctx, id),
            );
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            MediaQuery.viewPaddingOf(ctx).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.15,
                children: [
                  tile('today', Icons.today_rounded, 'Hoje'),
                  tile('tasks', Icons.checklist_rounded, 'Tarefas',
                      pending > 0 ? '$pending' : null),
                  tile('reminders', Icons.notifications_active_outlined,
                      'Lembretes', reminders > 0 ? '$reminders' : null),
                  tile('calendar', Icons.calendar_month_outlined, 'Calendário'),
                  tile('folders', Icons.folder_outlined, 'Pastas'),
                  tile('tags', Icons.label_outline_rounded, 'Tags'),
                  tile('archive', Icons.archive_outlined, 'Arquivadas',
                      archived > 0 ? '$archived' : null),
                  tile('trash', Icons.delete_outline_rounded, 'Lixeira',
                      trash > 0 ? '$trash' : null),
                  tile('backup', Icons.cloud_upload_outlined, 'Backup'),
                  tile('settings', Icons.settings_outlined, 'Ajustes'),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'today':
        _openToday();
      case 'tasks':
        _openTasks();
      case 'reminders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UpcomingRemindersPage(
              store: widget.store,
              onOpen: (note) => _openNote(note),
            ),
          ),
        );
      case 'calendar':
        _openCalendar();
      case 'folders':
        _manageCollection(folders: true);
      case 'tags':
        _manageCollection(folders: false);
      case 'archive':
        _openArchive();
      case 'trash':
        _openTrash();
      case 'backup':
        exportBackup(context, widget.store);
      case 'settings':
        _openSettings();
    }
  }

  void _openSettings() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => SettingsPage(store: widget.store)),
  );

  void _openArchive() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => ArchivePage(store: widget.store)),
  );

  void _openTrash() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TrashPage(store: widget.store)),
  );

  void _openCalendar() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          CalendarPage(
            store: widget.store,
            onOpen: (note) => _openNote(note),
            onCreate: (note) => _openNote(note, isNew: true),
          ),
    ),
  );

  void _swipeArchive(Note note) {
    setState(() => note.archived = true);
    widget.store.save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota arquivada'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            setState(() => note.archived = false);
            widget.store.save();
          },
        ),
      ),
    );
  }

  void _swipeDelete(Note note) {
    final previous = note.deletedAt;
    setState(() => note.deletedAt = DateTime.now());
    widget.store.save();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Nota movida para a lixeira'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            setState(() => note.deletedAt = previous);
            widget.store.save();
          },
        ),
      ),
    );
  }

  /// Ação de deslizar: 0 arquivar, 1 lixeira, 2 fixar, 3 favoritar, 4 nada.
  (IconData, String, Color) _swipeLook(int action) {
    final cs = Theme.of(context).colorScheme;
    return switch (action) {
      1 => (Icons.delete_outline_rounded, 'Lixeira', cs.error),
      2 => (Icons.push_pin_outlined, 'Fixar', cs.primary),
      3 => (Icons.star_outline_rounded, 'Favoritar', cs.primary),
      _ => (Icons.archive_outlined, 'Arquivar', cs.primary),
    };
  }

  /// Fixar e favoritar não tiram o card da tela: só alternam e voltam.
  /// Arquivar e lixeira deixam o card sair e agem em onDismissed.
  Future<bool> _runSwipe(Note note, int action) async {
    switch (action) {
      case 0:
      case 1:
        return true;
      case 2:
        widget.store.togglePin(note);
        HapticFeedback.selectionClick();
        return false;
      case 3:
        note.favorite = !note.favorite;
        widget.store.save();
        HapticFeedback.selectionClick();
        return false;
    }
    return false;
  }

  Widget _noteTile(Note note) {
    final right = widget.store.swipeRight;
    final left = widget.store.swipeLeft;
    final rightLook = _swipeLook(right);
    final leftLook = _swipeLook(left);
    final direction = selectedIds.isNotEmpty || (right == 4 && left == 4)
        ? DismissDirection.none
        : right == 4
        ? DismissDirection.endToStart
        : left == 4
        ? DismissDirection.startToEnd
        : DismissDirection.horizontal;
    return Dismissible(
      key: ValueKey('note-${note.id}'),
      direction: direction,
      background: _SwipeBackground(
        alignment: Alignment.centerLeft,
        icon: rightLook.$1,
        label: rightLook.$2,
        color: rightLook.$3,
      ),
      secondaryBackground: _SwipeBackground(
        alignment: Alignment.centerRight,
        icon: leftLook.$1,
        label: leftLook.$2,
        color: leftLook.$3,
      ),
      confirmDismiss: (dir) => _runSwipe(
        note,
        dir == DismissDirection.startToEnd ? right : left,
      ),
      onDismissed: (dir) {
        final action = dir == DismissDirection.startToEnd ? right : left;
        if (action == 0) _swipeArchive(note);
        if (action == 1) _swipeDelete(note);
      },
      child: _NoteCard(
        note: note,
        onTap: () {
          if (selectedIds.isEmpty) {
            _openNote(note);
          } else {
            _select(note);
          }
        },
        onLongPress: () => _select(note),
        selected: selectedIds.contains(note.id),
        radius: widget.store.cardRadius.toDouble(),
        previewLines: widget.store.previewLines,
        showFolder: widget.store.cardShowFolder,
        showDate: widget.store.cardShowDate,
        showTags: widget.store.cardShowTags,
        highlight: foldForSearch(query.trim()),
      ),
    );
  }

  /// Modo lista: notas agrupadas por quando foram editadas.
  Widget _groupedList(List<Note> notes) {
    final grouping = sortOrder == 0 && query.trim().isEmpty;
    final today = DateUtils.dateOnly(DateTime.now());
    String group(Note note) {
      if (note.pinned) return 'Fixadas';
      final day = DateUtils.dateOnly(note.updatedAt);
      if (day == today) return 'Hoje';
      if (day == today.subtract(const Duration(days: 1))) return 'Ontem';
      if (today.difference(day).inDays < 7) return 'Nos últimos 7 dias';
      if (today.difference(day).inDays < 31) return 'Neste mês';
      return 'Mais antigas';
    }

    final rows = <Object>[];
    String? last;
    for (final note in notes) {
      if (grouping) {
        final name = group(note);
        if (name != last) rows.add(name);
        last = name;
      }
      rows.add(note);
    }
    final height = widget.store.compactCards ? 136.0 : 184.0;
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: EdgeInsets.fromLTRB(4, index == 0 ? 2 : 14, 0, 8),
            child: Text(
              row.toUpperCase(),
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .6),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(height: height, child: _noteTile(row as Note)),
        );
      },
    );
  }

  bool _hasQuickFilters(List<Note> active) => active.any(
    (n) => n.favorite || n.reminderAt != null || _isOverdue(n),
  );

  Widget _quickChip(String label, bool selected, VoidCallback toggle) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => setState(toggle),
    ),
  );

  Widget _recentSearches() => SizedBox(
    height: 42,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      children: [
        for (final item in widget.store.recentSearches)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16),
              label: Text(item),
              onPressed: () {
                _searchController.text = item;
                setState(() => query = item);
              },
            ),
          ),
      ],
    ),
  );

  Widget _folderChips() {
    final folders = _allFolders;
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Todas'),
              selected: folder == null &&
                  scope == _NoteScope.all &&
                  !reminderOnly &&
                  !overdueOnly,
              onSelected: (_) => setState(() {
                folder = null;
                scope = _NoteScope.all;
                reminderOnly = false;
                overdueOnly = false;
              }),
            ),
          ),
          if (_active.any((n) => n.favorite))
            _quickChip(
              '★ Favoritas',
              scope == _NoteScope.favorites,
              () => scope = scope == _NoteScope.favorites
                  ? _NoteScope.all
                  : _NoteScope.favorites,
            ),
          if (_active.any((n) => n.reminderAt != null))
            _quickChip(
              'Com lembrete',
              reminderOnly,
              () => reminderOnly = !reminderOnly,
            ),
          if (_active.any(_isOverdue))
            _quickChip('Atrasadas', overdueOnly, () => overdueOnly = !overdueOnly),
          if (folders.length > 1)
          for (final item in [
            ...folders.where(widget.store.pinnedFolders.contains),
            ...folders.where((f) => !widget.store.pinnedFolders.contains(f)),
          ])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              // Segurar a pasta fixa ela no começo dos atalhos.
              child: GestureDetector(
                onLongPress: () {
                  HapticFeedback.selectionClick();
                  final pinned = widget.store.pinnedFolders;
                  final was = pinned.remove(item);
                  if (!was) pinned.insert(0, item);
                  widget.store.save();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        was ? 'Pasta $item solta' : 'Pasta $item fixada no começo',
                      ),
                    ),
                  );
                },
                child: ChoiceChip(
                  avatar: widget.store.pinnedFolders.contains(item)
                      ? const Icon(Icons.push_pin, size: 14)
                      : null,
                  label: Text('$item  ${_active.where((n) => _inFolder(n.folder, item)).length}'),
                  selected: folder == item,
                  onSelected: (_) => setState(
                    () => folder = folder == item ? null : item,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (_, __) {
      final active = _active;
      final notes = _visible;
      final snapshot = buildTodaySnapshot(active);
      final archived = widget.store.notes
          .where((note) => note.archived && note.deletedAt == null)
          .length;
      final trash = widget.store.notes
          .where((note) => note.deletedAt != null)
          .length;

      // Voltar fecha a busca ou a seleção antes de sair do app.
      return PopScope(
        canPop: !searching && selectedIds.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() {
            if (selectedIds.isNotEmpty) {
              selectedIds.clear();
            } else {
              searching = false;
              query = '';
              _searchController.clear();
            }
          });
        },
        child: Scaffold(
        backgroundColor: _hasWallpaper ? Colors.transparent : null,
        appBar: AppBar(
          titleSpacing: 20,
          title: Row(
            children: [
              RawGestureDetector(
                gestures: {
                  LongPressGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        LongPressGestureRecognizer
                      >(
                        () => LongPressGestureRecognizer(
                          duration: const Duration(seconds: 2),
                        ),
                        (instance) => instance.onLongPress = () {
                          HapticFeedback.mediumImpact();
                          openVault(context, widget.store);
                        },
                      ),
                },
                child: const NotoMark(size: 34),
              ),
              const SizedBox(width: 8),
              Flexible(
                // Tocar no nome volta ao começo da lista.
                child: GestureDetector(
                  onTap: _scrollToTop,
                  child: Text(
                    widget.store.homeTitle.trim().isEmpty
                        ? 'Noto'
                        : widget.store.homeTitle.trim(),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: searching ? 'Fechar busca' : 'Buscar',
              onPressed: () => setState(() {
                searching = !searching;
                if (!searching) {
                  query = '';
                  _searchController.clear();
                }
              }),
              icon: Badge(
                isLabelVisible: _hasFilters && !searching,
                smallSize: 7,
                child: Icon(
                  searching ? Icons.close_rounded : Icons.search_rounded,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Calendário',
              onPressed: _openCalendar,
              icon: const Icon(Icons.calendar_month_outlined),
            ),
            IconButton(
              tooltip: 'Menu',
              onPressed: () => _openHub(archived: archived, trash: trash),
              icon: const Icon(Icons.apps_rounded),
            ),
            const SizedBox(width: 6),
          ],
          bottom: !widget.store.showShortcutsBar
              ? null
              : PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: _TopLibraryActions(
              archived: archived,
              trash: trash,
              onArchive: _openArchive,
              onTrash: _openTrash,
              onCreateFolder: () => _manageCollection(folders: true),
              onCreateTag: () => _manageCollection(folders: false),
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (searching)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Buscar no Noto (dica: #tag)',
                      prefixIcon: IconButton(
                        tooltip: 'Busca avançada',
                        onPressed: _showFilters,
                        icon: Badge(
                          isLabelVisible: _hasFilters,
                          smallSize: 7,
                          child: const Icon(Icons.tune_rounded),
                        ),
                      ),
                      suffixIcon: query.isEmpty
                          ? IconButton(
                              tooltip: 'Buscar falando',
                              icon: const Icon(Icons.mic_none_rounded),
                              onPressed: () async {
                                final spoken = await showDictation(context);
                                if (spoken == null || !mounted) return;
                                _searchController.text = spoken;
                                setState(() => query = spoken);
                              },
                            )
                          : IconButton(
                              tooltip: 'Limpar busca',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => query = '');
                              },
                            ),
                    ),
                    onChanged: (value) => setState(() => query = value),
                    onSubmitted: widget.store.rememberSearch,
                  ),
                ),
              if (searching &&
                  query.isEmpty &&
                  widget.store.recentSearches.isNotEmpty)
                _recentSearches(),
              if (widget.store.homeShowToday)
                _TodayLine(snapshot: snapshot, onTasks: _openTasks),
              if (widget.store.showFolderChips &&
                  (_allFolders.length > 1 || _hasQuickFilters(active)))
                _folderChips(),
              if (widget.store.shouldNudgeBackup)
                _TipCard(
                  text:
                      'Faz um tempo que você não faz backup. Guarde uma cópia '
                      'das notas caso troque ou perca o celular.',
                  actionLabel: 'Fazer',
                  onAction: () => exportBackup(context, widget.store),
                  onClose: () {
                    widget.store.backupNudgeDismissedAt = DateTime.now();
                    widget.store.save();
                  },
                )
              else if (active.length >= 3 &&
                  !widget.store.seenTips.contains('home-gestures'))
                _TipCard(
                  text:
                      'Dica: segure uma nota para selecionar várias. Deslize '
                      'para a direita para arquivar e para a esquerda para '
                      'mandar para a lixeira.',
                  onClose: () => setState(
                    () => widget.store.takeTip('home-gestures'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _hasFilters || query.trim().isNotEmpty
                            ? '${notes.length} ${notes.length == 1 ? 'encontrada' : 'encontradas'}'
                            : '${notes.length} ${notes.length == 1 ? 'nota' : 'notas'}',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    PopupMenuButton<int>(
                      tooltip: 'Ordenar notas',
                      initialValue: sortOrder,
                      icon: const Icon(Icons.sort),
                      onSelected: (value) async {
                        setState(() => sortOrder = value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setInt('notoSortOrder', value);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 0, child: Text('Editadas por último')),
                        PopupMenuItem(value: 1, child: Text('Editadas há mais tempo')),
                        PopupMenuItem(value: 4, child: Text('Criadas por último')),
                        PopupMenuItem(value: 5, child: Text('Criadas há mais tempo')),
                        PopupMenuItem(value: 6, child: Text('Prazo mais próximo')),
                        PopupMenuItem(value: 2, child: Text('Título A–Z')),
                        PopupMenuItem(value: 3, child: Text('Título Z–A')),
                      ],
                    ),
                    if (folder != null)
                      Flexible(
                        child: Text(
                          folder!,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    if (tag != null)
                      Text(
                        '#$tag',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if (_hasFilters)
                      TextButton(
                        onPressed: _clearFilters,
                        child: const Text('Limpar'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: notes.isEmpty
                    ? _EmptyNotes(
                        filtered: _hasFilters || query.trim().isNotEmpty,
                        query: query.trim(),
                        onCreate: _createNote,
                        onClear: () {
                          _searchController.clear();
                          setState(() => query = '');
                          _clearFilters();
                        },
                      )
                    : widget.store.layoutMode == 1
                    ? _groupedList(notes)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              widget.store.gridColumns +
                              (constraints.maxWidth >= 760 ? 1 : 0);
                          return GridView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent:
                                      widget.store.compactCards ? 168 : 224,
                                ),
                            itemCount: notes.length,
                            itemBuilder: (_, index) => _noteTile(notes[index]),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: selectedIds.isEmpty ? null : _selectionBar(),
        floatingActionButton: selectedIds.isNotEmpty
            ? null
            : GestureDetector(
                // Segurar o + cria direto o outro tipo de nota.
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  _createNote(
                    direct: widget.store.plusAction == 2 ? 'blank' : 'checklist',
                  );
                },
                child: FloatingActionButton(
                  onPressed: _createNote,
                  tooltip: widget.store.plusAction == 2
                      ? 'Nova lista (segure para nota em branco)'
                      : 'Nova nota (segure para lista de tarefas)',
                  child: const Icon(Icons.add_rounded),
                ),
              ),
      ),
      );
    },
  );
}

class _HubTile extends StatelessWidget {
  const _HubTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 28, color: cs.primary),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopLibraryActions extends StatelessWidget {
  const _TopLibraryActions({
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
    child: Row(
      children: [
        Expanded(
          child: _TopAction(
            icon: Icons.archive_outlined,
            label: 'Arquivadas',
            count: archived,
            onTap: onArchive,
          ),
        ),
        Expanded(
          child: _TopAction(
            icon: Icons.delete_outline_rounded,
            label: 'Lixeira',
            count: trash,
            onTap: onTrash,
          ),
        ),
        Expanded(
          child: _TopAction(
            icon: Icons.folder_outlined,
            label: 'Pastas',
            onTap: onCreateFolder,
          ),
        ),
        Expanded(
          child: _TopAction(
            icon: Icons.label_outline_rounded,
            label: 'Tags',
            onTap: onCreateTag,
          ),
        ),
      ],
    ),
  );
}

class _TopAction extends StatelessWidget {
  const _TopAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: cs.onSurface.withValues(alpha: .72)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '$label${count == null ? '' : ' $count'}',
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: .78),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.snapshot, required this.onTasks});

  final TodaySnapshot snapshot;
  final VoidCallback onTasks;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if (snapshot.pendingTasks > 0)
        (
          Icons.check_box_outline_blank_rounded,
          snapshot.pendingTasks == 1
              ? '1 tarefa a fazer'
              : '${snapshot.pendingTasks} tarefas a fazer',
        ),
      if (snapshot.remindersToday > 0)
        (
          Icons.notifications_none_rounded,
          snapshot.remindersToday == 1
              ? '1 lembrete hoje'
              : '${snapshot.remindersToday} lembretes hoje',
        ),
      if (snapshot.touched > 0)
        (
          Icons.edit_outlined,
          snapshot.touched == 1
              ? '1 editada hoje'
              : '${snapshot.touched} editadas hoje',
        ),
    ];
    // Sem nada para mostrar, o resumo some em vez de ocupar espaço.
    if (items.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
        children: [
          for (final item in items)
            GestureDetector(
              // Tocar nas tarefas abre a lista com todas elas.
              onTap: item.$1 == Icons.check_box_outline_blank_rounded
                  ? onTasks
                  : null,
              child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: .82),
                    ),
                  ),
                  if (item.$1 == Icons.check_box_outline_blank_rounded) ...[
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: cs.onSurface.withValues(alpha: .5),
                    ),
                  ],
                ],
              ),
            ),
            ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.text,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });
  final String text;
  final VoidCallback onClose;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: cs.onPrimaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: cs.onPrimaryContainer, height: 1.35),
            ),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
          TextButton(
            onPressed: onClose,
            child: Text(actionLabel == null ? 'Entendi' : 'Agora não'),
          ),
        ],
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.color,
  });
  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    alignment: alignment,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .22),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
      ],
    ),
  );
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.note,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.radius = 16,
    this.previewLines = 4,
    this.showFolder = true,
    this.showDate = true,
    this.showTags = true,
    this.highlight = '',
  });
  final VoidCallback? onLongPress;
  final bool selected;
  final double radius;
  final int previewLines;
  final bool showFolder;
  final bool showDate;
  final bool showTags;

  /// Termo da busca: o card mostra o trecho onde ele aparece.
  final String highlight;

  /// Trecho do texto em volta do termo buscado, com o termo em destaque.
  TextSpan? _snippet(String text, TextStyle base, Color strong) {
    if (highlight.isEmpty) return null;
    final folded = foldForSearch(text);
    final at = folded.indexOf(highlight);
    if (at < 0 || folded.length != text.length) return null;
    final start = (at - 30).clamp(0, text.length).toInt();
    final end = (at + highlight.length + 80).clamp(0, text.length).toInt();
    return TextSpan(
      style: base,
      children: [
        TextSpan(text: '${start > 0 ? '…' : ''}${text.substring(start, at)}'),
        TextSpan(
          text: text.substring(at, at + highlight.length),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: strong,
            backgroundColor: strong.withValues(alpha: .16),
          ),
        ),
        TextSpan(text: text.substring(at + highlight.length, end)),
      ],
    );
  }

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final wallpaper = noteWallpaper(note);
    final hasWallpaper = wallpaper != null;
    final noteColor = NotoAppearance
        .noteColors[NotoAppearance.safeNoteColorIndex(note.color)];
    final background = note.color == 0 ? cs.surfaceContainerLow : noteColor;
    final titleFont = NotoAppearance.familyAt(note.titleFont ?? note.font);
    final bodyFont = NotoAppearance.familyAt(note.bodyFont ?? note.font);
    final customTextColor = note.textColor == 0
        ? null
        : NotoAppearance.textColors[NotoAppearance.safeTextColorIndex(
            note.textColor,
          )];
    final contentColor =
        customTextColor ?? (hasWallpaper ? Colors.white : cs.onSurface);
    final contentSecondary = contentColor.withValues(alpha: .72);
    final metadataColor = hasWallpaper
        ? Colors.white70
        : cs.onSurface.withValues(alpha: .58);
    // Sem título, a primeira linha vira o título; a prévia mostra o resto.
    var bodyLines = readablePreview(note.body)
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (note.title.trim().isEmpty && bodyLines.isNotEmpty) {
      bodyLines = bodyLines.skip(1).toList();
    }
    final preview = bodyLines.join('  ');
    final pending = countPendingTasks(note.body);
    final done = countDoneTasks(note.body);
    final total = pending + done;
    final accentText =
        customTextColor ?? (hasWallpaper ? Colors.white : cs.primary);
    final reminder = note.reminderAt;
    final showReminder =
        reminder != null &&
        (note.reminderRepeat > 0 || reminder.isAfter(DateTime.now()));
    final overdue =
        note.dueAt != null &&
        DateUtils.dateOnly(
          note.dueAt!,
        ).isBefore(DateUtils.dateOnly(DateTime.now()));
    final snippet = _snippet(
      readablePreview(note.body).replaceAll('\n', '  '),
      TextStyle(
        color: contentSecondary,
        fontFamily: bodyFont,
        fontSize: 13,
        height: 1.35,
      ),
      accentText,
    );
    final cover = note.coverImage == null ? null : File(note.coverImage!);
    final hasCover = cover != null && FileCache.exists(note.coverImage);

    final card = Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              width: selected ? 2.5 : 1,
              color: selected
                  ? cs.primary
                  : hasWallpaper
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
            onLongPress: onLongPress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasCover)
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: Image.file(cover, fit: BoxFit.cover),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (note.emoji.isNotEmpty) ...[
                              Text(
                                note.emoji,
                                style: const TextStyle(fontSize: 17),
                              ),
                              const SizedBox(width: 5),
                            ],
                            Expanded(
                              child: Text(
                                displayTitle(note),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: contentColor,
                                  fontFamily: titleFont,
                                  fontSize: 16.5,
                                  height: 1.15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (note.pinned)
                              Icon(
                                Icons.push_pin_outlined,
                                size: 14,
                                color: contentSecondary,
                              ),
                            if (note.favorite) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.star_rounded,
                                size: 14,
                                color:
                                    customTextColor ??
                                    (hasWallpaper ? Colors.white : cs.primary),
                              ),
                            ],
                          ],
                        ),
                        if (snippet != null) ...[
                          const SizedBox(height: 7),
                          Text.rich(
                            snippet,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else if (preview.isNotEmpty && previewLines > 0) ...[
                          const SizedBox(height: 7),
                          Text(
                            preview,
                            maxLines: hasCover
                                ? (previewLines < 2 ? previewLines : 2)
                                : previewLines,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: contentSecondary,
                              fontFamily: bodyFont,
                              fontSize: 13,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Wrap(
                          spacing: 5,
                          runSpacing: 2,
                          children: [
                            if (total > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: done / total,
                                        minHeight: 4,
                                        color: accentText,
                                        backgroundColor: accentText.withValues(
                                          alpha: .22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    '$done/$total',
                                    style: TextStyle(
                                      color: accentText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            if (showReminder)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    note.reminderRepeat > 0
                                        ? Icons.repeat_rounded
                                        : Icons.notifications_none_rounded,
                                    size: 12,
                                    color: metadataColor,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    note.reminderRepeat > 0
                                        ? DateFormat('HH:mm').format(reminder)
                                        : DateFormat('dd/MM HH:mm')
                                              .format(reminder),
                                    style: TextStyle(
                                      color: metadataColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            if (note.priority > 0)
                              Text(
                                priorityLabel(note.priority),
                                style: TextStyle(
                                  color: note.priority == 3
                                      ? cs.error
                                      : metadataColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (note.dueAt != null)
                              Text(
                                dueCountdown(note.dueAt!, DateTime.now()),
                                style: TextStyle(
                                  color: overdue ? cs.error : metadataColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (showFolder) note.folder,
                            if (showTags && note.tags.isNotEmpty)
                              note.tags.take(2).map((t) => '#$t').join(' '),
                            if (showDate)
                              DateFormat('dd/MM').format(note.updatedAt),
                          ].join('  ·  '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: metadataColor,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
    );
    // Selecionado: borda na cor de destaque, card um pouco menor e um
    // selo de marcado no canto, sem empurrar o conteúdo.
    return AnimatedScale(
      scale: selected ? .96 : 1,
      duration: const Duration(milliseconds: 140),
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          card,
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(radius),
                  ),
                ),
              ),
            ),
          if (selected)
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 2),
                  ),
                  child: Icon(Icons.check_rounded, size: 16, color: cs.onPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes({
    required this.filtered,
    required this.query,
    required this.onCreate,
    required this.onClear,
  });
  final bool filtered;
  final String query;
  final VoidCallback onCreate;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filtered ? Icons.search_off_rounded : Icons.edit_note_rounded,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            filtered
                ? query.isEmpty
                      ? 'Nenhuma nota com esses filtros.'
                      : 'Nada encontrado para "$query".'
                : 'Nenhuma nota ainda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (filtered)
            OutlinedButton(
              onPressed: onClear,
              child: const Text('Limpar busca e filtros'),
            )
          else
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Criar primeira nota'),
            ),
        ],
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
            color: Theme.of(context).colorScheme.onSurface
                .withValues(alpha: .36),
          ),
        ],
      ),
    ),
  );
}
