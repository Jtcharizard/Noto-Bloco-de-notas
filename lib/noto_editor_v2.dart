import 'noto_code_block.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_rich_editor.dart';
import 'noto_settings.dart' as settings;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_editor.dart' as legacy;
import 'noto_features.dart';
import 'noto_formatting.dart';
import 'noto_models.dart';
import 'noto_power_tools.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

class EditorPageV2 extends StatefulWidget {
  const EditorPageV2({
    super.key,
    required this.store,
    required this.note,
    required this.isNew,
  });

  final AppStore store;
  final Note note;
  final bool isNew;

  @override
  State<EditorPageV2> createState() => _EditorPageV2State();
}

class _EditorPageV2State extends State<EditorPageV2>
    with WidgetsBindingObserver {
  late final TextEditingController title = TextEditingController(
    text: widget.note.title,
  );
  late final NotoRichController body = NotoRichController(
    text: widget.note.body,
    styles: widget.note.editor['styles'] as List? ?? [],
  );

  final bodyFocus = FocusNode();

  late final ScrollController editorScroll = ScrollController(
    initialScrollOffset:
        (widget.note.editor['scroll'] as num?)?.toDouble() ?? 0,
  );
  final List<NotoTable> tables = [];
  final List<Map<String, dynamic>> codeBlocks = [];
  final List<String> undoStack = [];
  final List<String> redoStack = [];
  Set<String> pinnedTools = {'table', 'bold', 'color', 'search'};
  TextAlign alignment = TextAlign.left;
  Timer? autosaveTimer;
  SharedPreferences? editorPrefs;
  String saveLabel = 'Salvo';
  String lastSnapshot = '';
  bool restoringEditor = false;
  bool dirty = false;
  int tableEpoch = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final metadata = widget.note.editor;
    codeBlocks.addAll(
      ((metadata['code'] as List?) ?? []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    if (!widget.note.checklist && codeBlocks.isEmpty) {
      body.text = body.text.replaceAllMapped(
        RegExp(r'^```([^\n]*)\n([\s\S]*?)\n```[ \t]*(?:\n|$)', multiLine: true),
        (m) {
          final language = m[1]!.trim();
          codeBlocks.add({
            'id':
                'code-${DateTime.now().microsecondsSinceEpoch}-${codeBlocks.length}',
            'language':
                [
                  'dart',
                  'python',
                  'javascript',
                  'typescript',
                  'html',
                  'css',
                  'json',
                  'sql',
                  'java',
                  'c',
                  'cpp',
                  'bash',
                ].contains(language)
                ? language
                : 'texto',
            'text': m[2],
            'wrap': false,
          });
          return '';
        },
      );
    }
    tables.addAll(
      ((metadata['tables'] as List?) ?? []).map(
        (e) => NotoTable.fromJson(Map<String, dynamic>.from(e as Map)),
      ),
    );
    alignment =
        TextAlign.values[((metadata['align'] as int?) ?? 0).clamp(
          0,
          TextAlign.values.length - 1,
        )];
    final taskLines = body.text
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (taskLines.isNotEmpty &&
        taskLines.every((s) => RegExp(r'^\s*(?:- )?\[[ xX]\]').hasMatch(s)))
      widget.note.checklist = true;
    if (tables.isEmpty && !widget.note.checklist) {
      final migration = migrateTables(body.text);
      if (migration.tables.isNotEmpty) {
        body.text = migration.text;
        tables.addAll(migration.tables);
      }
    }
    body.selection = TextSelection.collapsed(
      offset: ((metadata['cursor'] as int?) ?? 0).clamp(0, body.text.length),
    );
    lastSnapshot = _snapshot();
    title.addListener(_editorChanged);
    body.addListener(_editorChanged);
    _loadEditorPreferences();
  }

  Map<String, dynamic> _editorData() => {
    'checklist': widget.note.checklist,
    'code': codeBlocks,
    'styles': body.marks,
    'tables': tables.map((t) => t.toJson()).toList(),
    'align': alignment.index,
    'cursor': body.selection.isValid ? body.selection.extentOffset : 0,
    'scroll': editorScroll.hasClients ? editorScroll.offset : 0,
  };
  String _snapshot() => jsonEncode({
    'title': title.text,
    'body': body.text,
    'checklist': widget.note.checklist,
    'code': codeBlocks,
    'styles': body.marks,
    'tables': tables.map((t) => t.toJson()).toList(),
    'align': alignment.index,
  });

  Future<void> _loadEditorPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    editorPrefs = prefs;
    pinnedTools = (prefs.getStringList('editor.pins') ?? pinnedTools.toList())
        .toSet();
    focusMode = prefs.getBool('editor.focus') ?? false;
    final raw = prefs.getString('editor.draft.${widget.note.id}');
    if (!dirty && raw != null) {
      try {
        final draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final time = DateTime.tryParse(draft['at'] as String? ?? '');
        if (time != null && time.isAfter(widget.note.updatedAt)) {
          _restoreSnapshot(draft['snapshot'] as String);
          saveLabel = 'Rascunho recuperado';
          dirty = true;
          autosaveTimer = Timer(const Duration(milliseconds: 700), _autosave);
        }
      } catch (_) {
        /* Keep the persisted note if a draft is malformed. */
      }
    }
    setState(() {});
  }

  void _editorChanged() {
    if (restoringEditor || !mounted) return;
    final next = _snapshot();
    if (next != lastSnapshot) {
      undoStack.add(lastSnapshot);
      if (undoStack.length > 100) undoStack.removeAt(0);
      redoStack.clear();
      lastSnapshot = next;
      dirty = true;
      saveLabel = 'Salvando…';
      autosaveTimer?.cancel();
      _writeDraft();
      autosaveTimer = Timer(const Duration(milliseconds: 700), _autosave);
    }
    setState(() {});
  }

  Future<void> _writeDraft() async {
    final prefs = editorPrefs ?? await SharedPreferences.getInstance();
    if (saved) return;
    await prefs.setString(
      'editor.draft.${widget.note.id}',
      jsonEncode({
        'at': DateTime.now().toIso8601String(),
        'snapshot': _snapshot(),
      }),
    );
  }

  Future<void> _autosave() async {
    if (saved || !dirty) return;
    final snapshot = _snapshot();
    try {
      await _saveDraft();
      if (!mounted) return;
      if (snapshot == _snapshot()) {
        dirty = false;
        await editorPrefs?.remove('editor.draft.${widget.note.id}');
        if (mounted) setState(() => saveLabel = 'Salvo');
      }
    } catch (_) {
      if (mounted) setState(() => saveLabel = 'Falha ao salvar · tentar');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _writeDraft();
      _autosave();
    }
  }

  void _restoreSnapshot(String raw) {
    final data = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    restoringEditor = true;
    widget.note.checklist = data['checklist'] as bool? ?? widget.note.checklist;
    title.text = data['title'] as String;
    body.restore(
      data['body'] as String,
      data['styles'] as List? ?? [],
      body.selection.isValid ? body.selection.extentOffset : 0,
    );
    codeBlocks
      ..clear()
      ..addAll(
        ((data['code'] as List?) ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
    tables
      ..clear()
      ..addAll(
        (data['tables'] as List).map(
          (e) => NotoTable.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    alignment = TextAlign.values[data['align'] as int];
    tableEpoch++;
    restoringEditor = false;
    lastSnapshot = _snapshot();
  }

  void _historyEdit(bool redo) {
    final source = redo ? redoStack : undoStack;
    if (source.isEmpty) return;
    (redo ? undoStack : redoStack).add(_snapshot());
    _restoreSnapshot(source.removeLast());
    dirty = true;
    saveLabel = 'Salvando…';
    _writeDraft();
    autosaveTimer?.cancel();
    autosaveTimer = Timer(const Duration(milliseconds: 700), _autosave);
    setState(() {});
  }

  String get fullText => [
    body.text,
    ...tables.map((t) => t.plainText),
    ...codeBlocks.map((c) => c['text'] as String),
  ].where((s) => s.isNotEmpty).join('\n\n');
  String get fullMarkdown => [
    body.text,
    ...tables.map((t) => t.markdown),
    ...codeBlocks.map((c) => '```${c['language']}\n${c['text']}\n```'),
  ].where((s) => s.isNotEmpty).join('\n\n');
  int get selectedWords {
    final s = body.selection;
    if (!s.isValid || s.isCollapsed) return 0;
    final text = s.textInside(body.text).trim();
    return text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
  }

  Future<void> _copyAll() async {
    await Clipboard.setData(ClipboardData(text: '${title.text}\n\n$fullText'));
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nota copiada')));
  }

  Future<void> _findReplace() async {
    final find = TextEditingController(), replace = TextEditingController();
    var result = '';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) {
          void search(bool replaceOne, bool all) {
            final needle = find.text;
            if (needle.isEmpty) {
              update(() => result = 'Digite o que procurar');
              return;
            }
            if (all) {
              var count = 0;
              restoringEditor = true;
              var offset = 0;
              while (true) {
                final at = body.text.indexOf(needle, offset);
                if (at < 0) break;
                body.value = TextEditingValue(
                  text: body.text.replaceRange(
                    at,
                    at + needle.length,
                    replace.text,
                  ),
                  selection: TextSelection.collapsed(
                    offset: at + replace.text.length,
                  ),
                );
                offset = at + replace.text.length;
                count++;
              }
              for (final table in tables) {
                for (final row in table.cells) {
                  for (var c = 0; c < row.length; c++) {
                    count += needle.allMatches(row[c]).length;
                    row[c] = row[c].replaceAll(needle, replace.text);
                  }
                }
                table.revision++;
              }
              restoringEditor = false;
              _editorChanged();
              update(() => result = '$count ocorrência(s) substituída(s)');
              return;
            }
            final selection = body.selection;
            if (replaceOne &&
                selection.isValid &&
                selection.textInside(body.text) == needle) {
              body.value = TextEditingValue(
                text: body.text.replaceRange(
                  selection.start,
                  selection.end,
                  replace.text,
                ),
                selection: TextSelection.collapsed(
                  offset: selection.start + replace.text.length,
                ),
              );
            }
            final from = body.selection.isValid ? body.selection.end : 0;
            var at = body.text.indexOf(needle, from);
            if (at < 0) at = body.text.indexOf(needle);
            if (at >= 0)
              body.selection = TextSelection(
                baseOffset: at,
                extentOffset: at + needle.length,
              );
            final inTables = tables.fold<int>(
              0,
              (n, t) => n + needle.allMatches(t.plainText).length,
            );
            update(
              () => result = at >= 0
                  ? 'Trecho selecionado no texto'
                  : inTables > 0
                  ? '$inTables ocorrência(s) nas tabelas. Use substituir tudo.'
                  : 'Nenhum resultado',
            );
          }

          return AlertDialog(
            title: const Text('Buscar e substituir'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: find,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Buscar (diferencia maiúsculas)',
                    ),
                  ),
                  TextField(
                    controller: replace,
                    decoration: const InputDecoration(
                      labelText: 'Substituir por',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(result),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => search(false, false),
                        child: const Text('Próximo'),
                      ),
                      TextButton(
                        onPressed: () => search(true, false),
                        child: const Text('Substituir'),
                      ),
                      TextButton(
                        onPressed: () => search(false, true),
                        child: const Text('Substituir tudo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fechar'),
              ),
            ],
          );
        },
      ),
    );
    // Dialog transition must finish before its text fields release controllers.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    find.dispose();
    replace.dispose();
  }

  Future<void> _pickTextColor(bool highlight) async {
    final color = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(highlight ? 'Marca-texto' : 'Cor do trecho'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c
                in highlight
                    ? [
                        0xFFFFEB3B,
                        0xFFB9F6CA,
                        0xFFFFB3DE,
                        0xFFD1B3FF,
                        0xFF80DEEA,
                        0x00000000,
                      ]
                    : [
                        0xFF7C3AED,
                        0xFFD0187D,
                        0xFF2457F5,
                        0xFF007D63,
                        0xFFD34716,
                        0xFF161020,
                        0xFFFFFFFF,
                      ])
              Semantics(
                label: 'Cor ${c.toRadixString(16)}',
                button: true,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, c),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Color(c),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: c == 0 ? const Icon(Icons.format_color_reset) : null,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
    if (color != null && mounted) {
      body.apply(highlight ? 'highlight' : 'color', color);
      bodyFocus.requestFocus();
    }
  }

  Future<void> _pickInlineFont() async {
    final index = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => settings.FontPickerSheet(
        selected: widget.note.bodyFont ?? widget.note.font,
      ),
    );
    if (index == null || !mounted) return;
    if (body.selection.isValid && !body.selection.isCollapsed) {
      body.apply('font', NotoAppearance.familyAt(index));
    } else {
      widget.note.bodyFont = index;
      _editorChanged();
      dirty = true;
      await _autosave();
    }
    bodyFocus.requestFocus();
  }

  static const toolLabels = {
    'table': 'Tabela',
    'bold': 'Negrito',
    'italic': 'Itálico',
    'font': 'Fonte',
    'color': 'Cor',
    'highlight': 'Marca-texto',
    'align': 'Alinhamento',
    'search': 'Buscar e substituir',
    'copy': 'Copiar nota',
    'heading': 'Título',
    'list': 'Lista',
    'checklist': 'Checklist',
    'quote': 'Citação',
    'code': 'Código',
    'divider': 'Separador',
  };
  static const toolIcons = {
    'table': Icons.table_chart_outlined,
    'bold': Icons.format_bold,
    'italic': Icons.format_italic,
    'font': Icons.font_download_outlined,
    'color': Icons.format_color_text,
    'highlight': Icons.highlight,
    'align': Icons.format_align_left,
    'search': Icons.find_replace,
    'copy': Icons.copy_all,
    'heading': Icons.title,
    'list': Icons.format_list_bulleted,
    'checklist': Icons.checklist,
    'quote': Icons.format_quote,
    'code': Icons.code,
    'divider': Icons.horizontal_rule,
  };

  void _tool(String key) {
    switch (key) {
      case 'table':
        _insertTable();
        break;
      case 'color':
        _pickTextColor(false);
        break;
      case 'highlight':
        _pickTextColor(true);
        break;
      case 'search':
        _findReplace();
        break;
      case 'copy':
        _copyAll();
        break;
      case 'font':
        _pickInlineFont();
        break;
      case 'align':
        setState(
          () => alignment =
              [
                TextAlign.left,
                TextAlign.center,
                TextAlign.right,
                TextAlign.justify,
              ][([
                        TextAlign.left,
                        TextAlign.center,
                        TextAlign.right,
                        TextAlign.justify,
                      ].indexOf(alignment) +
                      1) %
                  4],
        );
        _editorChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Alinhamento: ${['esquerda', 'direita', 'centro', 'justificado', 'início', 'fim'][alignment.index]}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
        break;
      default:
        _format(key);
    }
  }

  Future<void> _customizeTools() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .7,
            child: ListView(
              children: [
                const ListTile(
                  title: Text('Seus atalhos'),
                  subtitle: Text(
                    'Marque os comandos que ficam no início da barra.',
                  ),
                ),
                for (final entry in toolLabels.entries)
                  CheckboxListTile(
                    title: Text(entry.value),
                    value: pinnedTools.contains(entry.key),
                    onChanged: (v) {
                      update(() {
                        if (v == true) {
                          pinnedTools.add(entry.key);
                        } else {
                          pinnedTools.remove(entry.key);
                        }
                      });
                      editorPrefs?.setStringList(
                        'editor.pins',
                        pinnedTools.toList(),
                      );
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _richToolbar() => Material(
    color: Theme.of(context).colorScheme.primaryContainer,
    borderRadius: BorderRadius.circular(12),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Desfazer',
            onPressed: undoStack.isEmpty ? null : () => _historyEdit(false),
            icon: const Icon(Icons.undo),
          ),
          IconButton(
            tooltip: 'Refazer',
            onPressed: redoStack.isEmpty ? null : () => _historyEdit(true),
            icon: const Icon(Icons.redo),
          ),
          for (final key in [
            ...pinnedTools.where(toolLabels.containsKey),
            ...toolLabels.keys.where((k) => !pinnedTools.contains(k)),
          ])
            IconButton(
              tooltip: toolLabels[key],
              onPressed: () => _tool(key),
              icon: Icon(toolIcons[key]),
            ),
          IconButton(
            tooltip: 'Personalizar barra',
            onPressed: _customizeTools,
            icon: const Icon(Icons.push_pin_outlined),
          ),
        ],
      ),
    ),
  );

  bool saved = false;
  bool focusMode = false;

  bool get hasContent =>
      title.text.trim().isNotEmpty ||
      body.text.trim().isNotEmpty ||
      tables.isNotEmpty ||
      codeBlocks.isNotEmpty;

  int get words => body.text.trim().isEmpty
      ? 0
      : body.text.trim().split(RegExp(r'\s+')).length;
  int get characters => body.text.characters.length;
  int get readingMinutes => words == 0 ? 0 : ((words + 199) ~/ 200);

  Color? get editorTextColor {
    final wallpaper = noteWallpaper(widget.note);
    if (widget.note.textColor == 0) {
      return wallpaper == null ? null : Colors.white;
    }
    return NotoAppearance.textColors[NotoAppearance.safeTextColorIndex(
      widget.note.textColor,
    )];
  }

  void _syncModel() {
    widget.note.title = title.text.trim();
    widget.note.body = body.text;
    widget.note.editor = copyEditor(_editorData());
    widget.note.updatedAt = DateTime.now();
  }

  Future<bool> _saveDraft() async {
    final shouldPersist = !widget.isNew || hasContent;
    if (!shouldPersist) return false;
    _syncModel();
    if (widget.isNew && !widget.store.notes.contains(widget.note)) {
      widget.store.notes.add(widget.note);
    }
    await widget.store.save();
    return true;
  }

  Future<void> saveAndClose() async {
    if (saved) return;
    if (title.text.trim().isNotEmpty &&
        widget.store.notes.any(
          (n) =>
              n.id != widget.note.id &&
              n.deletedAt == null &&
              n.title.trim().toLowerCase() == title.text.trim().toLowerCase(),
        )) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Já existe uma nota com esse título'),
          content: const Text(
            'Quer manter o título repetido ou voltar para mudar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Voltar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Manter'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    autosaveTimer?.cancel();
    saved = true;
    try {
      final persisted = await _saveDraft();
      await editorPrefs?.remove('editor.draft.${widget.note.id}');
      if (mounted) Navigator.pop(context, persisted);
    } catch (_) {
      saved = false;
      if (mounted) setState(() => saveLabel = 'Falha ao salvar · tentar');
    }
  }

  Future<void> shareNote() async {
    final content =
        '${title.text.trim().isEmpty ? 'Sem título' : title.text.trim()}\n\n$fullText\n\n— Noto';
    await Share.share(content);
  }

  Future<void> chooseReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: widget.note.reminderAt ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        widget.note.reminderAt ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isBefore(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'noto_reminders',
        'Lembretes do Noto',
        channelDescription: 'Lembretes configurados nas notas',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    final id = widget.note.id.hashCode & 0x7fffffff;
    await notifications.zonedSchedule(
      id,
      title.text.trim().isEmpty ? 'Lembrete do Noto' : title.text.trim(),
      body.text.trim().isEmpty
          ? 'Hora de abrir tua nota.'
          : body.text.trim().split('\n').first,
      tz.TZDateTime.from(selected, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: widget.note.id,
    );
    setState(() => widget.note.reminderAt = selected);
    await widget.store.save();
  }

  void openStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PowerNoteStyleSheet(
        store: widget.store,
        note: widget.note,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _archiveAndClose() async {
    autosaveTimer?.cancel();
    await editorPrefs?.remove('editor.draft.${widget.note.id}');
    _syncModel();
    if (widget.isNew &&
        !widget.store.notes.contains(widget.note) &&
        hasContent) {
      widget.store.notes.add(widget.note);
    }
    widget.note.archived = true;
    await widget.store.save();
    saved = true;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteAndClose() async {
    autosaveTimer?.cancel();
    await editorPrefs?.remove('editor.draft.${widget.note.id}');
    _syncModel();
    if (widget.isNew &&
        !widget.store.notes.contains(widget.note) &&
        hasContent) {
      widget.store.notes.add(widget.note);
    }
    widget.note.deletedAt = DateTime.now();
    await widget.store.save();
    saved = true;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _duplicate() async {
    final persisted = await _saveDraft();
    if (!persisted || !mounted) return;
    widget.store.duplicate(widget.note);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Cópia criada')));
  }

  Future<void> _showTaskDetails() async {
    var priority = widget.note.priority;
    var due = widget.note.dueAt;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prioridade e prazo',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'Prioridade'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Sem prioridade')),
                  DropdownMenuItem(value: 1, child: Text('Baixa')),
                  DropdownMenuItem(value: 2, child: Text('Média')),
                  DropdownMenuItem(value: 3, child: Text('Alta')),
                ],
                onChanged: (value) =>
                    setModalState(() => priority = value ?? 0),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Prazo'),
                subtitle: Text(
                  due == null
                      ? 'Sem prazo'
                      : DateFormat('dd/MM/yyyy').format(due!),
                ),
                trailing: due == null
                    ? const Icon(Icons.chevron_right_rounded)
                    : IconButton(
                        tooltip: 'Remover prazo',
                        onPressed: () => setModalState(() => due = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: due ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (selected != null) setModalState(() => due = selected);
                },
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (apply == true) {
      setState(() {
        widget.note.priority = priority;
        widget.note.dueAt = due;
      });
      await widget.store.save();
    }
  }

  void _insertCodeBlock() {
    codeBlocks.add({
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'text': '',
      'language': 'texto',
      'wrap': false,
    });
    _editorChanged();
  }

  void _format(String kind) {
    if (kind == 'code') {
      _insertCodeBlock();
      return;
    }
    if (kind == 'checklist') {
      widget.note.checklist = true;
      body.text = body.text.replaceAllMapped(
        RegExp(r'^- (\[[ xX]\])', multiLine: true),
        (m) => m[1]!,
      );
      _editorChanged();
      dirty = true;
      _autosave();
      setState(() {});
      return;
    }
    if (kind == 'bold' || kind == 'italic') {
      final at = body.selection.isValid
          ? body.selection.start
          : body.text.length;
      dynamic active = body.typingStyle[kind];
      for (final mark in body.marks) {
        if (mark['key'] == kind &&
            (mark['start'] as int) <= at &&
            (mark['end'] as int) > at)
          active = mark['value'];
      }
      body.apply(kind, active != true);
      bodyFocus.requestFocus();
      return;
    }
    body.value = switch (kind) {
      'bold' => formatSelection(body.value, prefix: '**', suffix: '**'),
      'italic' => formatSelection(body.value, prefix: '*', suffix: '*'),
      'heading' => formatSelection(body.value, prefix: '## ', eachLine: true),
      'list' => formatSelection(body.value, prefix: '- ', eachLine: true),
      'checklist' => formatSelection(
        body.value,
        prefix: '- [ ] ',
        eachLine: true,
      ),
      'quote' => formatSelection(body.value, prefix: '> ', eachLine: true),
      'code' => formatSelection(
        body.value,
        prefix: '```\n',
        suffix: '\n```',
        placeholder: '// código',
        block: true,
      ),
      'divider' => formatSelection(
        body.value.copyWith(
          selection: TextSelection.collapsed(
            offset: body.selection.isValid
                ? body.selection.end
                : body.text.length,
          ),
        ),
        placeholder: '---',
        block: true,
      ),
      _ => body.value,
    };
    bodyFocus.requestFocus();
    setState(() {});
  }

  Future<void> _insertTable() async {
    var rows = 3;
    var columns = 3;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Inserir tabela'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Escolha o tamanho. Depois, toque nas células para preencher a tabela.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: columns,
                  decoration: const InputDecoration(labelText: 'Colunas'),
                  items: List.generate(
                    6,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (value) => update(() => columns = value ?? 3),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: rows,
                  decoration: const InputDecoration(
                    labelText: 'Linhas (além do cabeçalho)',
                  ),
                  items: List.generate(
                    20,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  onChanged: (value) => update(() => rows = value ?? 3),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Inserir'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    tables.add(NotoTable.create(rows, columns));
    _editorChanged();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && editorScroll.hasClients)
        editorScroll.animateTo(
          editorScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
    });
  }

  Future<void> _showExport() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Exportar TXT'),
              onTap: () => Navigator.pop(sheetContext, 'txt'),
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded),
              title: const Text('Exportar Markdown'),
              onTap: () => Navigator.pop(sheetContext, 'md'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await _saveDraft();
    await exportNoteFile(widget.note, markdown: choice == 'md');
  }

  Future<void> _saveAsTemplate() async {
    final persisted = await _saveDraft();
    if (!persisted || !mounted) return;
    final controller = TextEditingController(
      text: title.text.trim().isEmpty ? 'Meu modelo' : title.text.trim(),
    );
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Salvar como modelo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome do modelo'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await widget.store.addTemplateFromNote(widget.note, name);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Modelo salvo')));
    }
  }

  Future<void> _showOrganize() async {
    final folderController = TextEditingController(text: widget.note.folder);
    final tagsController = TextEditingController(
      text: widget.note.tags.join(', '),
    );
    final existingFolders = <String>{
      for (final item in widget.store.notes)
        if (item.deletedAt == null && item.folder.trim().isNotEmpty)
          item.folder.trim(),
    }.toList()..sort();

    final shouldSave = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          8,
          18,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Organizar',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text('Pasta, subpasta e tags ficam todos aqui.'),
            const SizedBox(height: 16),
            TextField(
              controller: folderController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Pasta',
                hintText: 'Ex.: Escola/Química',
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
                    onPressed: () =>
                        folderController.text = existingFolders[index],
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
      widget.note.folder = cleanFolder.isEmpty ? 'Geral' : cleanFolder;
      widget.note.tags = cleanTags;
      widget.note.updatedAt = DateTime.now();
      await widget.store.save();
      if (mounted) setState(() {});
    }
    folderController.dispose();
    tagsController.dispose();
  }

  Future<void> _showConnections() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final outbound = extractWikiLinks(body.text);
          final backlinks = backlinksFor(widget.note, widget.store.notes);
          final candidates =
              widget.store.notes
                  .where(
                    (item) =>
                        item.deletedAt == null &&
                        item.id != widget.note.id &&
                        item.title.trim().isNotEmpty,
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      a.title.toLowerCase().compareTo(b.title.toLowerCase()),
                );

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .76,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Conexões',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const Text('Links e backlinks num lugar só.'),
                          ],
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
                                          leading: const Icon(
                                            Icons.note_alt_outlined,
                                          ),
                                          title: Text(target.title),
                                          subtitle: Text(target.folder),
                                          onTap: () => Navigator.pop(
                                            pickerContext,
                                            target,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                                if (target == null) return;
                                final marker = '[[${target.title.trim()}]]';
                                if (!extractWikiLinks(body.text).any(
                                  (item) =>
                                      item.toLowerCase() ==
                                      target.title.trim().toLowerCase(),
                                )) {
                                  final separator = body.text.trim().isEmpty
                                      ? ''
                                      : '\n\n';
                                  body.text = '${body.text}$separator$marker';
                                  body.selection = TextSelection.collapsed(
                                    offset: body.text.length,
                                  );
                                  setModalState(() {});
                                  if (mounted) setState(() {});
                                }
                              },
                        icon: const Icon(Icons.add_link_rounded),
                        label: const Text('Conectar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SAINDO DESTA NOTA',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (outbound.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.link_off_rounded),
                      title: Text('Nenhum link ainda'),
                      subtitle: Text(
                        'Usa Conectar ou escreve [[Nome da nota]].',
                      ),
                    )
                  else
                    ...outbound.map((linkTitle) {
                      final target = noteByTitle(widget.store.notes, linkTitle);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          target == null
                              ? Icons.link_off_rounded
                              : Icons.arrow_outward_rounded,
                        ),
                        title: Text(linkTitle),
                        subtitle: Text(
                          target == null
                              ? 'Nota não encontrada'
                              : target.folder,
                        ),
                        onTap: target == null
                            ? null
                            : () async {
                                await _saveDraft();
                                if (!sheetContext.mounted || !mounted) return;
                                Navigator.pop(sheetContext);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditorPageV2(
                                      store: widget.store,
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
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
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
                        title: Text(
                          source.title.trim().isEmpty
                              ? 'Sem título'
                              : source.title,
                        ),
                        subtitle: Text(source.folder),
                        onTap: () async {
                          await _saveDraft();
                          if (!sheetContext.mounted || !mounted) return;
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditorPageV2(
                                store: widget.store,
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

  Future<void> _showHistory() async {
    final history = widget.store.historyFor(widget.note);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .74,
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
                            style: Theme.of(context).textTheme.headlineSmall
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
                          await widget.store.clearHistory(widget.note);
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
                            'Ainda não tem versão anterior. Ela aparece depois que a nota for editada e salva.',
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
                              revision.title.trim().isEmpty
                                  ? 'Sem título'
                                  : revision.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${DateFormat('dd/MM/yyyy HH:mm').format(revision.savedAt)}\n${revision.body.trim().isEmpty ? 'Nota vazia' : revision.body.replaceAll('\n', ' ')}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Restaurar esta versão',
                              icon: const Icon(Icons.history_rounded),
                              onPressed: () async {
                                await widget.store.restoreRevision(
                                  widget.note,
                                  revision,
                                );
                                title.text = widget.note.title;
                                body.restore(
                                  widget.note.body,
                                  widget.note.editor['styles'] as List? ?? [],
                                  0,
                                );
                                codeBlocks
                                  ..clear()
                                  ..addAll(
                                    ((widget.note.editor['code'] as List?) ??
                                            [])
                                        .map(
                                          (e) => Map<String, dynamic>.from(
                                            e as Map,
                                          ),
                                        ),
                                  );
                                tables
                                  ..clear()
                                  ..addAll(
                                    ((widget.note.editor['tables'] as List?) ??
                                            [])
                                        .map(
                                          (e) => NotoTable.fromJson(
                                            Map<String, dynamic>.from(e as Map),
                                          ),
                                        ),
                                  );
                                tableEpoch++;
                                if (sheetContext.mounted)
                                  Navigator.pop(sheetContext);
                                if (mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Versão restaurada'),
                                    ),
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    autosaveTimer?.cancel();
    title.removeListener(_editorChanged);
    body.removeListener(_editorChanged);
    editorScroll.dispose();
    title.dispose();
    body.dispose();
    bodyFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallpaper = noteWallpaper(widget.note);
    final noteColorIndex = NotoAppearance.safeNoteColorIndex(widget.note.color);
    final noteColor = noteColorIndex == 0
        ? null
        : NotoAppearance.noteColors[noteColorIndex];
    final titleFamily = NotoAppearance.familyAt(
      widget.note.titleFont ?? widget.note.font,
    );
    final bodyFamily = NotoAppearance.familyAt(
      widget.note.bodyFont ?? widget.note.font,
    );
    final fg = editorTextColor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) saveAndClose();
      },
      child: Scaffold(
        backgroundColor: selectedWallpaper != null ? Colors.black : noteColor,
        appBar: focusMode
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: saveAndClose,
                ),
                foregroundColor: selectedWallpaper != null
                    ? Colors.white
                    : null,
                actions: [
                  IconButton(
                    tooltip: widget.note.favorite
                        ? 'Remover dos favoritos'
                        : 'Favoritar',
                    icon: Icon(
                      widget.note.favorite
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                    ),
                    onPressed: () {
                      setState(
                        () => widget.note.favorite = !widget.note.favorite,
                      );
                      widget.store.save();
                    },
                  ),
                  IconButton(
                    tooltip: 'Lembrete',
                    icon: Icon(
                      widget.note.reminderAt == null
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                    ),
                    onPressed: chooseReminder,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'organize') await _showOrganize();
                      if (value == 'task') await _showTaskDetails();
                      if (value == 'connections') await _showConnections();
                      if (value == 'history') await _showHistory();
                      if (value == 'preview') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MarkdownPreviewPage(
                              title: title.text,
                              markdown: fullMarkdown,
                            ),
                          ),
                        );
                      }
                      if (value == 'code') _insertCodeBlock();
                      if (value == 'export') await _showExport();
                      if (value == 'template') await _saveAsTemplate();
                      if (value == 'textMode') {
                        setState(
                          () => widget.note.checklist = !widget.note.checklist,
                        );
                        dirty = true;
                        _autosave();
                      }
                      if (value == 'share') await shareNote();
                      if (value == 'duplicate') await _duplicate();
                      if (value == 'archive') await _archiveAndClose();
                      if (value == 'delete') await _deleteAndClose();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'textMode',
                        child: ListTile(
                          leading: Icon(Icons.checklist),
                          title: Text('Alternar checklist / texto'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'organize',
                        child: ListTile(
                          leading: Icon(Icons.drive_file_move_outline),
                          title: Text('Organizar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'task',
                        child: ListTile(
                          leading: Icon(Icons.flag_outlined),
                          title: Text('Prioridade e prazo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'connections',
                        child: ListTile(
                          leading: Icon(Icons.hub_outlined),
                          title: Text('Conexões'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'preview',
                        child: ListTile(
                          leading: Icon(Icons.visibility_outlined),
                          title: Text('Prévia Markdown'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'code',
                        child: ListTile(
                          leading: Icon(Icons.code_rounded),
                          title: Text('Inserir bloco de código'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'export',
                        child: ListTile(
                          leading: Icon(Icons.file_upload_outlined),
                          title: Text('Exportar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'template',
                        child: ListTile(
                          leading: Icon(Icons.bookmark_add_outlined),
                          title: Text('Salvar como modelo'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'history',
                        child: ListTile(
                          leading: Icon(Icons.history_rounded),
                          title: Text('Histórico'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'share',
                        child: ListTile(
                          leading: Icon(Icons.ios_share_rounded),
                          title: Text('Compartilhar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'duplicate',
                        child: ListTile(
                          leading: Icon(Icons.copy_outlined),
                          title: Text('Duplicar'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'archive',
                        child: ListTile(
                          leading: Icon(Icons.archive_outlined),
                          title: Text('Arquivar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Lixeira'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (selectedWallpaper != null)
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: widget.note.wallpaperBlur,
                  sigmaY: widget.note.wallpaperBlur,
                ),
                child: Image(image: selectedWallpaper, fit: BoxFit.cover),
              ),
            if (selectedWallpaper != null)
              ColoredBox(
                color: Colors.black.withValues(
                  alpha: widget.note.wallpaperDarkness,
                ),
              ),
            SafeArea(
              top: focusMode,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  focusMode ? 24 : 20,
                  focusMode ? 22 : 8,
                  focusMode ? 24 : 20,
                  12,
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.note.emoji.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 3, right: 8),
                            child: Text(
                              widget.note.emoji,
                              style: const TextStyle(fontSize: 25),
                            ),
                          ),
                        ],
                        Expanded(
                          child: TextField(
                            controller: title,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Título',
                              hintStyle: TextStyle(
                                color: fg?.withValues(alpha: .55),
                              ),
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontFamily: titleFamily,
                              fontSize: focusMode ? 32 : 29,
                              height: 1.18,
                              fontWeight: FontWeight.w900,
                              color: fg,
                              letterSpacing: -.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (!focusMode &&
                        (widget.note.reminderAt != null ||
                            widget.note.dueAt != null ||
                            widget.note.priority > 0))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (widget.note.reminderAt != null)
                              Chip(
                                avatar: const Icon(
                                  Icons.notifications_active_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  DateFormat("dd/MM 'às' HH:mm")
                                      .format(widget.note.reminderAt!),
                                ),
                                onDeleted: () async {
                                  await notifications.cancel(
                                    widget.note.id.hashCode & 0x7fffffff,
                                  );
                                  setState(() => widget.note.reminderAt = null);
                                  widget.store.save();
                                },
                              ),
                            if (widget.note.priority > 0)
                              Chip(
                                avatar: Icon(
                                  priorityIcon(widget.note.priority),
                                  size: 16,
                                ),
                                label: Text(
                                  priorityLabel(widget.note.priority),
                                ),
                              ),
                            if (widget.note.dueAt != null)
                              Chip(
                                avatar: const Icon(
                                  Icons.event_outlined,
                                  size: 16,
                                ),
                                label: Text(
                                  DateFormat('dd/MM')
                                      .format(widget.note.dueAt!),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (!widget.note.checklist && !focusMode) ...[
                      _richToolbar(),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(height: focusMode ? 18 : 12),
                    Expanded(
                      child: widget.note.checklist
                          ? legacy.ChecklistEditor(
                              controller: body,
                              family: bodyFamily,
                              fontSize: widget.store.fontSize,
                              textColor: fg,
                              onChanged: () => setState(() {}),
                            )
                          : ListView(
                              controller: editorScroll,
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                TextField(
                                  controller: body,
                                  focusNode: bodyFocus,
                                  minLines: 6,
                                  maxLines: null,
                                  textAlign: alignment,
                                  keyboardType: TextInputType.multiline,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  decoration: InputDecoration(
                                    hintText: 'Começa a escrever...',
                                    hintStyle: TextStyle(
                                      color: fg?.withValues(alpha: .48),
                                    ),
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  style: TextStyle(
                                    fontFamily: bodyFamily,
                                    fontSize: widget.store.fontSize,
                                    height: 1.6,
                                    color: fg,
                                  ),
                                ),
                                for (final code in codeBlocks)
                                  NotoCodeBlock(
                                    key: ValueKey('${code['id']}-$tableEpoch'),
                                    data: code,
                                    onChanged: _editorChanged,
                                    onDelete: () {
                                      codeBlocks.remove(code);
                                      _editorChanged();
                                    },
                                  ),
                                for (final table in tables)
                                  VisualNoteTable(
                                    key: ValueKey('${table.id}-$tableEpoch'),
                                    table: table,
                                    fontFamily: bodyFamily,
                                    fontSize: widget.store.fontSize,
                                    onChanged: _editorChanged,
                                    onDelete: () {
                                      tables.remove(table);
                                      _editorChanged();
                                    },
                                  ),
                              ],
                            ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _autosave,
                            child: Text(
                              saveLabel,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copiar nota',
                          onPressed: _copyAll,
                          icon: const Icon(Icons.copy_all, size: 20),
                        ),
                        IconButton(
                          tooltip: 'Fechar teclado',
                          onPressed: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          icon: const Icon(Icons.keyboard_hide_outlined),
                        ),
                      ],
                    ),
                    if (!focusMode)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectedWords > 0
                                  ? '$selectedWords palavras selecionadas'
                                  : '$words palavras · $characters caracteres',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: fg?.withValues(alpha: .65),
                              ),
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Modo foco',
                            onPressed: () {
                              setState(() => focusMode = true);
                              editorPrefs?.setBool('editor.focus', true);
                            },
                            icon: const Icon(Icons.fullscreen_rounded),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonalIcon(
                            onPressed: openStyleSheet,
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('Estilo'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            if (focusMode)
              Positioned(
                top: 12,
                right: 12,
                child: SafeArea(
                  child: IconButton.filledTonal(
                    tooltip: 'Sair do modo foco',
                    onPressed: () {
                      setState(() => focusMode = false);
                      editorPrefs?.setBool('editor.focus', false);
                    },
                    icon: const Icon(Icons.fullscreen_exit_rounded),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
