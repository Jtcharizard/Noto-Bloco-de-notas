import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/timezone.dart' as tz;

import 'noto_models.dart';
import 'noto_settings.dart';
import 'noto_store.dart';
import 'noto_theme.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.store, required this.note, required this.isNew});
  final AppStore store;
  final Note note;
  final bool isNew;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController title = TextEditingController(text: widget.note.title);
  late final TextEditingController body = TextEditingController(text: widget.note.body);
  bool saved = false;

  bool get hasContent => title.text.trim().isNotEmpty || body.text.trim().isNotEmpty;
  int get words => body.text.trim().isEmpty ? 0 : body.text.trim().split(RegExp(r'\s+')).length;

  Color? get editorTextColor {
    final wallpaper = noteWallpaper(widget.note);
    if (widget.note.textColor == 0) return wallpaper == null ? null : Colors.white;
    return NotoAppearance.textColors[NotoAppearance.safeTextColorIndex(widget.note.textColor)];
  }

  Future<void> saveAndClose() async {
    if (saved) return;
    saved = true;
    widget.note.title = title.text.trim();
    widget.note.body = body.text;
    widget.note.updatedAt = DateTime.now();
    if (widget.isNew && hasContent) widget.store.notes.add(widget.note);
    if (hasContent) await widget.store.save();
    if (mounted) Navigator.pop(context, hasContent);
  }

  Future<void> shareNote() async {
    final content = '${title.text.trim().isEmpty ? 'Sem título' : title.text.trim()}\n\n${body.text}\n\n— Noto';
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
      initialTime: TimeOfDay.fromDateTime(widget.note.reminderAt ?? now.add(const Duration(hours: 1))),
    );
    if (time == null) return;
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
      body.text.trim().isEmpty ? 'Hora de abrir tua nota.' : body.text.trim().split('\n').first,
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
      builder: (_) => NoteStyleSheet(store: widget.store, note: widget.note, onChanged: () => setState(() {})),
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
    final family = NotoAppearance.familyAt(widget.note.font);
    final fg = editorTextColor;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) saveAndClose();
      },
      child: Scaffold(
        backgroundColor: selectedWallpaper != null ? Colors.black : noteColor,
        appBar: AppBar(
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
            IconButton(tooltip: 'Compartilhar', icon: const Icon(Icons.ios_share_rounded), onPressed: shareNote),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'reminder') await chooseReminder();
                if (value == 'style') openStyleSheet();
                if (value == 'archive') {
                  widget.note.archived = true;
                  await saveAndClose();
                }
                if (value == 'delete') {
                  widget.note.deletedAt = DateTime.now();
                  await saveAndClose();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'style', child: ListTile(leading: Icon(Icons.palette_outlined), title: Text('Aparência'))),
                PopupMenuItem(value: 'reminder', child: ListTile(leading: Icon(Icons.notifications_none_rounded), title: Text('Lembrete'))),
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
            if (selectedWallpaper != null) ColoredBox(color: Colors.black.withValues(alpha: widget.note.wallpaperDarkness)),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  children: [
                    TextField(
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
                      style: TextStyle(fontFamily: family, fontSize: 29, height: 1.18, fontWeight: FontWeight.w900, color: fg),
                    ),
                    if (widget.note.reminderAt != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Chip(
                            avatar: const Icon(Icons.notifications_active_outlined, size: 17),
                            label: Text(DateFormat("dd/MM 'às' HH:mm").format(widget.note.reminderAt!)),
                            onDeleted: () async {
                              await notifications.cancel(widget.note.id.hashCode & 0x7fffffff);
                              setState(() => widget.note.reminderAt = null);
                              widget.store.save();
                            },
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: widget.note.checklist
                          ? ChecklistEditor(
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
                              style: TextStyle(fontFamily: family, fontSize: widget.store.fontSize, height: 1.6, color: fg),
                            ),
                    ),
                    Row(
                      children: [
                        Text('$words palavras', style: TextStyle(fontSize: 11, color: fg?.withValues(alpha: .65))),
                        const Spacer(),
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
          ],
        ),
      ),
    );
  }
}

class NoteStyleSheet extends StatefulWidget {
  const NoteStyleSheet({super.key, required this.store, required this.note, required this.onChanged});
  final AppStore store;
  final Note note;
  final VoidCallback onChanged;

  @override
  State<NoteStyleSheet> createState() => _NoteStyleSheetState();
}

class _NoteStyleSheetState extends State<NoteStyleSheet> {
  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .74,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
          children: [
            Text('Estilo da nota', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            const Text('COR DA NOTA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(NotoAppearance.noteColors.length, (index) {
                final color = index == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : NotoAppearance.noteColors[index];
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    setState(() => note.color = index);
                    widget.store.save();
                    widget.onChanged();
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: note.color == index ? const Icon(Icons.check_rounded) : (index == 0 ? const Icon(Icons.auto_awesome_rounded, size: 18) : null),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            const Text('COR DO TEXTO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(NotoAppearance.textColors.length, (index) {
                final color = index == 0 ? Theme.of(context).colorScheme.surfaceContainerHighest : NotoAppearance.textColors[index];
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    setState(() => note.textColor = index);
                    widget.store.save();
                    widget.onChanged();
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: color,
                    child: note.textColor == index ? Icon(Icons.check_rounded, color: index == 2 ? Colors.white : null) : (index == 0 ? const Icon(Icons.auto_awesome_rounded, size: 18) : null),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.font_download_outlined),
              title: const Text('Fonte da nota', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(NotoAppearance.fonts[NotoAppearance.safeFontIndex(note.font)].name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final selected = await showModalBottomSheet<int>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FontPickerSheet(selected: NotoAppearance.safeFontIndex(note.font)),
                );
                if (selected != null) {
                  setState(() => note.font = selected);
                  widget.store.save();
                  widget.onChanged();
                }
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Checklist', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Transforma a nota em uma lista marcável'),
              value: note.checklist,
              onChanged: (value) {
                setState(() => note.checklist = value);
                widget.store.save();
                widget.onChanged();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wallpaper_outlined),
              title: const Text('Imagem de fundo', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: const Text('Escolhe um wallpaper ou uma foto tua'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => WallpaperSheet(store: widget.store, note: note),
              ).then((_) => widget.onChanged()),
            ),
            if (noteWallpaper(note) != null) ...[
              Row(children: [
                const SizedBox(width: 4),
                const Icon(Icons.brightness_6_outlined, size: 20),
                const SizedBox(width: 8),
                const SizedBox(width: 80, child: Text('Escurecer')),
                Expanded(
                  child: Slider(
                    value: note.wallpaperDarkness,
                    min: 0,
                    max: .8,
                    onChanged: (value) {
                      setState(() => note.wallpaperDarkness = value);
                      widget.store.save();
                      widget.onChanged();
                    },
                  ),
                ),
              ]),
              Row(children: [
                const SizedBox(width: 4),
                const Icon(Icons.blur_on_outlined, size: 20),
                const SizedBox(width: 8),
                const SizedBox(width: 80, child: Text('Desfoque')),
                Expanded(
                  child: Slider(
                    value: note.wallpaperBlur,
                    min: 0,
                    max: 16,
                    divisions: 16,
                    onChanged: (value) {
                      setState(() => note.wallpaperBlur = value);
                      widget.store.save();
                      widget.onChanged();
                    },
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem {
  _ChecklistItem(this.text, this.checked);
  String text;
  bool checked;
}

class ChecklistEditor extends StatefulWidget {
  const ChecklistEditor({
    super.key,
    required this.controller,
    required this.family,
    required this.fontSize,
    required this.textColor,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String? family;
  final double fontSize;
  final Color? textColor;
  final VoidCallback onChanged;

  @override
  State<ChecklistEditor> createState() => _ChecklistEditorState();
}

class _ChecklistEditorState extends State<ChecklistEditor> {
  final input = TextEditingController();
  late final List<_ChecklistItem> items;

  @override
  void initState() {
    super.initState();
    items = widget.controller.text.split('\n').where((line) => line.trim().isNotEmpty).map((line) {
      final value = line.trim();
      if (value.startsWith('[x]')) return _ChecklistItem(value.substring(3).trim(), true);
      if (value.startsWith('[ ]')) return _ChecklistItem(value.substring(3).trim(), false);
      return _ChecklistItem(value, false);
    }).toList();
  }

  void sync() {
    widget.controller.text = items.map((item) => '${item.checked ? '[x]' : '[ ]'} ${item.text}').join('\n');
    widget.onChanged();
  }

  void add() {
    final value = input.text.trim();
    if (value.isEmpty) return;
    setState(() {
      items.add(_ChecklistItem(value, false));
      input.clear();
      sync();
    });
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: ReorderableListView.builder(
              itemCount: items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = items.removeAt(oldIndex);
                  items.insert(newIndex, item);
                  sync();
                });
              },
              itemBuilder: (_, index) {
                final item = items[index];
                return CheckboxListTile(
                  key: ValueKey(item),
                  contentPadding: EdgeInsets.zero,
                  value: item.checked,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    item.text,
                    style: TextStyle(
                      fontFamily: widget.family,
                      fontSize: widget.fontSize,
                      color: widget.textColor,
                      decoration: item.checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  secondary: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 19),
                    onPressed: () {
                      setState(() {
                        items.removeAt(index);
                        sync();
                      });
                    },
                  ),
                  onChanged: (value) {
                    setState(() {
                      item.checked = value ?? false;
                      sync();
                    });
                  },
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: input,
                    onSubmitted: (_) => add(),
                    decoration: const InputDecoration(hintText: 'Novo item...', filled: false, border: InputBorder.none),
                  ),
                ),
                IconButton.filled(onPressed: add, icon: const Icon(Icons.add_rounded)),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ],
      );
}
