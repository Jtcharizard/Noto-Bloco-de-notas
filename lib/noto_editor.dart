import 'noto_code_block.dart';
import 'noto_mixed_editor.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'noto_rich_editor.dart';
import 'noto_library.dart';

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'noto_features.dart';
import 'noto_formatting.dart';
import 'noto_models.dart';
import 'noto_power_tools.dart';
import 'noto_store.dart';
import 'noto_theme.dart';
import 'noto_dictation.dart';
import 'noto_vault.dart';
import 'noto_extras.dart';
import 'noto_smart.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    required this.store,
    required this.note,
    required this.isNew,
    this.startDictation = false,
  });

  final AppStore store;
  final Note note;
  final bool isNew;

  /// Abre já ouvindo o ditado (atalho "Ditar nota").
  final bool startDictation;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage>
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
  TextAlign alignment = TextAlign.left;
  bool hideDone = false;
  bool _countsAsVault = false;
  bool readOnly = false;

  /// Nota protegida: abre só para ler, até tocar em "Editar".
  bool protectedNote = false;

  /// Lista que volta desmarcada todo dia (rotina, remédios, academia).
  bool resetDaily = false;
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
    if (widget.note.locked) {
      widget.store.vaultScreenOpened();
      _countsAsVault = true;
    }
    final metadata = widget.note.editor;
    hideDone = metadata['hideDone'] == true;
    protectedNote = metadata['protected'] == true;
    readOnly = protectedNote;
    resetDaily = metadata['resetDaily'] == true;
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
    if (RegExp(
      r'^\s*(?:-\s*)?\[[ xX]\]',
      multiLine: true,
    ).hasMatch(body.text)) {
      widget.note.checklist = true;
    }
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
    _slashBase = body.text;
    body.addListener(_watchSlash);
    _loadEditorPreferences();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowTaskTip();
      if (widget.startDictation) {
        _dictate();
      } else if (widget.isNew && !widget.note.checklist && body.text.isEmpty) {
        // Nota nova em branco: já abre pronta para escrever.
        bodyFocus.requestFocus();
      }
    });
  }

  void _maybeShowTaskTip() {
    if (!mounted || !widget.note.checklist) return;
    if (!widget.store.takeTip('tasks-enter')) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 4),
        content: Text(
          'Dica: Enter cria a próxima tarefa. Deslize uma tarefa para apagar.',
        ),
      ),
    );
  }

  Map<String, dynamic> _editorData() => {
    'checklist': widget.note.checklist,
    'code': codeBlocks,
    'styles': body.marks,
    'tables': tables.map((t) => t.toJson()).toList(),
    'align': alignment.index,
    'hideDone': hideDone,
    if (protectedNote) 'protected': true,
    if (resetDaily) 'resetDaily': true,
    if (resetDaily) 'lastReset': widget.note.editor['lastReset'] ?? dayKey(DateTime.now()),
    if (widget.note.editor['daily'] != null) 'daily': widget.note.editor['daily'],
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
    final raw = prefs.getString('editor.draft.${widget.note.id}');
    if (!dirty && raw != null) {
      try {
        final draft = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final time = DateTime.tryParse(draft['at'] as String? ?? '');
        if (time != null && time.isAfter(widget.note.updatedAt)) {
          _restoreSnapshot(draft['snapshot'] as String);
          saveLabel = 'Texto não salvo recuperado';
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
      if (mounted) setState(() => saveLabel = 'Não salvou · toque para tentar de novo');
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
              update(() => result = 'Digite o que você quer buscar');
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
              update(
                () => result = count == 1
                    ? '1 trecho substituído'
                    : '$count trechos substituídos',
              );
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
                  ? 'Encontrado e selecionado no texto'
                  : inTables > 0
                  ? 'Encontrado só nas tabelas. Use "Substituir tudo".'
                  : 'Nada encontrado',
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
                      labelText: 'Buscar (maiúsculas contam)',
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
      builder: (_) => FontPickerSheet(
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

  void _tool(String key) {
    switch (key) {
      case 'table':
        _insertTable();
        break;
      case 'datetime':
        _insertText(DateFormat("dd/MM/yyyy 'às' HH:mm").format(DateTime.now()));
        break;
      case 'dictate':
        _dictate();
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
      case 'case':
        _changeCase();
        break;
      case 'align':
        _pickAlignment();
        break;
      default:
        _format(key);
    }
  }

  Future<void> _pickAlignment() async {
    const options = [
      (TextAlign.left, 'À esquerda', Icons.format_align_left_rounded),
      (TextAlign.center, 'Centralizado', Icons.format_align_center_rounded),
      (TextAlign.right, 'À direita', Icons.format_align_right_rounded),
      (TextAlign.justify, 'Justificado', Icons.format_align_justify_rounded),
    ];
    final picked = await showModalBottomSheet<TextAlign>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            const ListTile(title: Text('Alinhamento')),
            for (final option in options)
              ListTile(
                leading: Icon(option.$3),
                title: Text(option.$2),
                trailing: alignment == option.$1
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(ctx, option.$1),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => alignment = picked);
    _editorChanged();
  }

  /// Coloca texto no cursor (texto comum) ou numa linha nova (lista de tarefas).
  void _insertText(String text) {
    if (text.isEmpty) return;
    if (widget.note.checklist) {
      body.text = body.text.trim().isEmpty ? text : '${body.text}\n$text';
      tableEpoch++;
      _editorChanged();
      return;
    }
    final selection = body.selection;
    final at = selection.isValid ? selection.start : body.text.length;
    final end = selection.isValid ? selection.end : body.text.length;
    final before = body.text.substring(0, at);
    final spacer = before.isEmpty || before.endsWith(' ') || before.endsWith('\n')
        ? ''
        : ' ';
    final insert = '$spacer$text';
    body.value = TextEditingValue(
      text: body.text.replaceRange(at, end, insert),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    bodyFocus.requestFocus();
  }

  Future<void> _dictate() async {
    final text = await showDictation(context);
    if (text == null || !mounted) return;
    _insertText(text);
  }

  /// Desmarca todas as tarefas ou apaga as concluídas.
  void _rewriteTasks({required bool remove}) {
    final task = RegExp(r'^(\s*(?:[-*]\s*)?)\[([xX])\](.*)$');
    final lines = <String>[];
    var changed = 0;
    for (final line in body.text.split('\n')) {
      final match = task.firstMatch(line);
      if (match == null) {
        lines.add(line);
        continue;
      }
      changed++;
      if (!remove) lines.add('${match.group(1)}[ ]${match.group(3)}');
    }
    if (changed == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhuma tarefa concluída.')),
      );
      return;
    }
    body.text = lines.isEmpty ? '- [ ] ' : lines.join('\n');
    tableEpoch++;
    _editorChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          remove
              ? (changed == 1 ? '1 tarefa apagada' : '$changed tarefas apagadas')
              : (changed == 1
                    ? '1 tarefa desmarcada'
                    : '$changed tarefas desmarcadas'),
        ),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _historyEdit(false),
        ),
      ),
    );
  }

  void _undoSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _historyEdit(false),
        ),
      ),
    );
  }

  /// Ordena de A a Z. Nas tarefas, ordena cada bloco de tarefas e mantém
  /// as pendentes antes das feitas; no texto, ordena todas as linhas com texto.
  void _sortLines({required bool tasksOnly}) {
    final lines = body.text.split('\n');
    int compare(String a, String b) =>
        foldForSearch(a.trim()).compareTo(foldForSearch(b.trim()));
    if (!tasksOnly) {
      final filled = lines.where((l) => l.trim().isNotEmpty).toList()
        ..sort(compare);
      if (filled.length < 2) return;
      body.text = filled.join('\n');
    } else {
      final task = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');
      final out = <String>[];
      var block = <String>[];
      void flush() {
        String text(String l) => task.firstMatch(l)?.group(2) ?? l;
        bool done(String l) => task.firstMatch(l)?.group(1) != ' ';
        block.sort((a, b) {
          if (done(a) != done(b)) return done(a) ? 1 : -1;
          return compare(text(a), text(b));
        });
        out.addAll(block);
        block = [];
      }
      for (final line in lines) {
        if (task.hasMatch(line)) {
          block.add(line);
        } else {
          flush();
          out.add(line);
        }
      }
      flush();
      body.text = out.join('\n');
    }
    tableEpoch++;
    _editorChanged();
    _undoSnack('Linhas ordenadas de A a Z');
  }

  Future<void> _changeCase() async {
    final selection = body.selection;
    if (!selection.isValid || selection.isCollapsed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o trecho primeiro.')),
      );
      return;
    }
    final mode = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: const Text('MAIÚSCULAS'),
              onTap: () => Navigator.pop(ctx, 0),
            ),
            ListTile(
              title: const Text('minúsculas'),
              onTap: () => Navigator.pop(ctx, 1),
            ),
            ListTile(
              title: const Text('Primeira Letra De Cada Palavra'),
              onTap: () => Navigator.pop(ctx, 2),
            ),
            ListTile(
              title: const Text('Primeira letra da frase'),
              onTap: () => Navigator.pop(ctx, 3),
            ),
          ],
        ),
      ),
    );
    if (mode == null || !mounted) return;
    final text = selection.textInside(body.text);
    String capital(String word) => word.isEmpty
        ? word
        : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
    final changed = switch (mode) {
      0 => text.toUpperCase(),
      1 => text.toLowerCase(),
      2 => text.split(' ').map(capital).join(' '),
      _ => capital(text),
    };
    body.value = body.value.copyWith(
      text: body.text.replaceRange(selection.start, selection.end, changed),
      selection: TextSelection(
        baseOffset: selection.start,
        extentOffset: selection.start + changed.length,
      ),
    );
    bodyFocus.requestFocus();
  }

  Future<void> _addManyTasks() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar várias tarefas'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 4,
          maxLines: 10,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Uma tarefa por linha\nLeite\nPão\nOvos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    controller.dispose();
    if (text == null || !mounted) return;
    final items = text
        .split('\n')
        .map((line) => line.replaceFirst(RegExp(r'^\s*(?:[-*•]|\d+\s?[.)\-–])\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .map((line) => '- [ ] $line')
        .toList();
    if (items.isEmpty) return;
    // Tira a tarefa vazia do fim, se houver, antes de adicionar.
    final current = body.text.replaceFirst(RegExp(r'\n?- \[ \] ?$'), '');
    body.text = [if (current.trim().isNotEmpty) current, ...items].join('\n');
    tableEpoch++;
    _editorChanged();
    _undoSnack(
      items.length == 1
          ? '1 tarefa adicionada'
          : '${items.length} tarefas adicionadas',
    );
  }

  void _checkAllTasks() {
    final pending = RegExp(r'^(\s*(?:[-*]\s*)?)\[ \](.*)$');
    var changed = 0;
    body.text = body.text.split('\n').map((line) {
      final match = pending.firstMatch(line);
      if (match == null) return line;
      changed++;
      return '${match.group(1)}[x]${match.group(2)}';
    }).join('\n');
    if (changed == 0) return;
    tableEpoch++;
    _editorChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tudo feito! 🎉'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _historyEdit(false),
        ),
      ),
    );
  }

  Future<void> _copyPending() async {
    final pending = RegExp(r'^\s*(?:[-*]\s*)?\[ \]\s?(.*)$');
    final items = [
      for (final line in body.text.split('\n'))
        if (pending.firstMatch(line)?.group(1)?.trim().isNotEmpty ?? false)
          '• ${pending.firstMatch(line)!.group(1)!.trim()}',
    ];
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nada pendente nesta lista.')),
      );
      return;
    }
    final header = title.text.trim().isEmpty ? '' : '${title.text.trim()}\n';
    await Clipboard.setData(ClipboardData(text: '$header${items.join('\n')}'));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          items.length == 1 ? '1 item copiado' : '${items.length} itens copiados',
        ),
      ),
    );
  }

  Future<void> _showNoteInfo() async {
    String date(DateTime value) =>
        DateFormat("dd/MM/yyyy 'às' HH:mm").format(value);
    final pending = countPendingTasks(body.text);
    final done = countDoneTasks(body.text);
    final rows = <(String, String)>[
      ('Criada', date(widget.note.createdAt)),
      ('Editada', date(widget.note.updatedAt)),
      ('Pasta', widget.note.folder),
      if (widget.note.tags.isNotEmpty)
        ('Tags', widget.note.tags.map((t) => '#$t').join(' ')),
      ('Palavras', '$words'),
      ('Caracteres', '$characters'),
      ('Tempo de leitura', readingMinutes <= 1 ? 'menos de 1 min' : '$readingMinutes min'),
      if (pending + done > 0) ('Tarefas', '$done de ${pending + done} feitas'),
      if (widget.note.reminderAt != null)
        ('Lembrete', date(widget.note.reminderAt!)),
      if (widget.note.dueAt != null)
        ('Prazo', DateFormat('dd/MM/yyyy').format(widget.note.dueAt!)),
      ('Versões guardadas', '${widget.store.historyFor(widget.note).length}'),
    ];
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Informações da nota',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ),
              for (final row in rows)
                ListTile(
                  dense: true,
                  title: Text(row.$1),
                  trailing: Text(
                    row.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tira a lista de tarefas da nota e deixa só o texto. Dá para desfazer.
  void _deleteTaskList() {
    if (!hasTaskLines(body.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta nota não tem lista.')),
      );
      return;
    }
    final rest = removeTaskLines(body.text);
    // Sem tarefas, a nota vira texto comum com o que sobrou.
    widget.note.checklist = false;
    body.text = rest;
    tableEpoch++;
    _editorChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Lista excluída da nota'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () => _historyEdit(false),
        ),
      ),
    );
  }

  /// Sumário da nota: pula para cada título (linhas com #).
  Future<void> _showSections() async {
    final sections = extractSections(body.text);
    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sem seções ainda. Use Formatar texto > Título para criar uma.',
          ),
        ),
      );
      return;
    }
    final picked = await showModalBottomSheet<NoteSection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            8,
            MediaQuery.viewPaddingOf(ctx).bottom + 12,
          ),
          children: [
            const ListTile(
              title: Text(
                'Ir para seção',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
            for (final section in sections)
              ListTile(
                contentPadding: EdgeInsets.only(
                  left: 16.0 + (section.level - 1) * 18,
                  right: 16,
                ),
                leading: Icon(
                  section.level == 1
                      ? Icons.title_rounded
                      : Icons.subdirectory_arrow_right_rounded,
                ),
                title: Text(
                  section.title,
                  style: TextStyle(
                    fontWeight: section.level == 1
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, section),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    body.selection = TextSelection.collapsed(
      offset: picked.offset.clamp(0, body.text.length),
    );
    bodyFocus.requestFocus();
  }

  static const _shortcutChannel = MethodChannel('noto/share');

  /// Cria um ícone da nota na tela inicial do celular.
  Future<void> _pinToHomeScreen() async {
    if (widget.note.locked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notas do cofre não ganham atalho.')),
      );
      return;
    }
    final persisted = await _saveDraft();
    if (!mounted) return;
    if (!persisted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreva algo na nota primeiro.')),
      );
      return;
    }
    var ok = false;
    try {
      ok = await _shortcutChannel.invokeMethod<bool>('pinShortcut', {
            'id': widget.note.id,
            'title': displayTitle(widget.note),
          }) ??
          false;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Confirme no aviso do celular para pôr a nota na tela inicial.'
              : 'Este celular não deixa criar atalhos de notas.',
        ),
      ),
    );
  }

  /// Links, e-mails e telefones da nota, para abrir com um toque.
  void _showLinks(List<NoteLink> links) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: EdgeInsets.fromLTRB(
            8,
            0,
            8,
            MediaQuery.viewPaddingOf(ctx).bottom + 12,
          ),
          children: [
            const ListTile(
              title: Text(
                'Links da nota',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              subtitle: Text('Toque para abrir. Segure para copiar.'),
            ),
            for (final link in links)
              ListTile(
                leading: Icon(switch (link.kind) {
                  'email' => Icons.mail_outline_rounded,
                  'phone' => Icons.call_outlined,
                  _ => Icons.public_rounded,
                }),
                title: Text(
                  link.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(switch (link.kind) {
                  'email' => 'Escrever e-mail',
                  'phone' => 'Ligar',
                  _ => 'Abrir no navegador',
                }),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await launchUrl(
                    link.uri,
                    mode: LaunchMode.externalApplication,
                  ).catchError((_) => false);
                  if (!ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Nenhum app do celular abre esse link.'),
                      ),
                    );
                  }
                },
                onLongPress: () {
                  Clipboard.setData(ClipboardData(text: link.text));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copiado')),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Lista toda marcada: oferece arquivar (como no Keep e no Todoist).
  void _listFinished() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Tudo feito! 🎉'),
        action: resetDaily
            ? null
            : SnackBarAction(label: 'Arquivar lista', onPressed: _archiveAndClose),
      ),
    );
  }

  String _slashBase = '';

  /// "/" sozinho no começo de uma linha abre o menu de inserir (como no Notion).
  void _watchSlash() {
    final text = body.text;
    final before = _slashBase;
    _slashBase = text;
    if (restoringEditor || widget.note.checklist || readOnly) return;
    if (text.length != before.length + 1) return;
    final selection = body.selection;
    if (!selection.isValid || !selection.isCollapsed) return;
    final at = selection.baseOffset;
    if (at < 1 || at > text.length || text[at - 1] != '/') return;
    if (at - 1 > 0 && text[at - 2] != '\n') return;
    if (at < text.length && text[at] != '\n') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showSlashMenu(at - 1);
    });
  }

  Future<void> _showSlashMenu(int at) async {
    final value = await _gridSheet(
      title: 'Inserir aqui',
      subtitle: 'Dica: digite / numa linha vazia para abrir este menu',
      sections: const [
        (
          'Texto',
          [
            _MenuAction('heading', Icons.title_rounded, 'Título'),
            _MenuAction('subheading', Icons.text_fields_rounded, 'Subtítulo'),
            _MenuAction('list', Icons.format_list_bulleted_rounded, 'Lista'),
            _MenuAction('numbered', Icons.format_list_numbered_rounded, 'Lista numerada'),
            _MenuAction('quote', Icons.format_quote_rounded, 'Citação'),
          ],
        ),
        (
          'Blocos',
          [
            _MenuAction('checklist', Icons.checklist_rounded, 'Tarefas'),
            _MenuAction('table', Icons.table_chart_outlined, 'Tabela'),
            _MenuAction('code', Icons.code_rounded, 'Código'),
            _MenuAction('divider', Icons.horizontal_rule_rounded, 'Separador'),
            _MenuAction('datetime', Icons.today_outlined, 'Data e hora'),
          ],
        ),
      ],
    );
    if (value == null || !mounted) return;
    // Tira a "/" que abriu o menu.
    final text = body.text;
    if (at < text.length && text[at] == '/') {
      body.value = TextEditingValue(
        text: text.replaceRange(at, at + 1, ''),
        selection: TextSelection.collapsed(offset: at),
      );
    }
    // Linha vazia: só põe o começo da linha, sem texto de exemplo.
    const starts = {
      'heading': '## ',
      'subheading': '### ',
      'list': '- ',
      'numbered': '1. ',
      'quote': '> ',
    };
    final start = starts[value];
    if (start != null) {
      body.value = formatSelection(
        body.value,
        prefix: start,
        placeholder: '',
        eachLine: true,
      );
      bodyFocus.requestFocus();
    } else {
      _tool(value);
    }
  }

  /// Salva mudanças que não mexem no texto (proteção, rotina...).
  void _markMetaChanged() {
    dirty = true;
    autosaveTimer?.cancel();
    autosaveTimer = Timer(const Duration(milliseconds: 300), _autosave);
  }

  void _setHideDone(bool value) {
    setState(() => hideDone = value);
    dirty = true;
    autosaveTimer?.cancel();
    autosaveTimer = Timer(const Duration(milliseconds: 300), _autosave);
  }

  void _setChecklistMode(bool on) {
    if (on == widget.note.checklist) return;
    widget.note.checklist = on;
    if (on) {
      // Itens de lista ("- leite", "1- pão", "• ovos") viram tarefas.
      final item = RegExp(r'^(\s*)(?:[-*•]|\d+\s?[.)\-–])\s+(.+)$');
      var converted = 0;
      final lines = body.text.split('\n').map((line) {
        if (RegExp(r'^\s*(?:[-*]\s*)?\[[ xX]\]').hasMatch(line)) return line;
        final match = item.firstMatch(line);
        if (match == null) return line;
        converted++;
        return '${match.group(1)}- [ ] ${match.group(2)}';
      }).toList();
      body.text = lines.join('\n');
      if (converted == 0 && !hasTaskLines(body.text)) {
        body.text = body.text.trim().isEmpty
            ? '- [ ] '
            : '${body.text.trimRight()}\n- [ ] ';
      }
    } else {
      // Tarefas viram itens "- ". Tarefas vazias somem, então uma lista
      // nova sem nada volta a ser uma nota em branco.
      final task = RegExp(r'^\s*(?:[-*]\s*)?\[([ xX])\]\s?(.*)$');
      body.text = body.text
          .split('\n')
          .map((line) {
            final match = task.firstMatch(line);
            if (match == null) return line;
            final text = (match.group(2) ?? '').trim();
            return text.isEmpty ? null : '- $text';
          })
          .whereType<String>()
          .join('\n')
          .trim();
    }
    tableEpoch++;
    _editorChanged();
    if (on) _maybeShowTaskTip();
  }

  /// Folha com grade de botões, usada nos menus da nota.
  Future<String?> _gridSheet({
    required String title,
    String? subtitle,
    Widget? top,
    required List<(String, List<_MenuAction>)> sections,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * .86,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              0,
              16,
              MediaQuery.viewPaddingOf(ctx).bottom + 18,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: cs.onSurface.withValues(alpha: .6),
                      ),
                    ),
                  ),
                if (top != null) ...[const SizedBox(height: 14), top],
                for (final section in sections)
                  if (section.$2.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
                      child: Text(
                        section.$1.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          letterSpacing: .8,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    _MenuGrid(
                      items: section.$2,
                      onPick: (id) => Navigator.pop(ctx, id),
                    ),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showInsertMenu() async {
    final value = await _gridSheet(
      title: 'Inserir',
      sections: [
        (
          'Na nota',
          [
            if (!widget.note.checklist) ...const [
              _MenuAction('table', Icons.table_chart_outlined, 'Tabela'),
              _MenuAction('code', Icons.code_rounded, 'Bloco de código'),
              _MenuAction('divider', Icons.horizontal_rule_rounded, 'Separador'),
            ],
            const _MenuAction('datetime', Icons.today_outlined, 'Data e hora'),
            if (widget.note.checklist)
              const _MenuAction('add-many', Icons.playlist_add_rounded, 'Várias tarefas'),
          ],
        ),
      ],
    );
    if (value == null || !mounted) return;
    if (value == 'add-many') {
      await _addManyTasks();
    } else {
      _tool(value);
    }
  }

  /// Formatação do trecho de texto (título, lista, cor...).
  Future<void> _showFormatText() async {
    final value = await _gridSheet(
      title: 'Formatar texto',
      subtitle: 'Vale para o trecho selecionado ou para onde está o cursor',
      sections: const [
        (
          'Formato',
          [
            _MenuAction('heading', Icons.title_rounded, 'Título'),
            _MenuAction('list', Icons.format_list_bulleted_rounded, 'Lista'),
            _MenuAction('quote', Icons.format_quote_rounded, 'Citação'),
            _MenuAction('case', Icons.text_fields_rounded, 'Maiúsculas'),
          ],
        ),
        (
          'Cor e letra',
          [
            _MenuAction('font', Icons.font_download_outlined, 'Fonte'),
            _MenuAction('color', Icons.format_color_text_rounded, 'Cor do texto'),
            _MenuAction('highlight', Icons.highlight_rounded, 'Marca-texto'),
            _MenuAction('align', Icons.format_align_left_rounded, 'Alinhar'),
          ],
        ),
      ],
    );
    if (value == null || !mounted) return;
    _tool(value);
  }

  /// Menu único da nota: ações rápidas no topo e o resto por assunto.
  Future<void> _showNoteMenu() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final note = widget.note;
    final checklist = note.checklist;
    final notified = widget.store.pinnedNotificationNoteId == note.id;
    final cs = Theme.of(context).colorScheme;

    Widget quick(String id, IconData icon, String label, {bool on = false}) =>
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: on ? cs.primaryContainer : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.pop(context, id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        color: on ? cs.onPrimaryContainer : cs.onSurface,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: on ? cs.onPrimaryContainer : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

    final value = await _gridSheet(
      title: title.text.trim().isEmpty ? 'Nota sem título' : title.text.trim(),
      subtitle:
          'Editada ${DateFormat("dd/MM 'às' HH:mm").format(note.updatedAt)} · '
          '$words ${words == 1 ? 'palavra' : 'palavras'}',
      top: Row(
        children: [
          quick(
            'pin',
            note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
            note.pinned ? 'Fixada' : 'Fixar',
            on: note.pinned,
          ),
          quick(
            'favorite',
            note.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
            note.favorite ? 'Favorita' : 'Favoritar',
            on: note.favorite,
          ),
          quick('share', Icons.ios_share_rounded, 'Enviar'),
          quick('copy', Icons.copy_all_rounded, 'Copiar'),
        ],
      ),
      sections: [
        (
          'Organizar',
          const [
            _MenuAction('organize', Icons.drive_file_move_outline, 'Pasta e tags'),
            _MenuAction('reminder', Icons.notifications_none_rounded, 'Lembrete'),
            _MenuAction('task', Icons.flag_outlined, 'Prazo e prioridade'),
            _MenuAction('connections', Icons.hub_outlined, 'Conexões'),
          ],
        ),
        if (checklist)
          (
            'Tarefas',
            [
              _MenuAction(
                'hide-done',
                hideDone
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                hideDone ? 'Mostrar feitas' : 'Esconder feitas',
              ),
              const _MenuAction('add-many', Icons.playlist_add_rounded, 'Várias de uma vez'),
              const _MenuAction('copy-pending', Icons.content_copy_rounded, 'Copiar o que falta'),
              const _MenuAction('check-all', Icons.done_all_rounded, 'Marcar todas'),
              const _MenuAction('uncheck-all', Icons.restart_alt_rounded, 'Desmarcar todas'),
              const _MenuAction('remove-done', Icons.playlist_remove_rounded, 'Apagar feitas'),
              const _MenuAction('sort-tasks', Icons.sort_by_alpha_rounded, 'Ordenar A-Z'),
              const _MenuAction('fresh-copy', Icons.copy_all_outlined, 'Cópia desmarcada'),
              const _MenuAction(
                'delete-list',
                Icons.delete_sweep_outlined,
                'Excluir lista',
                danger: true,
              ),
              _MenuAction(
                'reset-daily',
                resetDaily ? Icons.event_busy_outlined : Icons.event_repeat_outlined,
                resetDaily ? 'Parar de desmarcar' : 'Desmarcar todo dia',
              ),
            ],
          ),
        (
          'Ferramentas',
          [
            const _MenuAction('search', Icons.find_replace_rounded, 'Buscar e trocar'),
            const _MenuAction('focus', Icons.fullscreen_rounded, 'Modo foco'),
            _MenuAction(
              'protect',
              protectedNote ? Icons.lock_open_rounded : Icons.edit_off_outlined,
              protectedNote ? 'Tirar proteção' : 'Proteger nota',
            ),
            if (!checklist) ...[
              const _MenuAction('preview', Icons.visibility_outlined, 'Ver formatada'),
              const _MenuAction('sections', Icons.toc_rounded, 'Ir para seção'),
            ],
            const _MenuAction('info', Icons.info_outline_rounded, 'Informações'),
          ],
        ),
        (
          'Salvar e enviar',
          [
            const _MenuAction('share-image', Icons.image_outlined, 'Como imagem'),
            const _MenuAction('export', Icons.file_upload_outlined, 'Exportar arquivo'),
            const _MenuAction('template', Icons.bookmark_add_outlined, 'Salvar como modelo'),
            const _MenuAction('duplicate', Icons.copy_outlined, 'Duplicar'),
            const _MenuAction('history', Icons.history_rounded, 'Versões antigas'),
            const _MenuAction('home-shortcut', Icons.add_to_home_screen_rounded, 'Atalho na tela inicial'),
            if (!note.locked)
              _MenuAction(
                'widget-note',
                Icons.widgets_outlined,
                widget.store.widgetNoteId == note.id
                    ? 'Já está no widget'
                    : 'Mostrar no widget',
              ),
            _MenuAction(
              'pin-notification',
              notified
                  ? Icons.notifications_off_outlined
                  : Icons.notification_add_outlined,
              notified ? 'Tirar da notificação' : 'Fixar na notificação',
            ),
          ],
        ),
        (
          'Guardar',
          [
            _MenuAction(
              'vault',
              note.locked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
              note.locked ? 'Tirar do cofre' : 'Mover para o cofre',
            ),
            const _MenuAction('archive', Icons.archive_outlined, 'Arquivar'),
            const _MenuAction(
              'delete',
              Icons.delete_outline_rounded,
              'Lixeira',
              danger: true,
            ),
          ],
        ),
      ],
    );
    if (value == null || !mounted) return;
    await _runNoteAction(value);
  }

  Future<void> _runNoteAction(String value) async {
    switch (value) {
      case 'pin':
        setState(() => widget.store.togglePin(widget.note));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.note.pinned
                  ? 'Fixada no topo da tela inicial'
                  : 'Tirada do topo',
            ),
          ),
        );
      case 'favorite':
        setState(() => widget.note.favorite = !widget.note.favorite);
        widget.store.save();
      case 'share':
        await shareNote();
      case 'share-image':
        _syncModel();
        await shareNoteAsImage(
          context,
          title: title.text,
          body: fullText,
          background: NotoAppearance.safeNoteColorIndex(widget.note.color) == 0
              ? null
              : NotoAppearance.noteColors[
                  NotoAppearance.safeNoteColorIndex(widget.note.color)],
          fontFamily: NotoAppearance.familyAt(
            widget.note.bodyFont ?? widget.note.font,
          ),
        );
      case 'copy':
        await _copyAll();
      case 'organize':
        await _showOrganize();
      case 'reminder':
        await chooseReminder();
      case 'task':
        await _showTaskDetails();
      case 'connections':
        await _showConnections();
      case 'history':
        await _showHistory();
      case 'export':
        await _showExport();
      case 'template':
        await _saveAsTemplate();
      case 'duplicate':
        await _duplicate();
      case 'vault':
        await _toggleVault();
      case 'archive':
        await _archiveAndClose();
      case 'delete':
        await _deleteAndClose();
      case 'hide-done':
        _setHideDone(!hideDone);
      case 'uncheck-all' || 'remove-done':
        _rewriteTasks(remove: value == 'remove-done');
      case 'add-many':
        await _addManyTasks();
      case 'sort-tasks':
        _sortLines(tasksOnly: true);
      case 'fresh-copy':
        // Lista para usar de novo (compras da semana que vem, por exemplo).
        final persisted = await _saveDraft();
        if (!persisted || !mounted) return;
        final copy = widget.store.duplicate(widget.note);
        copy.body = uncheckAllTasks(copy.body);
        await widget.store.save();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cópia criada com tudo desmarcado'),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () {
                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        EditorPage(store: widget.store, note: copy, isNew: false),
                  ),
                );
              },
            ),
          ),
        );
      case 'delete-list':
        _deleteTaskList();
      case 'sections':
        await _showSections();
      case 'home-shortcut':
        await _pinToHomeScreen();
      case 'widget-note':
        final persisted = await _saveDraft();
        if (!mounted) return;
        if (!persisted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Escreva algo na nota primeiro.')),
          );
          return;
        }
        widget.store.widgetNoteId = widget.note.id;
        await widget.store.save();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Pronto! Esta nota aparece no widget "Noto · Nota" da tela inicial.',
            ),
          ),
        );
      case 'check-all':
        _checkAllTasks();
      case 'copy-pending':
        await _copyPending();
      case 'info':
        await _showNoteInfo();
      case 'focus':
        FocusManager.instance.primaryFocus?.unfocus();
        setState(() => focusMode = true);
      case 'protect':
        setState(() {
          protectedNote = !protectedNote;
          readOnly = protectedNote;
        });
        if (readOnly) FocusManager.instance.primaryFocus?.unfocus();
        _markMetaChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              protectedNote
                  ? 'Nota protegida: abre só para ler. Toque em "Editar" quando precisar mudar.'
                  : 'Proteção tirada.',
            ),
          ),
        );
      case 'reset-daily':
        setState(() => resetDaily = !resetDaily);
        if (resetDaily) {
          widget.note.editor = {
            ...widget.note.editor,
            'lastReset': dayKey(DateTime.now()),
          };
        }
        _markMetaChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resetDaily
                  ? 'Todo dia, ao abrir o Noto, as tarefas desta lista voltam desmarcadas.'
                  : 'A lista não desmarca mais sozinha.',
            ),
          ),
        );
      case 'read-mode':
        setState(() => readOnly = !readOnly);
        if (readOnly) FocusManager.instance.primaryFocus?.unfocus();
      case 'pin-notification':
        _syncModel();
        if (widget.isNew && !widget.store.notes.contains(widget.note)) {
          if (!hasContent) return;
          widget.store.notes.add(widget.note);
        }
        final pinned = widget.store.pinnedNotificationNoteId == widget.note.id;
        if (pinned) {
          await widget.store.hidePinnedNotification();
        } else {
          await widget.store.showPinnedNotification(widget.note);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pinned
                  ? 'Nota tirada da barra de notificações'
                  : 'Nota fixada na barra de notificações',
            ),
          ),
        );
      case 'preview':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                MarkdownPreviewPage(title: title.text, markdown: fullMarkdown),
          ),
        );
      default:
        _tool(value);
    }
  }

  /// Linha de etiquetas logo abaixo do título: pasta, lembrete, prazo...
  Widget _metaChips(Color? fg) {
    final note = widget.note;
    final cs = Theme.of(context).colorScheme;
    final base = fg ?? cs.onSurface;
    final now = DateTime.now();
    final overdue =
        note.dueAt != null &&
        DateUtils.dateOnly(note.dueAt!).isBefore(DateUtils.dateOnly(now));
    Widget chip(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Color? color,
      String? tooltip,
    }) {
      final tint = color ?? base.withValues(alpha: .78);
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Tooltip(
          message: tooltip ?? label,
          child: Material(
            color: (color ?? base).withValues(alpha: color == null ? .07 : .14),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: tint),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: tint,
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

    final links = extractLinks(body.text);
    final tagsLabel = note.tags.isEmpty
        ? ''
        : note.tags.length == 1
        ? ' · #${note.tags.first}'
        : ' · ${note.tags.length} tags';
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (protectedNote)
            chip(
              readOnly ? Icons.edit_outlined : Icons.lock_outline_rounded,
              readOnly ? 'Editar' : 'Editando · proteger de novo',
              () => setState(() {
                readOnly = !readOnly;
                if (readOnly) FocusManager.instance.primaryFocus?.unfocus();
              }),
              color: cs.primary,
              tooltip: 'Nota protegida contra edição',
            ),
          chip(
            Icons.folder_outlined,
            '${widget.store.folderLabel(note.folder)}$tagsLabel',
            _showOrganize,
            tooltip: 'Pasta e tags',
          ),
          if (note.reminderAt != null)
            chip(
              note.reminderRepeat == 0
                  ? Icons.notifications_active_outlined
                  : Icons.repeat_rounded,
              note.reminderRepeat == 0
                  ? DateFormat("dd/MM 'às' HH:mm").format(note.reminderAt!)
                  : '${reminderRepeatLabels[note.reminderRepeat]} · ${DateFormat('HH:mm').format(note.reminderAt!)}',
              chooseReminder,
              color: cs.primary,
              tooltip: 'Lembrete',
            ),
          if (note.dueAt != null)
            chip(
              Icons.event_outlined,
              dueCountdown(note.dueAt!, now),
              _showTaskDetails,
              color: overdue ? cs.error : null,
              tooltip: 'Prazo',
            ),
          if (note.priority > 0)
            chip(
              priorityIcon(note.priority),
              priorityLabel(note.priority),
              _showTaskDetails,
              color: note.priority == 3 ? cs.error : null,
            ),
          if (links.isNotEmpty)
            chip(
              Icons.link_rounded,
              links.length == 1 ? '1 link' : '${links.length} links',
              () => _showLinks(links),
              tooltip: 'Links da nota',
            ),
          if (resetDaily && widget.note.checklist)
            chip(
              Icons.event_repeat_outlined,
              'Desmarca todo dia',
              () => _runNoteAction('reset-daily'),
              tooltip: 'Toque para parar',
            ),
          if (tables.isNotEmpty || codeBlocks.isNotEmpty)
            if (widget.note.checklist)
              chip(
                Icons.attachment_rounded,
                'Tabelas e código (${tables.length + codeBlocks.length})',
                _showAttachments,
              ),
        ],
      ),
    );
  }

  /// Barra única de edição, presa em cima do teclado.
  Widget _bottomBar() {
    final cs = Theme.of(context).colorScheme;
    final checklist = widget.note.checklist;
    Widget button(String tip, IconData icon, VoidCallback? onTap) => Expanded(
      child: IconButton(
        tooltip: tip,
        onPressed: onTap,
        icon: Icon(icon, size: 22),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Row(
        children: [
          Expanded(
            child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(18),
        elevation: 1,
        shadowColor: Colors.black26,
        child: IconButtonTheme(
          data: IconButtonThemeData(
            style: IconButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(28, 46),
              padding: EdgeInsets.zero,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                      button(
                        'Desfazer',
                        Icons.undo_rounded,
                        undoStack.isEmpty ? null : () => _historyEdit(false),
                      ),
                      button(
                        'Refazer',
                        Icons.redo_rounded,
                        redoStack.isEmpty ? null : () => _historyEdit(true),
                      ),
                      if (!checklist) ...[
                        button(
                          'Negrito',
                          Icons.format_bold_rounded,
                          readOnly ? null : () => _tool('bold'),
                        ),
                        button(
                          'Itálico',
                          Icons.format_italic_rounded,
                          readOnly ? null : () => _tool('italic'),
                        ),
                      ],
                      button(
                        checklist ? 'Virar texto comum' : 'Virar lista de tarefas',
                        checklist ? Icons.notes_rounded : Icons.checklist_rounded,
                        readOnly ? null : () => _setChecklistMode(!checklist),
                      ),
                      button(
                        'Ditar por voz',
                        Icons.mic_none_rounded,
                        readOnly ? null : _dictate,
                      ),
                      button(
                        'Inserir',
                        Icons.add_box_outlined,
                        readOnly ? null : _showInsertMenu,
                      ),
                      if (!checklist)
                        button(
                          'Formatar texto',
                          Icons.text_format_rounded,
                          readOnly ? null : _showFormatText,
                        ),
              ],
            ),
          ),
        ),
            ),
          ),
          const SizedBox(width: 8),
          // Estilo fica num botão próprio, fora da barra de edição.
          Tooltip(
            message: 'Estilo da nota',
            child: Material(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              elevation: 1,
              shadowColor: Colors.black26,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: openStyleSheet,
                child: SizedBox(
                  width: 48,
                  height: 46,
                  child: Icon(
                    Icons.palette_outlined,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool saved = false;
  bool focusMode = false;

  // Tarefas vazias ("- [ ] " sozinho) não contam como conteúdo.
  bool get hasContent =>
      title.text.trim().isNotEmpty ||
      body.text
          .replaceAll(
            RegExp(r'^\s*(?:[-*]\s*)?\[[ xX]\]\s*$', multiLine: true),
            '',
          )
          .trim()
          .isNotEmpty ||
      tables.isNotEmpty ||
      codeBlocks.isNotEmpty;

  String get _countableText => body.text
      .replaceAll(RegExp(r'^\s*(?:[-*]\s*)?\[[ xX]\]', multiLine: true), '')
      .trim();
  int get words => _countableText.isEmpty
      ? 0
      : _countableText.split(RegExp(r'\s+')).length;
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
    autosaveTimer?.cancel();
    // Nota que ficou vazia vai para a lixeira ao sair (como no Keep).
    if (!widget.isNew &&
        !hasContent &&
        widget.note.deletedAt == null &&
        widget.store.notes.contains(widget.note)) {
      saved = true;
      _syncModel();
      widget.store.cancelReminder(widget.note);
      widget.note.deletedAt = DateTime.now();
      await widget.store.save();
      await editorPrefs?.remove('editor.draft.${widget.note.id}');
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context, true);
      _offerUndo(messenger, 'Nota vazia descartada', () {
        widget.note.deletedAt = null;
      });
      return;
    }
    saved = true;
    try {
      final persisted = await _saveDraft();
      await editorPrefs?.remove('editor.draft.${widget.note.id}');
      if (mounted) Navigator.pop(context, persisted);
    } catch (_) {
      saved = false;
      if (mounted) setState(() => saveLabel = 'Não salvou · toque para tentar de novo');
    }
  }

  Future<void> shareNote() async {
    final content =
        '${title.text.trim().isEmpty ? 'Sem título' : title.text.trim()}\n\n$fullText\n\n— Noto';
    await Share.share(content);
  }

  /// Atalhos comuns para marcar lembrete rápido.
  List<(String, DateTime)> _quickReminderTimes() {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final tomorrow = today.add(const Duration(days: 1));
    final inHour = now.add(const Duration(hours: 1));
    var monday = today.add(const Duration(days: 1));
    while (monday.weekday != DateTime.monday) {
      monday = monday.add(const Duration(days: 1));
    }
    return [
      ('Em 1 hora', DateTime(inHour.year, inHour.month, inHour.day, inHour.hour, inHour.minute)),
      if (now.hour < 19) ('Hoje às 20h', today.add(const Duration(hours: 20))),
      ('Amanhã às 9h', tomorrow.add(const Duration(hours: 9))),
      ('Segunda às 9h', monday.add(const Duration(hours: 9))),
    ];
  }

  Future<void> chooseReminder() async {
    final now = DateTime.now();
    final today = DateUtils.dateOnly(now);
    final current = widget.note.reminderAt;
    var date = current != null && !current.isBefore(today)
        ? DateUtils.dateOnly(current)
        : today;
    var time = TimeOfDay.fromDateTime(
      current ?? now.add(const Duration(hours: 1)),
    );
    var repeat = widget.note.reminderRepeat;
    final typed = TextEditingController();
    String? understood;

    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => SingleChildScrollView(
          child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            14,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lembrete',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: typed,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.edit_calendar_outlined),
                  hintText: 'Escreva: amanhã às 9, sexta 18h, em 2 horas',
                  helperText: understood,
                  helperStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onChanged: (value) => setModalState(() {
                  final parsed = parseReminderText(value, DateTime.now());
                  if (parsed == null) {
                    understood = value.trim().isEmpty
                        ? null
                        : 'Ainda não entendi. Tente "amanhã às 9".';
                    return;
                  }
                  date = DateUtils.dateOnly(parsed);
                  time = TimeOfDay.fromDateTime(parsed);
                  understood =
                      'Entendi: ${DateFormat("EEEE, dd/MM 'às' HH:mm", 'pt_BR').format(parsed)}';
                }),
                onSubmitted: (_) {
                  if (understood?.startsWith('Entendi') ?? false) {
                    Navigator.pop(sheetContext, 'save');
                  }
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final quick in _quickReminderTimes())
                    ActionChip(
                      label: Text(quick.$1),
                      onPressed: () => setModalState(() {
                        date = DateUtils.dateOnly(quick.$2);
                        time = TimeOfDay.fromDateTime(quick.$2);
                      }),
                    ),
                ],
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Dia'),
                subtitle: Text(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(date)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: today,
                    lastDate: today.add(const Duration(days: 3650)),
                  );
                  if (picked != null) setModalState(() => date = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Hora'),
                subtitle: Text(time.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: time,
                  );
                  if (picked != null) setModalState(() => time = picked);
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: repeat,
                decoration: const InputDecoration(labelText: 'Repetir'),
                items: [
                  for (var i = 0; i < reminderRepeatLabels.length; i++)
                    DropdownMenuItem(
                      value: i,
                      child: Text(reminderRepeatLabels[i]),
                    ),
                ],
                onChanged: (value) => setModalState(() => repeat = value ?? 0),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (current != null)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, 'remove'),
                      icon: const Icon(Icons.notifications_off_outlined),
                      label: const Text('Tirar lembrete'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, 'save'),
                    child: const Text('Salvar'),
                  ),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 400), typed.dispose);
    if (action == null || !mounted) return;
    if (action == 'remove') {
      setState(() => widget.store.cancelReminder(widget.note));
      await widget.store.save();
      return;
    }

    var selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (!selected.isAfter(DateTime.now())) {
      if (repeat == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Esse horário já passou. Escolha outro.'),
          ),
        );
        return;
      }
      // Repetido: começa na próxima vez que esse horário chegar.
      selected = selected.add(const Duration(days: 1));
    }

    _syncModel();
    await widget.store.scheduleReminder(widget.note, selected, repeat);
    if (!mounted) return;
    setState(() {});
    final when = DateFormat("dd/MM 'às' HH:mm").format(selected);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          repeat == 0
              ? 'Lembrete marcado para $when'
              : 'Lembrete ${reminderRepeatLabels[repeat].toLowerCase()}, a partir de $when',
        ),
      ),
    );
  }

  void openStyleSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PowerNoteStyleSheet(
        store: widget.store,
        note: widget.note,
        onChanged: _editorChanged,
      ),
    );
  }

  Future<void> _toggleVault() async {
    if (widget.note.locked) {
      widget.note.locked = false;
      _syncModel();
      await widget.store.save();
      await widget.store.refreshReminder(widget.note);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nota tirada do cofre.')),
      );
      return;
    }
    final ready = await ensureVault(context, widget.store);
    if (!ready || !mounted) return;
    widget.note.locked = true;
    final messenger = ScaffoldMessenger.of(context);
    await saveAndClose();
    await widget.store.refreshReminder(widget.note);
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Nota guardada no cofre. Para abrir, segure o logo do Noto por 2 segundos.',
        ),
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
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    _offerUndo(messenger, 'Nota arquivada', () {
      widget.note.archived = false;
    });
  }

  /// Depois de fechar a nota, a tela anterior mostra "Desfazer".
  void _offerUndo(
    ScaffoldMessengerState messenger,
    String message,
    VoidCallback restore,
  ) {
    final store = widget.store;
    final note = widget.note;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () async {
              restore();
              await store.save();
              await store.refreshReminder(note);
            },
          ),
        ),
      );
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
    widget.store.cancelReminder(widget.note);
    widget.note.deletedAt = DateTime.now();
    await widget.store.save();
    saved = true;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context, true);
    _offerUndo(messenger, 'Nota na lixeira', () {
      widget.note.deletedAt = null;
    });
  }

  Future<void> _duplicate() async {
    final persisted = await _saveDraft();
    if (!persisted || !mounted) return;
    final copy = widget.store.duplicate(widget.note);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Cópia criada'),
        action: SnackBarAction(
          label: 'Abrir',
          onPressed: () {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    EditorPage(store: widget.store, note: copy, isNew: false),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showTaskDetails() async {
    var priority = widget.note.priority;
    var due = widget.note.dueAt;
    var remindBefore = false;
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
              if (due != null &&
                  due!
                      .subtract(const Duration(days: 1))
                      .add(const Duration(hours: 9))
                      .isAfter(DateTime.now()))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lembrar um dia antes, às 9h'),
                  subtitle: widget.note.reminderAt != null
                      ? const Text('Troca o lembrete que a nota já tem')
                      : null,
                  value: remindBefore,
                  onChanged: (value) => setModalState(() => remindBefore = value),
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
      if (remindBefore && due != null) {
        final at = DateUtils.dateOnly(due!)
            .subtract(const Duration(days: 1))
            .add(const Duration(hours: 9));
        if (at.isAfter(DateTime.now())) {
          _syncModel();
          if (widget.isNew && !widget.store.notes.contains(widget.note)) {
            widget.store.notes.add(widget.note);
          }
          await widget.store.scheduleReminder(widget.note, at, 0);
          if (mounted) {
            setState(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Lembrete marcado para ${DateFormat("dd/MM 'às' HH:mm").format(at)}',
                ),
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _showAttachments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => SizedBox(
          height: MediaQuery.sizeOf(ctx).height * .75,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.viewInsetsOf(ctx).bottom + 16,
            ),
            children: [
              const ListTile(title: Text('Tabelas e código')),
              for (final code in codeBlocks)
                NotoCodeBlock(
                  key: ValueKey(code['id']),
                  data: code,
                  onChanged: _editorChanged,
                  onDelete: () {
                    update(() => codeBlocks.remove(code));
                    _editorChanged();
                  },
                ),
              for (final table in tables)
                VisualNoteTable(
                  key: ValueKey(table.id),
                  table: table,
                  onChanged: _editorChanged,
                  onDelete: () {
                    update(() => tables.remove(table));
                    _editorChanged();
                  },
                ),
            ],
          ),
        ),
      ),
    );
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
      _setChecklistMode(true);
      return;
    }
    if (kind == 'plain') {
      _setChecklistMode(false);
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
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Exportar PDF'),
              subtitle: const Text('Bom para enviar ou imprimir'),
              onTap: () => Navigator.pop(sheetContext, 'pdf'),
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
    if (choice == 'pdf') {
      await exportNotePdf(widget.note);
      return;
    }
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
    final existingTags = <String>{
      for (final item in widget.store.notes)
        if (item.deletedAt == null) ...item.tags,
    }.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
            const Text('Use / para criar subpastas. Ex.: Escola/Química.'),
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
            if (existingFolders.length > 1) ...[
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
            if (existingTags.isNotEmpty) ...[
              const SizedBox(height: 10),
              // Toque numa tag que você já usa para adicionar.
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: existingTags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (_, index) => ActionChip(
                    label: Text('#${existingTags[index]}'),
                    onPressed: () {
                      final current = tagsController.text
                          .split(RegExp(r'[,#\n]'))
                          .map((item) => item.trim())
                          .where((item) => item.isNotEmpty)
                          .toList();
                      if (current.any(
                        (item) =>
                            item.toLowerCase() ==
                            existingTags[index].toLowerCase(),
                      )) {
                        return;
                      }
                      tagsController.text = [
                        ...current,
                        existingTags[index],
                      ].join(', ');
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Salvar'),
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
          final backlinks = backlinksFor(
            widget.note,
            widget.store.notes
                .where((item) => !item.locked || widget.note.locked)
                .toList(),
          );
          final candidates =
              widget.store.notes
                  .where(
                    (item) =>
                        item.deletedAt == null &&
                        !item.locked &&
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
                            const Text('Ligue notas usando [[Nome da nota]].'),
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
                                  tableEpoch++;
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
                    'LINKS NESTA NOTA',
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
                        'Toque em Conectar ou escreva [[Nome da nota]].',
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
                                    builder: (_) => EditorPage(
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
                    'NOTAS QUE APONTAM PARA ESTA',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (backlinks.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.call_received_rounded),
                      title: Text('Nenhuma nota aponta para esta ainda'),
                    )
                  else
                    ...backlinks.map(
                      (source) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.call_received_rounded),
                        title: Text(
                          displayTitle(source),
                        ),
                        subtitle: Text(source.folder),
                        onTap: () async {
                          await _saveDraft();
                          if (!sheetContext.mounted || !mounted) return;
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditorPage(
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
                          Text(
                            history.length == 1
                                ? '1 versão guardada (até 20)'
                                : '${history.length} versões guardadas (até 20)',
                          ),
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
                            'Nenhuma versão anterior ainda. Elas aparecem conforme você edita a nota.',
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
                              '${DateFormat('dd/MM/yyyy HH:mm').format(revision.savedAt)}\n${readablePreview(revision.body).isEmpty ? 'Nota vazia' : readablePreview(revision.body).replaceAll('\n', ' ')}',
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
    if (_countsAsVault) widget.store.vaultScreenClosed();
    WidgetsBinding.instance.removeObserver(this);
    autosaveTimer?.cancel();
    title.removeListener(_editorChanged);
    body.removeListener(_editorChanged);
    body.removeListener(_watchSlash);
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
    final cs = Theme.of(context).colorScheme;
    final failed = saveLabel.startsWith('Não salvou');
    final saving = saveLabel == 'Salvando…';

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
                  tooltip: 'Voltar',
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: saveAndClose,
                ),
                titleSpacing: 0,
                foregroundColor: selectedWallpaper != null
                    ? Colors.white
                    : null,
                title: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: failed ? _autosave : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          failed
                              ? Icons.error_outline_rounded
                              : saving
                              ? Icons.sync_rounded
                              : Icons.cloud_done_outlined,
                          size: 17,
                          color: failed ? cs.error : null,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            saveLabel,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: failed ? cs.error : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'Lembrete',
                    icon: Icon(
                      widget.note.reminderAt == null
                          ? Icons.notifications_none_rounded
                          : Icons.notifications_active_rounded,
                    ),
                    onPressed: chooseReminder,
                  ),
                  IconButton(
                    tooltip: 'Mais opções',
                    icon: const Icon(Icons.more_vert_rounded),
                    onPressed: _showNoteMenu,
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
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        focusMode ? 24 : 20,
                        focusMode ? 22 : 4,
                        focusMode ? 24 : 20,
                        0,
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.note.emoji.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 3,
                                    right: 8,
                                  ),
                                  child: Text(
                                    widget.note.emoji,
                                    style: const TextStyle(fontSize: 25),
                                  ),
                                ),
                              Expanded(
                                child: TextField(
                                  controller: title,
                                  readOnly: readOnly,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) => bodyFocus.requestFocus(),
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                    fontSize: focusMode ? 32 : 28,
                                    height: 1.18,
                                    fontWeight: FontWeight.w900,
                                    color: fg,
                                    letterSpacing: -.65,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (!focusMode) ...[
                            const SizedBox(height: 8),
                            _metaChips(fg),
                          ],
                          SizedBox(height: focusMode ? 18 : 12),
                          Expanded(
                            child: widget.note.checklist
                                ? AbsorbPointer(
                                    absorbing: readOnly,
                                    child: MixedContentEditor(
                                    key: ValueKey('mixed-$tableEpoch-$hideDone'),
                                    hideDone: hideDone,
                                    onShowDone: () => _setHideDone(false),
                                    onAllDone: _listFinished,
                                    controller: body,
                                    family: bodyFamily,
                                    fontSize: widget.store.fontSize,
                                    textColor: fg,
                                    onChanged: () => setState(() {}),
                                  ),
                                  )
                                : ListView(
                                    controller: editorScroll,
                                    padding: const EdgeInsets.only(bottom: 24),
                                    children: [
                                      TextField(
                                        controller: body,
                                        focusNode: bodyFocus,
                                        readOnly: readOnly,
                                        inputFormatters: [
                                          ListContinuationFormatter(),
                                        ],
                                        minLines: 8,
                                        maxLines: null,
                                        textAlign: alignment,
                                        keyboardType: TextInputType.multiline,
                                        textCapitalization:
                                            TextCapitalization.sentences,
                                        decoration: InputDecoration(
                                          hintText: 'Escreva aqui...',
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
                                          height: widget.store.editorLineHeight,
                                          color: fg,
                                        ),
                                      ),
                                      for (final code in codeBlocks)
                                        NotoCodeBlock(
                                          key: ValueKey(
                                            '${code['id']}-$tableEpoch',
                                          ),
                                          data: code,
                                          onChanged: _editorChanged,
                                          onDelete: () {
                                            codeBlocks.remove(code);
                                            _editorChanged();
                                          },
                                        ),
                                      for (final table in tables)
                                        VisualNoteTable(
                                          key: ValueKey(
                                            '${table.id}-$tableEpoch',
                                          ),
                                          table: table,
                                          fontFamily: bodyFamily,
                                          fontSize: widget.store.fontSize,
                                          onChanged: _editorChanged,
                                          onDelete: () {
                                            tables.remove(table);
                                            _editorChanged();
                                          },
                                        ),
                                      if (selectedWords > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            '$selectedWords ${selectedWords == 1 ? 'palavra selecionada' : 'palavras selecionadas'}',
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              color: fg?.withValues(alpha: .65),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!focusMode) _bottomBar(),
                ],
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

class _MenuAction {
  const _MenuAction(this.id, this.icon, this.label, {this.danger = false});
  final String id;
  final IconData icon;
  final String label;
  final bool danger;
}

/// Grade de 4 colunas com ícone e nome curto, para menus fáceis de bater o olho.
class _MenuGrid extends StatelessWidget {
  const _MenuGrid({required this.items, required this.onPick});

  final List<_MenuAction> items;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 520 ? 6 : 4;
        final width = constraints.maxWidth / columns;
        return Wrap(
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onPick(item.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    child: Column(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: item.danger
                                ? cs.errorContainer
                                : cs.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            item.icon,
                            size: 22,
                            color: item.danger ? cs.onErrorContainer : cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: item.danger ? cs.error : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
