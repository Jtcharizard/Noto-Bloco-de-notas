import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_editor.dart' as legacy;
import 'noto_features.dart';
import 'noto_models.dart';
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

class _EditorPageV2State extends State<EditorPageV2> {
  late final TextEditingController title =
      TextEditingController(text: widget.note.title);
  late final TextEditingController body =
      TextEditingController(text: widget.note.body);

  bool saved = false;
  bool focusMode = false;

  bool get hasContent =>
      title.text.trim().isNotEmpty || body.text.trim().isNotEmpty;

  int get words => body.text.trim().isEmpty
      ? 0
      : body.text.trim().split(RegExp(r'\s+')).length;

  Color? get editorTextColor {
    final wallpaper = noteWallpaper(widget.note);
    if (widget.note.textColor == 0) {
      return wallpaper == null ? null : Colors.white;
    }
    return NotoAppearance.textColors[
      NotoAppearance.safeTextColorIndex(widget.note.textColor)
    ];
  }

  void _syncModel() {
    widget.note.title = title.text.trim();
    widget.note.body = body.text;
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
    saved = true;
    final persisted = await _saveDraft();
    if (mounted) Navigator.pop(context, persisted);
  }

  Future<void> shareNote() async {
    final content =
        '${title.text.trim().isEmpty ? 'Sem título' : title.text.trim()}\n\n${body.text}\n\n— Noto';
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
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      builder: (_) => legacy.NoteStyleSheet(
        store: widget.store,
        note: widget.note,
        onChanged: () => setState(() {}),
      ),
    );
  }

  Future<void> _archiveAndClose() async {
    _syncModel();
    if (widget.isNew && !widget.store.notes.contains(widget.note) && hasContent) {
      widget.store.notes.add(widget.note);
    }
    widget.note.archived = true;
    await widget.store.save();
    saved = true;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteAndClose() async {
    _syncModel();
    if (widget.isNew && !widget.store.notes.contains(widget.note) && hasContent) {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cópia criada')),
    );
  }

  Future<void> _showOrganize() async {
    final folderController = TextEditingController(text: widget.note.folder);
    final tagsController = TextEditingController(text: widget.note.tags.join(', '));
    final existingFolders = <String>{
      for (final item in widget.store.notes)
        if (item.deletedAt == null && item.folder.trim().isNotEmpty)
          item.folder.trim(),
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
                'Organizar',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
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
          final candidates = widget.store.notes
              .where((item) =>
                  item.deletedAt == null &&
                  item.id != widget.note.id &&
                  item.title.trim().isNotEmpty)
              .toList()
            ..sort((a, b) =>
                a.title.toLowerCase().compareTo(b.title.toLowerCase()));

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
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
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
                                final target =
                                    await showModalBottomSheet<Note>(
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
                                  final separator =
                                      body.text.trim().isEmpty ? '' : '\n\n';
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
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  if (outbound.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.link_off_rounded),
                      title: Text('Nenhum link ainda'),
                      subtitle: Text('Usa Conectar ou escreve [[Nome da nota]].'),
                    )
                  else
                    ...outbound.map((linkTitle) {
                      final target =
                          noteByTitle(widget.store.notes, linkTitle);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(target == null
                            ? Icons.link_off_rounded
                            : Icons.arrow_outward_rounded),
                        title: Text(linkTitle),
                        subtitle: Text(target == null
                            ? 'Nota não encontrada'
                            : target.folder),
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
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
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
                        title: Text(source.title.trim().isEmpty
                            ? 'Sem título'
                            : source.title),
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
                          await widget.store.clearHistory(widget.note);
                          if (sheetContext.mounted) {
                            Navigator.pop(sheetContext);
                          }
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
                                await widget.store
                                    .restoreRevision(widget.note, revision);
                                title.text = widget.note.title;
                                body.text = widget.note.body;
                                if (sheetContext.mounted) {
                                  Navigator.pop(sheetContext);
                                }
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
    title.dispose();
    body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedWallpaper = noteWallpaper(widget.note);
    final noteColorIndex = NotoAppearance.safeNoteColorIndex(widget.note.color);
    final noteColor = noteColorIndex == 0
        ? null
        : NotoAppearance.noteColors[noteColorIndex];
    final family = NotoAppearance.familyAt(widget.note.font);
    final fg = editorTextColor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) saveAndClose();
      },
      child: Scaffold(
        backgroundColor:
            selectedWallpaper != null ? Colors.black : noteColor,
        appBar: focusMode
            ? null
            : AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: saveAndClose,
                ),
                foregroundColor:
                    selectedWallpaper != null ? Colors.white : null,
                actions: [
                  IconButton(
                    tooltip: widget.note.favorite
                        ? 'Remover dos favoritos'
                        : 'Favoritar',
                    icon: Icon(widget.note.favorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded),
                    onPressed: () {
                      setState(() =>
                          widget.note.favorite = !widget.note.favorite);
                      widget.store.save();
                    },
                  ),
                  IconButton(
                    tooltip: 'Lembrete',
                    icon: Icon(widget.note.reminderAt == null
                        ? Icons.notifications_none_rounded
                        : Icons.notifications_active_rounded),
                    onPressed: chooseReminder,
                  ),
                  IconButton(
                    tooltip: 'Compartilhar',
                    icon: const Icon(Icons.ios_share_rounded),
                    onPressed: shareNote,
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'organize') await _showOrganize();
                      if (value == 'connections') await _showConnections();
                      if (value == 'history') await _showHistory();
                      if (value == 'duplicate') await _duplicate();
                      if (value == 'archive') await _archiveAndClose();
                      if (value == 'delete') await _deleteAndClose();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'organize',
                        child: ListTile(
                          leading: Icon(Icons.drive_file_move_outline),
                          title: Text('Organizar'),
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
                        value: 'history',
                        child: ListTile(
                          leading: Icon(Icons.history_rounded),
                          title: Text('Histórico'),
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
                    TextField(
                      controller: title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Título',
                        hintStyle:
                            TextStyle(color: fg?.withValues(alpha: .55)),
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: TextStyle(
                        fontFamily: family,
                        fontSize: focusMode ? 32 : 29,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        color: fg,
                        letterSpacing: -.65,
                      ),
                    ),
                    if (!focusMode && widget.note.reminderAt != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            avatar: const Icon(
                              Icons.notifications_active_outlined,
                              size: 17,
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
                        ),
                      ),
                    SizedBox(height: focusMode ? 18 : 12),
                    Expanded(
                      child: widget.note.checklist
                          ? legacy.ChecklistEditor(
                              controller: body,
                              family: family,
                              fontSize: widget.store.fontSize,
                              textColor: fg,
                              onChanged: () => setState(() {}),
                            )
                          : TextField(
                              controller: body,
                              expands: true,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
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
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontFamily: family,
                                fontSize: focusMode
                                    ? widget.store.fontSize + 1
                                    : widget.store.fontSize,
                                height: focusMode ? 1.72 : 1.6,
                                color: fg,
                              ),
                            ),
                    ),
                    if (!focusMode)
                      Row(
                        children: [
                          Text(
                            '$words palavras',
                            style: TextStyle(
                              fontSize: 11,
                              color: fg?.withValues(alpha: .65),
                            ),
                          ),
                          const Spacer(),
                          IconButton.filledTonal(
                            tooltip: 'Modo foco',
                            onPressed: () => setState(() => focusMode = true),
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
                    onPressed: () => setState(() => focusMode = false),
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
