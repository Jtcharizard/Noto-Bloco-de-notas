import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_editor.dart' as legacy;
import 'noto_features.dart';
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
  int get characters => body.text.characters.length;
  int get readingMinutes => words == 0 ? 0 : ((words + 199) ~/ 200);

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
      useSafeArea: true,
      builder: (_) => PowerNoteStyleSheet(
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
              Text('Prioridade e prazo', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
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
                onChanged: (value) => setModalState(() => priority = value ?? 0),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Prazo'),
                subtitle: Text(due == null ? 'Sem prazo' : DateFormat('dd/MM/yyyy').format(due!)),
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
    final selection = body.selection;
    final start = selection.isValid ? selection.start : body.text.length;
    final end = selection.isValid ? selection.end : body.text.length;
    final selected = start >= 0 && end >= start ? body.text.substring(start, end) : '';
    final block = '```\n${selected.isEmpty ? '// código' : selected}\n```';
    final newText = body.text.replaceRange(start, end, block);
    body.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + block.length),
    );
    setState(() {});
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Salvar')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await widget.store.addTemplateFromNote(widget.note, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modelo salvo')));
    }
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
                                if (!extractWikiLinks(body.text).any(
                                  (item) => item.toLowerCase() == target.title.trim().toLowerCase(),
                                )) {
                                  final separator = body.text.trim().isEmpty ? '' : '\n\n';
                                  body.text = '${body.text}$separator$marker';
                                  body.selection = TextSelection.collapsed(offset: body.text.length);
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
                  Text('SAINDO DESTA NOTA', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
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
                      final target = noteByTitle(widget.store.notes, linkTitle);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(target == null ? Icons.link_off_rounded : Icons.arrow_outward_rounded),
                        title: Text(linkTitle),
                        subtitle: Text(target == null ? 'Nota não encontrada' : target.folder),
                        onTap: target == null
                            ? null
                            : () async {
                                await _saveDraft();
                                if (!sheetContext.mounted || !mounted) return;
                                Navigator.pop(sheetContext);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => EditorPageV2(store: widget.store, note: target, isNew: false)),
                                );
                              },
                      );
                    }),
                  const Divider(height: 28),
                  Text('APONTANDO PRA ESTA NOTA', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900)),
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
                        title: Text(source.title.trim().isEmpty ? 'Sem título' : source.title),
                        subtitle: Text(source.folder),
                        onTap: () async {
                          await _saveDraft();
                          if (!sheetContext.mounted || !mounted) return;
                          Navigator.pop(sheetContext);
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => EditorPageV2(store: widget.store, note: source, isNew: false)),
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
                          Text('Histórico', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
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
                          child: Text('Ainda não tem versão anterior. Ela aparece depois que a nota for editada e salva.', textAlign: TextAlign.center),
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
                            title: Text(revision.title.trim().isEmpty ? 'Sem título' : revision.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
                                await widget.store.restoreRevision(widget.note, revision);
                                title.text = widget.note.title;
                                body.text = widget.note.body;
                                if (sheetContext.mounted) Navigator.pop(sheetContext);
                                if (mounted) {
                                  setState(() {});
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Versão restaurada')));
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
    final noteColor = noteColorIndex == 0 ? null : NotoAppearance.noteColors[noteColorIndex];
    final titleFamily = NotoAppearance.familyAt(widget.note.titleFont ?? widget.note.font);
    final bodyFamily = NotoAppearance.familyAt(widget.note.bodyFont ?? widget.note.font);
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
                leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: saveAndClose),
                foregroundColor: selectedWallpaper != null ? Colors.white : null,
                actions: [
                  IconButton(
                    tooltip: widget.note.favorite ? 'Remover dos favoritos' : 'Favoritar',
                    icon: Icon(widget.note.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
                    onPressed: () {
                      setState(() => widget.note.favorite = !widget.note.favorite);
                      widget.store.save();
                    },
                  ),
                  IconButton(
                    tooltip: 'Lembrete',
                    icon: Icon(widget.note.reminderAt == null ? Icons.notifications_none_rounded : Icons.notifications_active_rounded),
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
                          MaterialPageRoute(builder: (_) => MarkdownPreviewPage(title: title.text, markdown: body.text)),
                        );
                      }
                      if (value == 'code') _insertCodeBlock();
                      if (value == 'export') await _showExport();
                      if (value == 'template') await _saveAsTemplate();
                      if (value == 'share') await shareNote();
                      if (value == 'duplicate') await _duplicate();
                      if (value == 'archive') await _archiveAndClose();
                      if (value == 'delete') await _deleteAndClose();
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'organize', child: ListTile(leading: Icon(Icons.drive_file_move_outline), title: Text('Organizar'))),
                      PopupMenuItem(value: 'task', child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Prioridade e prazo'))),
                      PopupMenuItem(value: 'connections', child: ListTile(leading: Icon(Icons.hub_outlined), title: Text('Conexões'))),
                      PopupMenuItem(value: 'preview', child: ListTile(leading: Icon(Icons.visibility_outlined), title: Text('Prévia Markdown'))),
                      PopupMenuItem(value: 'code', child: ListTile(leading: Icon(Icons.code_rounded), title: Text('Inserir bloco de código'))),
                      PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_upload_outlined), title: Text('Exportar'))),
                      PopupMenuItem(value: 'template', child: ListTile(leading: Icon(Icons.bookmark_add_outlined), title: Text('Salvar como modelo'))),
                      PopupMenuItem(value: 'history', child: ListTile(leading: Icon(Icons.history_rounded), title: Text('Histórico'))),
                      PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share_rounded), title: Text('Compartilhar'))),
                      PopupMenuItem(value: 'duplicate', child: ListTile(leading: Icon(Icons.copy_outlined), title: Text('Duplicar'))),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'archive', child: ListTile(leading: Icon(Icons.archive_outlined), title: Text('Arquivar'))),
                      PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Lixeira'))),
                    ],
                  ),
                ],
              ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (selectedWallpaper != null)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: widget.note.wallpaperBlur, sigmaY: widget.note.wallpaperBlur),
                child: Image(image: selectedWallpaper, fit: BoxFit.cover),
              ),
            if (selectedWallpaper != null)
              ColoredBox(color: Colors.black.withValues(alpha: widget.note.wallpaperDarkness)),
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
                            child: Text(widget.note.emoji, style: const TextStyle(fontSize: 25)),
                          ),
                        ],
                        Expanded(
                          child: TextField(
                            controller: title,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Título',
                              hintStyle: TextStyle(color: fg?.withValues(alpha: .55)),
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
                    if (!focusMode && (widget.note.reminderAt != null || widget.note.dueAt != null || widget.note.priority > 0))
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (widget.note.reminderAt != null)
                              Chip(
                                avatar: const Icon(Icons.notifications_active_outlined, size: 16),
                                label: Text(DateFormat("dd/MM 'às' HH:mm").format(widget.note.reminderAt!)),
                                onDeleted: () async {
                                  await notifications.cancel(widget.note.id.hashCode & 0x7fffffff);
                                  setState(() => widget.note.reminderAt = null);
                                  widget.store.save();
                                },
                              ),
                            if (widget.note.priority > 0)
                              Chip(
                                avatar: Icon(priorityIcon(widget.note.priority), size: 16),
                                label: Text(priorityLabel(widget.note.priority)),
                              ),
                            if (widget.note.dueAt != null)
                              Chip(
                                avatar: const Icon(Icons.event_outlined, size: 16),
                                label: Text(DateFormat('dd/MM').format(widget.note.dueAt!)),
                              ),
                          ],
                        ),
                      ),
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
                          : TextField(
                              controller: body,
                              expands: true,
                              maxLines: null,
                              textAlignVertical: TextAlignVertical.top,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Começa a escrever...',
                                hintStyle: TextStyle(color: fg?.withValues(alpha: .48)),
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                              onChanged: (_) => setState(() {}),
                              style: TextStyle(
                                fontFamily: bodyFamily,
                                fontSize: focusMode ? widget.store.fontSize + 1 : widget.store.fontSize,
                                height: focusMode ? 1.72 : 1.6,
                                color: fg,
                              ),
                            ),
                    ),
                    if (!focusMode)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$words palavras · $characters caracteres · ${readingMinutes == 0 ? '<1' : readingMinutes} min',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10.5, color: fg?.withValues(alpha: .65)),
                            ),
                          ),
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
