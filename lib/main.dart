import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:home_widget/home_widget.dart';

final notifications = FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
  await notifications.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  runApp(const NotesApp());
}

class Note {
  Note({required this.id, required this.title, required this.body, required this.updatedAt, this.color = 0, this.pinned = false, this.wallpaper = 0, this.customWallpaper, this.textColor = 0, this.font = 0, this.favorite = false, this.folder = 'Geral', this.tags = const [], this.checklist = false, this.deletedAt, this.reminderAt});
  final String id;
  String title;
  String body;
  DateTime updatedAt;
  int color;
  bool pinned;
  int wallpaper;
  String? customWallpaper;
  int textColor;
  int font;
  bool favorite;
  String folder;
  List<String> tags;
  bool checklist;
  DateTime? deletedAt;
  DateTime? reminderAt;

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'updatedAt': updatedAt.toIso8601String(), 'color': color, 'pinned': pinned, 'wallpaper': wallpaper, 'customWallpaper': customWallpaper, 'textColor': textColor, 'font': font, 'favorite': favorite, 'folder': folder, 'tags': tags, 'checklist': checklist, 'deletedAt': deletedAt?.toIso8601String(), 'reminderAt': reminderAt?.toIso8601String()};
  factory Note.fromJson(Map<String, dynamic> j) => Note(id: j['id'], title: j['title'] ?? '', body: j['body'] ?? '', updatedAt: DateTime.parse(j['updatedAt']), color: j['color'] ?? 0, pinned: j['pinned'] ?? false, wallpaper: j['wallpaper'] ?? 0, customWallpaper: j['customWallpaper'], textColor: j['textColor'] ?? 0, font: j['font'] ?? 0, favorite: j['favorite'] ?? false, folder: j['folder'] ?? 'Geral', tags: List<String>.from(j['tags'] ?? const []), checklist: j['checklist'] ?? false, deletedAt: j['deletedAt'] == null ? null : DateTime.parse(j['deletedAt']), reminderAt: j['reminderAt'] == null ? null : DateTime.parse(j['reminderAt']));
}

ImageProvider? wallpaperFor(Note note) {
  final custom = note.customWallpaper;
  if (custom != null && File(custom).existsSync()) return FileImage(File(custom));
  if (note.wallpaper > 0) return AssetImage(WallpaperLayer.paths[note.wallpaper]);
  return null;
}

class AppStore extends ChangeNotifier {
  final List<Note> notes = [];
  ThemeMode mode = ThemeMode.system;
  int accent = 0;
  int font = 0;
  double fontSize = 17;
  bool grid = true;
  int wallpaper = 0;
  String? customWallpaper;
  bool loaded = false;

  static const accents = [Color(0xFF7557D3), Color(0xFF25756D), Color(0xFFC05343), Color(0xFF3367B2), Color(0xFFB46A18)];
  static const fonts = [
    'Moderna', 'Livro', 'Poppins', 'Máquina', 'Montserrat', 'Playfair',
    'Bebas Neue', 'Lobster', 'Pacifico', 'Caveat', 'Dancing Script',
    'Oswald', 'Raleway', 'Lora', 'Nunito', 'Quicksand', 'Rubik',
    'Cinzel', 'Bangers', 'Comfortaa',
  ];
  static const fontFamilies = [
    null, 'serif', 'Poppins', 'monospace', 'Montserrat', 'Playfair',
    'BebasNeue', 'Lobster', 'Pacifico', 'Caveat', 'DancingScript',
    'Oswald', 'Raleway', 'Lora', 'Nunito', 'Quicksand', 'Rubik',
    'Cinzel', 'Bangers', 'Comfortaa',
  ];

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('notes');
    if (raw != null) notes.addAll((jsonDecode(raw) as List).map((e) => Note.fromJson(e)));
    mode = ThemeMode.values[p.getInt('mode') ?? 0];
    accent = p.getInt('accent') ?? 0;
    font = p.getInt('font') ?? 0;
    fontSize = p.getDouble('fontSize') ?? 17;
    grid = p.getBool('grid') ?? true;
    wallpaper = p.getInt('wallpaper') ?? 0;
    customWallpaper = p.getString('customWallpaper');
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await Future.wait([
      p.setString('notes', jsonEncode(notes.map((e) => e.toJson()).toList())),
      p.setInt('mode', mode.index), p.setInt('accent', accent), p.setInt('font', font),
      p.setDouble('fontSize', fontSize), p.setBool('grid', grid),
      p.setInt('wallpaper', wallpaper),
      if (customWallpaper == null) p.remove('customWallpaper') else p.setString('customWallpaper', customWallpaper!),
    ]);
    final active = notes.where((n) => n.deletedAt == null).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    await HomeWidget.saveWidgetData<String>('note_title', active.isEmpty ? 'Noto' : (active.first.title.isEmpty ? 'Sem título' : active.first.title));
    await HomeWidget.saveWidgetData<String>('note_body', active.isEmpty ? 'Toca para criar tua primeira nota' : active.first.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'));
    await HomeWidget.updateWidget(name: 'NotoWidgetProvider', androidName: 'NotoWidgetProvider');
    notifyListeners();
  }

  void delete(Note n) { n.deletedAt = DateTime.now(); save(); }
  void restore(Note n) { n.deletedAt = null; save(); }
  void deleteForever(Note n) { notes.remove(n); save(); }
  void togglePin(Note n) { n.pinned = !n.pinned; n.updatedAt = DateTime.now(); save(); }
}

class NotesApp extends StatefulWidget {
  const NotesApp({super.key});
  @override State<NotesApp> createState() => _NotesAppState();
}

class _NotesAppState extends State<NotesApp> {
  final store = AppStore();
  @override void initState() { super.initState(); store.load(); }
  TextTheme themedText(ThemeData base) {
    return base.textTheme.apply(fontFamily: AppStore.fontFamilies[store.font]);
  }
  ThemeData theme(Brightness b) {
    final seed = AppStore.accents[store.accent];
    final base = ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: b), useMaterial3: true, brightness: b);
    return base.copyWith(textTheme: themedText(base), scaffoldBackgroundColor: store.wallpaper == 0 && store.customWallpaper == null ? (b == Brightness.light ? const Color(0xFFF8F6FA) : const Color(0xFF141217)) : Colors.transparent, cardTheme: const CardThemeData(elevation: 0, margin: EdgeInsets.zero));
  }
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_, __) => MaterialApp(debugShowCheckedModeBanner: false, title: 'Noto', theme: theme(Brightness.light), darkTheme: theme(Brightness.dark), themeMode: store.mode, builder: (_, child) => WallpaperLayer(store: store, child: child!), home: store.loaded ? HomePage(store: store) : const Scaffold(body: Center(child: CircularProgressIndicator()))));
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.store});
  final AppStore store;
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String query = '';
  String folder = 'Todas';
  bool favoritesOnly = false;
  int sort = 0;
  List<Note> get visible {
    final q = query.toLowerCase();
    final list = widget.store.notes.where((n) => n.deletedAt == null && (!favoritesOnly || n.favorite) && (folder == 'Todas' || n.folder == folder) && (n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q) || n.tags.any((t) => t.toLowerCase().contains(q)))).toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      if (sort == 1) return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      if (sort == 2) return a.updatedAt.compareTo(b.updatedAt);
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return list;
  }
  List<String> get folders => ['Todas', ...{for (final n in widget.store.notes.where((n) => n.deletedAt == null)) n.folder}];
  Future<void> open([Note? note, String template = 'normal']) async {
    final templates = <String, Map<String, dynamic>>{
      'normal': {'title': '', 'body': '', 'check': false},
      'checklist': {'title': 'Minha lista', 'body': '[ ] Primeiro item', 'check': true},
      'estudo': {'title': 'Resumo de estudo', 'body': 'Tema:\n\nPontos principais:\n• \n\nDúvidas:\n', 'check': false},
      'rpg': {'title': 'Sessão de RPG', 'body': 'Personagens:\n\nAcontecimentos:\n\nPistas e ideias:\n', 'check': false},
      'diario': {'title': DateFormat('dd/MM/yyyy').format(DateTime.now()), 'body': 'Como foi meu dia?\n\n', 'check': false},
    };
    final model = templates[template]!;
    final fresh = note ?? Note(id: DateTime.now().microsecondsSinceEpoch.toString(), title: model['title'], body: model['body'], checklist: model['check'], updatedAt: DateTime.now(), folder: folder == 'Todas' ? 'Geral' : folder);
    final keep = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditorPage(store: widget.store, note: fresh, isNew: note == null)));
    if (keep == true && note == null) widget.store.notes.add(fresh);
    if (keep == true) await widget.store.save();
  }
  void createNote() => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('O que vamos criar?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 14), Wrap(spacing: 10, runSpacing: 10, children: [('normal', Icons.note_add_outlined, 'Nota'), ('checklist', Icons.checklist_rounded, 'Checklist'), ('estudo', Icons.school_outlined, 'Estudo'), ('rpg', Icons.auto_awesome_outlined, 'RPG'), ('diario', Icons.menu_book_outlined, 'Diário')].map((e) => ActionChip(avatar: Icon(e.$2, size: 19), label: Text(e.$3), onPressed: () { Navigator.pop(context); open(null, e.$1); })).toList())]))));
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.asset('assets/app_icon.png', width: 40, height: 40)), const SizedBox(width: 10), const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Noto', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), Text('Tuas ideias, do teu jeito', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500))])]), actions: [PopupMenuButton<int>(tooltip: 'Ordenar', icon: const Icon(Icons.sort_rounded), onSelected: (v) => setState(() => sort = v), itemBuilder: (_) => const [PopupMenuItem(value: 0, child: Text('Mais recentes')), PopupMenuItem(value: 1, child: Text('Por nome')), PopupMenuItem(value: 2, child: Text('Mais antigas'))]), IconButton(tooltip: 'Lixeira', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TrashPage(store: widget.store))), icon: const Icon(Icons.delete_outline)), IconButton(tooltip: 'Personalizar', onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SettingsSheet(store: widget.store)), icon: const Icon(Icons.palette_outlined)), const SizedBox(width: 4)]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 2), child: Row(children: [Expanded(child: _SummaryCard(icon: Icons.note_alt_outlined, value: widget.store.notes.where((n) => n.deletedAt == null).length.toString(), label: 'notas')), const SizedBox(width: 10), Expanded(child: _SummaryCard(icon: Icons.star_outline_rounded, value: widget.store.notes.where((n) => n.deletedAt == null && n.favorite).length.toString(), label: 'favoritas')), const SizedBox(width: 10), IconButton.filledTonal(tooltip: 'Fundo da tela inicial', onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => WallpaperSheet(store: widget.store)), icon: const Icon(Icons.add_photo_alternate_outlined))])),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 14), child: SearchBar(hintText: 'Pesquisar nas notas...', leading: const Icon(Icons.search), elevation: const WidgetStatePropertyAll(0), backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest.withOpacity(.6)), onChanged: (v) => setState(() => query = v))),
        SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [FilterChip(label: const Text('Favoritas'), avatar: const Icon(Icons.star_rounded, size: 17), selected: favoritesOnly, onSelected: (v) => setState(() => favoritesOnly = v)), const SizedBox(width: 8), ...folders.map((f) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(f), selected: folder == f, onSelected: (_) => setState(() => folder = f))))])),
        const SizedBox(height: 10),
        Expanded(child: visible.isEmpty ? _Empty(searching: query.isNotEmpty, onCreate: createNote) : widget.store.grid ? GridView.builder(padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .82), itemCount: visible.length, itemBuilder: (_, i) => NoteCard(note: visible[i], store: widget.store, onOpen: () => open(visible[i]))) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => NoteCard(note: visible[i], store: widget.store, onOpen: () => open(visible[i]), wide: true))),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: createNote, icon: const Icon(Icons.add_rounded), label: const Text('Criar')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.icon, required this.value, required this.label});
  final IconData icon; final String value; final String label;
  @override Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(.9), borderRadius: BorderRadius.circular(17)), child: Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), const SizedBox(width: 4), Flexible(child: Text(label, style: const TextStyle(fontSize: 11)))]));
}

class _Empty extends StatelessWidget {
  const _Empty({required this.searching, required this.onCreate}); final bool searching; final VoidCallback onCreate;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(searching ? Icons.search_off_rounded : Icons.note_alt_outlined, size: 76, color: Theme.of(context).colorScheme.primary.withOpacity(.65)), const SizedBox(height: 18), Text(searching ? 'Nenhuma nota encontrada' : 'Teu espaço começa aqui', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(searching ? 'Tenta pesquisar com outras palavras.' : 'Cria uma nota e deixa ela com a tua cara.', textAlign: TextAlign.center), if (!searching) ...[const SizedBox(height: 22), FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Criar primeira nota'))]])));
}

class NoteCard extends StatelessWidget {
  const NoteCard({super.key, required this.note, required this.store, required this.onOpen, this.wide = false});
  final Note note; final AppStore store; final VoidCallback onOpen; final bool wide;
  static const colors = [Color(0x00000000), Color(0xFFFFE5AA), Color(0xFFCDEEE7), Color(0xFFE6D8FF), Color(0xFFFFD7D2), Color(0xFFD8E8FF)];
  static const textColors = [Colors.transparent, Colors.white, Colors.black, Color(0xFFFFD54F), Color(0xFFFF8A80), Color(0xFF80DEEA), Color(0xFFCE93D8)];
  @override
  Widget build(BuildContext context) {
    final bg = note.color == 0 ? Theme.of(context).colorScheme.surfaceContainer : colors[note.color];
    final noteWallpaper = wallpaperFor(note);
    final automatic = noteWallpaper != null ? Colors.white : (note.color == 0 ? Theme.of(context).colorScheme.onSurface : Colors.black87);
    final fg = note.textColor == 0 ? automatic : textColors[note.textColor];
    final family = AppStore.fontFamilies[note.font];
    return Card(
      clipBehavior: Clip.antiAlias,
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Ink(
        decoration: BoxDecoration(
          color: bg,
          image: noteWallpaper == null ? null : DecorationImage(image: noteWallpaper, fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .34), BlendMode.darken)),
        ),
        child: InkWell(
          onTap: onOpen,
          onLongPress: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: Icon(note.favorite ? Icons.star : Icons.star_outline), title: Text(note.favorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos'), onTap: () { Navigator.pop(context); note.favorite = !note.favorite; store.save(); }), ListTile(leading: Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(note.pinned ? 'Desafixar' : 'Fixar no topo'), onTap: () { Navigator.pop(context); store.togglePin(note); }), ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Mover para a lixeira', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); store.delete(note); })]))),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(note.title.trim().isEmpty ? 'Sem título' : note.title, maxLines: wide ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontFamily: family, fontWeight: FontWeight.w800, fontSize: 17))), if (note.favorite) Icon(Icons.star_rounded, size: 17, color: fg.withValues(alpha: .85)), if (note.pinned) Icon(Icons.push_pin, size: 17, color: fg.withValues(alpha: .7))]),
              const SizedBox(height: 9),
              Expanded(child: Text(note.body.trim().isEmpty ? 'Nota vazia' : note.body.replaceAll('[ ]', '☐').replaceAll('[x]', '☑'), maxLines: wide ? 2 : 7, overflow: TextOverflow.fade, style: TextStyle(color: fg.withValues(alpha: .9), fontFamily: family, height: 1.42))),
              const SizedBox(height: 10),
              Row(children: [Expanded(child: Text(note.folder, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg.withValues(alpha: .72), fontSize: 10, fontWeight: FontWeight.w700))), Text(DateFormat('dd/MM • HH:mm').format(note.updatedAt), style: TextStyle(color: fg.withValues(alpha: .72), fontFamily: family, fontSize: 10, fontWeight: FontWeight.w600))]),
            ]),
          ),
        ),
      ),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key, required this.store, required this.note, required this.isNew});
  final AppStore store; final Note note; final bool isNew;
  @override State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController title = TextEditingController(text: widget.note.title);
  late final TextEditingController body = TextEditingController(text: widget.note.body);
  bool get hasContent => title.text.trim().isNotEmpty || body.text.trim().isNotEmpty;
  void finish() { widget.note.title = title.text.trim(); widget.note.body = body.text; widget.note.updatedAt = DateTime.now(); Navigator.pop(context, hasContent); }
  int get words => body.text.trim().isEmpty ? 0 : body.text.trim().split(RegExp(r'\s+')).length;
  Future<void> shareNote({bool asFile = false}) async {
    widget.note.title = title.text.trim(); widget.note.body = body.text;
    final content = '${widget.note.title.isEmpty ? 'Sem título' : widget.note.title}\n\n${widget.note.body}\n\n— Noto';
    if (!asFile) { await Share.share(content); return; }
    final dir = await getTemporaryDirectory();
    final safe = (widget.note.title.isEmpty ? 'nota' : widget.note.title).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final file = File('${dir.path}/$safe.txt'); await file.writeAsString(content);
    await Share.shareXFiles([XFile(file.path)], text: 'Nota exportada pelo Noto');
  }
  Future<void> chooseReminder() async {
    final now = DateTime.now();
    final date = await showDatePicker(context: context, initialDate: widget.note.reminderAt ?? now, firstDate: now, lastDate: now.add(const Duration(days: 3650)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(widget.note.reminderAt ?? now.add(const Duration(hours: 1))));
    if (time == null) return;
    final selected = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (selected.isBefore(DateTime.now())) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolhe um horário que ainda não passou.'))); return; }
    await notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await notifications.zonedSchedule(widget.note.id.hashCode & 0x7fffffff, title.text.trim().isEmpty ? 'Lembrete do Noto' : title.text.trim(), body.text.trim().isEmpty ? 'Hora de conferir tua nota.' : body.text.trim().replaceAll('\n', ' '), tz.TZDateTime.from(selected, tz.local), const NotificationDetails(android: AndroidNotificationDetails('noto_reminders', 'Lembretes do Noto', channelDescription: 'Lembretes criados nas notas', importance: Importance.high, priority: Priority.high)), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, payload: widget.note.id);
    setState(() => widget.note.reminderAt = selected); await widget.store.save();
  }
  Future<void> organize() async {
    final folderController = TextEditingController(text: widget.note.folder);
    final tagsController = TextEditingController(text: widget.note.tags.join(', '));
    final save = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (context) => Padding(padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.viewInsetsOf(context).bottom), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Organizar nota', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 16), TextField(controller: folderController, decoration: const InputDecoration(labelText: 'Pasta', prefixIcon: Icon(Icons.folder_outlined), border: OutlineInputBorder())), const SizedBox(height: 12), TextField(controller: tagsController, decoration: const InputDecoration(labelText: 'Etiquetas separadas por vírgula', prefixIcon: Icon(Icons.sell_outlined), border: OutlineInputBorder())), const SizedBox(height: 16), SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar organização')))])));
    if (save == true) setState(() { widget.note.folder = folderController.text.trim().isEmpty ? 'Geral' : folderController.text.trim(); widget.note.tags = tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(); });
  }
  @override
  Widget build(BuildContext context) {
    final color = NoteCard.colors[widget.note.color];
    final selectedWallpaper = wallpaperFor(widget.note);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) finish();
      },
      child: Scaffold(
        backgroundColor: widget.note.color == 0 ? null : color,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            onPressed: finish,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(tooltip: 'Favoritar', onPressed: () => setState(() => widget.note.favorite = !widget.note.favorite), icon: Icon(widget.note.favorite ? Icons.star_rounded : Icons.star_outline_rounded)),
            IconButton(
              tooltip: 'Fixar',
              onPressed: () => setState(
                () => widget.note.pinned = !widget.note.pinned,
              ),
              icon: Icon(
                widget.note.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Wallpaper da nota',
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => WallpaperSheet(store: widget.store, note: widget.note),
              ).then((_) => setState(() {})),
              icon: const Icon(Icons.wallpaper_outlined),
            ),
            IconButton(
              tooltip: 'Fonte da nota',
              icon: const Icon(Icons.font_download_outlined),
              onPressed: () => showModalBottomSheet<int>(
                context: context,
                isScrollControlled: true,
                builder: (_) => FontPickerSheet(selected: widget.note.font),
              ).then((value) { if (value != null) setState(() => widget.note.font = value); }),
            ),
            PopupMenuButton<int>(
              tooltip: 'Cor do texto',
              icon: const Icon(Icons.format_color_text),
              onSelected: (v) => setState(() => widget.note.textColor = v),
              itemBuilder: (_) => List.generate(
                NoteCard.textColors.length,
                (i) => PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 11,
                      backgroundColor: i == 0 ? Theme.of(context).colorScheme.outline : NoteCard.textColors[i],
                      child: widget.note.textColor == i ? const Icon(Icons.check, size: 15) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(i == 0 ? 'Automática' : 'Cor $i'),
                  ]),
                ),
              ),
            ),
            PopupMenuButton<int>(
              tooltip: 'Cor da nota',
              icon: const Icon(Icons.color_lens_outlined),
              onSelected: (v) => setState(() => widget.note.color = v),
              itemBuilder: (_) => List.generate(
                NoteCard.colors.length,
                (i) => PopupMenuItem(
                  value: i,
                  child: Row(children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: i == 0
                          ? Theme.of(context).colorScheme.surfaceContainerHighest
                          : NoteCard.colors[i],
                      child: widget.note.color == i
                          ? const Icon(Icons.check, size: 15)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(i == 0 ? 'Padrão do tema' : 'Cor $i'),
                  ]),
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) { if (v == 'organize') organize(); if (v == 'reminder') chooseReminder(); if (v == 'share') shareNote(); if (v == 'export') shareNote(asFile: true); if (v == 'check') { final insert = body.text.isEmpty ? '[ ] ' : '\n[ ] '; body.text += insert; body.selection = TextSelection.collapsed(offset: body.text.length); setState(() => widget.note.checklist = true); } },
              itemBuilder: (_) => [const PopupMenuItem(value: 'organize', child: ListTile(leading: Icon(Icons.folder_outlined), title: Text('Pasta e etiquetas'))), const PopupMenuItem(value: 'reminder', child: ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Criar lembrete'))), const PopupMenuItem(value: 'check', child: ListTile(leading: Icon(Icons.check_box_outlined), title: Text('Adicionar item'))), const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share_outlined), title: Text('Compartilhar'))), const PopupMenuItem(value: 'export', child: ListTile(leading: Icon(Icons.file_download_outlined), title: Text('Exportar como TXT')))],
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Container(
          decoration: selectedWallpaper == null ? null : BoxDecoration(
            image: DecorationImage(
              image: selectedWallpaper,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: .38), BlendMode.darken),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 20),
          child: Column(children: [
            TextField(
              controller: title,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Título',
                border: InputBorder.none,
              ),
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, fontFamily: AppStore.fontFamilies[widget.note.font], color: widget.note.textColor == 0 ? (selectedWallpaper != null ? Colors.white : null) : NoteCard.textColors[widget.note.textColor]),
            ),
            if (widget.note.reminderAt != null) Align(alignment: Alignment.centerLeft, child: Chip(avatar: const Icon(Icons.notifications_active_outlined, size: 17), label: Text(DateFormat("dd/MM 'às' HH:mm").format(widget.note.reminderAt!)), onDeleted: () async { await notifications.cancel(widget.note.id.hashCode & 0x7fffffff); setState(() => widget.note.reminderAt = null); })),
            if (widget.note.tags.isNotEmpty) Align(alignment: Alignment.centerLeft, child: Wrap(spacing: 6, children: widget.note.tags.map((t) => Chip(label: Text('#$t'), visualDensity: VisualDensity.compact)).toList())),
            Expanded(
              child: TextField(
                controller: body,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Escreve alguma coisa...',
                  border: InputBorder.none,
                ),
                style: TextStyle(fontSize: widget.store.fontSize, height: 1.55, fontFamily: AppStore.fontFamilies[widget.note.font], color: widget.note.textColor == 0 ? (selectedWallpaper != null ? Colors.white : null) : NoteCard.textColors[widget.note.textColor]),
              ),
            ),
            Align(alignment: Alignment.centerRight, child: Text('$words palavras • ${body.text.length} caracteres', style: Theme.of(context).textTheme.labelSmall)),
          ]),
        ),
      ),
    );
  }
}

class TrashPage extends StatelessWidget {
  const TrashPage({super.key, required this.store});
  final AppStore store;
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_, __) {
    final deleted = store.notes.where((n) => n.deletedAt != null).toList()..sort((a, b) => b.deletedAt!.compareTo(a.deletedAt!));
    return Scaffold(appBar: AppBar(title: const Text('Lixeira', style: TextStyle(fontWeight: FontWeight.w800))), body: deleted.isEmpty ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.delete_sweep_outlined, size: 72), SizedBox(height: 12), Text('A lixeira está vazia')])) : ListView.separated(padding: const EdgeInsets.all(16), itemCount: deleted.length, separatorBuilder: (_, __) => const SizedBox(height: 8), itemBuilder: (_, i) { final note = deleted[i]; return Card(child: ListTile(title: Text(note.title.isEmpty ? 'Sem título' : note.title), subtitle: Text('Apagada em ${DateFormat('dd/MM • HH:mm').format(note.deletedAt!)}'), trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'restore') store.restore(note); if (v == 'delete') store.deleteForever(note); }, itemBuilder: (_) => const [PopupMenuItem(value: 'restore', child: Text('Restaurar')), PopupMenuItem(value: 'delete', child: Text('Excluir para sempre', style: TextStyle(color: Colors.red)))]))); }));
  });
}

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.store}); final AppStore store;
  @override Widget build(BuildContext context) => AnimatedBuilder(animation: store, builder: (_, __) => SafeArea(child: Padding(padding: EdgeInsets.fromLTRB(22, 18, 22, 22 + MediaQuery.viewInsetsOf(context).bottom), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(4)))), const SizedBox(height: 20), Text('Deixa com a tua cara', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 20), const Text('APARÊNCIA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 8), SegmentedButton<ThemeMode>(segments: const [ButtonSegment(value: ThemeMode.system, label: Text('Sistema')), ButtonSegment(value: ThemeMode.light, label: Text('Claro')), ButtonSegment(value: ThemeMode.dark, label: Text('Escuro'))], selected: {store.mode}, onSelectionChanged: (v) { store.mode = v.first; store.save(); }), const SizedBox(height: 20), const Text('COR PRINCIPAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 10), Wrap(spacing: 13, children: List.generate(AppStore.accents.length, (i) => InkWell(onTap: () { store.accent = i; store.save(); }, customBorder: const CircleBorder(), child: CircleAvatar(radius: 19, backgroundColor: AppStore.accents[i], child: store.accent == i ? const Icon(Icons.check, color: Colors.white) : null)))), const SizedBox(height: 20), const Text('FONTE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 8), OutlinedButton.icon(icon: const Icon(Icons.font_download_outlined), label: Expanded(child: Text(AppStore.fonts[store.font], style: TextStyle(fontFamily: AppStore.fontFamilies[store.font]))), onPressed: () => showModalBottomSheet<int>(context: context, isScrollControlled: true, builder: (_) => FontPickerSheet(selected: store.font)).then((v) { if (v != null) { store.font = v; store.save(); } })), const SizedBox(height: 14), Row(children: [const Text('Tamanho do texto'), Expanded(child: Slider(value: store.fontSize, min: 14, max: 24, divisions: 5, label: store.fontSize.round().toString(), onChanged: (v) { store.fontSize = v; store.save(); })), SizedBox(width: 28, child: Text(store.fontSize.round().toString()))])]))));
}

class FontPickerSheet extends StatefulWidget {
  const FontPickerSheet({super.key, required this.selected});
  final int selected;
  @override State<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends State<FontPickerSheet> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final indexes = List.generate(AppStore.fonts.length, (i) => i)
        .where((i) => AppStore.fonts[i].toLowerCase().contains(query.toLowerCase())).toList();
    return SafeArea(child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .78,
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outlineVariant, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 18),
        Text('Escolhe uma fonte', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        SearchBar(hintText: 'Pesquisar entre ${AppStore.fonts.length} fontes', leading: const Icon(Icons.search), elevation: const WidgetStatePropertyAll(0), onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 10),
        Expanded(child: ListView.builder(itemCount: indexes.length, itemBuilder: (_, position) {
          final i = indexes[position];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            title: Text(AppStore.fonts[i], style: TextStyle(fontFamily: AppStore.fontFamilies[i], fontSize: 21)),
            subtitle: Text('A imaginação começa aqui', style: TextStyle(fontFamily: AppStore.fontFamilies[i])),
            trailing: widget.selected == i ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
            onTap: () => Navigator.pop(context, i),
          );
        })),
      ])),
    ));
  }
}

class WallpaperLayer extends StatelessWidget {
  const WallpaperLayer({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;
  static const paths = [
    '',
    'assets/wallpapers/stars.png',
    'assets/wallpapers/forest.png',
    'assets/wallpapers/ocean.png',
    'assets/wallpapers/flowers.png',
    'assets/wallpapers/aurora.png',
    'assets/wallpapers/waterfall.png',
    'assets/wallpapers/cherry.png',
    'assets/wallpapers/lake.png',
    'assets/wallpapers/rain.png',
    'assets/wallpapers/nebula.png',
    'assets/wallpapers/supercar.png',
    'assets/wallpapers/fire_dragon.png',
    'assets/wallpapers/eternum.png',
    'assets/wallpapers/overtake.png',
    'assets/wallpapers/pixel_valley.png',
    'assets/wallpapers/moon_knight.png',
    'assets/wallpapers/crystal_kingdom.png',
    'assets/wallpapers/black_hole.png',
    'assets/wallpapers/neon_city.png',
    'assets/wallpapers/celestial_dragon.png',
  ];

  @override
  Widget build(BuildContext context) {
    final custom = store.customWallpaper;
    final customFile = custom == null ? null : File(custom);
    final hasCustom = customFile != null && customFile.existsSync();
    if (store.wallpaper == 0 && !hasCustom) return child;
    return Stack(fit: StackFit.expand, children: [
      if (hasCustom) Image.file(customFile, fit: BoxFit.cover) else Image.asset(paths[store.wallpaper], fit: BoxFit.cover),
      ColoredBox(color: Colors.black.withOpacity(.25)),
      child,
    ]);
  }
}

class WallpaperSheet extends StatelessWidget {
  const WallpaperSheet({super.key, required this.store, this.note});
  final AppStore store;
  final Note? note;
  Future<void> _pickCustom(BuildContext context) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1800);
    if (picked == null || !context.mounted) return;
    final directory = await getApplicationDocumentsDirectory();
    final saved = await File(picked.path).copy('${directory.path}/noto_wallpaper_${DateTime.now().microsecondsSinceEpoch}.jpg');
    if (note != null) {
      note!.customWallpaper = saved.path;
      note!.wallpaper = 0;
    } else {
      store.customWallpaper = saved.path;
      store.wallpaper = 0;
    }
    await store.save();
    if (context.mounted) Navigator.pop(context);
  }
  static const names = [
    'Sem foto', 'Estrelas', 'Floresta', 'Oceano', 'Flores',
    'Aurora', 'Cachoeira', 'Cerejeiras', 'Lago alpino', 'Chuva', 'Nebulosa',
    'Supercarro', 'Dragão de fogo', 'Eternum', 'Ultrapassagem', 'Vale pixelado',
    'Cavaleiro lunar', 'Reino de cristal', 'Buraco negro', 'Cidade neon', 'Dragão celestial',
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Escolhe teu fundo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _pickCustom(context),
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(note == null ? 'Usar foto na tela inicial' : 'Usar foto nesta nota'),
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(height: 190, child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => GestureDetector(
            onTap: () { if (note != null) { note!.wallpaper = i; note!.customWallpaper = null; store.save(); } else { store.wallpaper = i; store.customWallpaper = null; store.save(); } Navigator.pop(context); },
            child: SizedBox(width: 112, child: Column(children: [
              Expanded(child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(18),
                  border: (note?.wallpaper ?? store.wallpaper) == i ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3) : null,
                  image: i == 0 ? null : DecorationImage(image: AssetImage(WallpaperLayer.paths[i]), fit: BoxFit.cover),
                ),
                child: i == 0 ? const Center(child: Icon(Icons.block, size: 34)) : null,
              )),
              const SizedBox(height: 8),
              Text(names[i], style: const TextStyle(fontWeight: FontWeight.w600)),
            ])),
          ),
        )),
      ]),
    ),
  );
}
