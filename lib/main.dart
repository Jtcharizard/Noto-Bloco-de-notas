import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const NotesApp());

class Note {
  Note({required this.id, required this.title, required this.body, required this.updatedAt, this.color = 0, this.pinned = false, this.wallpaper = 0, this.customWallpaper, this.textColor = 0, this.font = 0});
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

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body, 'updatedAt': updatedAt.toIso8601String(), 'color': color, 'pinned': pinned, 'wallpaper': wallpaper, 'customWallpaper': customWallpaper, 'textColor': textColor, 'font': font};
  factory Note.fromJson(Map<String, dynamic> j) => Note(id: j['id'], title: j['title'] ?? '', body: j['body'] ?? '', updatedAt: DateTime.parse(j['updatedAt']), color: j['color'] ?? 0, pinned: j['pinned'] ?? false, wallpaper: j['wallpaper'] ?? 0, customWallpaper: j['customWallpaper'], textColor: j['textColor'] ?? 0, font: j['font'] ?? 0);
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
    notifyListeners();
  }

  void delete(Note n) { notes.remove(n); save(); }
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
  List<Note> get visible {
    final q = query.toLowerCase();
    final list = widget.store.notes.where((n) => n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q)).toList();
    list.sort((a, b) => a.pinned != b.pinned ? (a.pinned ? -1 : 1) : b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
  Future<void> open([Note? note]) async {
    final fresh = note ?? Note(id: DateTime.now().microsecondsSinceEpoch.toString(), title: '', body: '', updatedAt: DateTime.now());
    final keep = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => EditorPage(store: widget.store, note: fresh, isNew: note == null)));
    if (keep == true && note == null) widget.store.notes.add(fresh);
    if (keep == true) await widget.store.save();
  }
  @override Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Noto', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)), actions: [IconButton(tooltip: widget.store.grid ? 'Usar lista' : 'Usar grade', onPressed: () { widget.store.grid = !widget.store.grid; widget.store.save(); }, icon: Icon(widget.store.grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded)), IconButton(tooltip: 'Escolher foto de fundo', onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => WallpaperSheet(store: widget.store)), icon: const Icon(Icons.wallpaper_outlined)), IconButton(tooltip: 'Personalizar', onPressed: () => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SettingsSheet(store: widget.store)), icon: const Icon(Icons.palette_outlined)), const SizedBox(width: 8)]),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 14), child: SearchBar(hintText: 'Pesquisar nas notas...', leading: const Icon(Icons.search), elevation: const WidgetStatePropertyAll(0), backgroundColor: WidgetStatePropertyAll(cs.surfaceContainerHighest.withOpacity(.6)), onChanged: (v) => setState(() => query = v))),
        Expanded(child: visible.isEmpty ? _Empty(searching: query.isNotEmpty, onCreate: open) : widget.store.grid ? GridView.builder(padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: .82), itemCount: visible.length, itemBuilder: (_, i) => NoteCard(note: visible[i], store: widget.store, onOpen: () => open(visible[i]))) : ListView.separated(padding: const EdgeInsets.fromLTRB(16, 2, 16, 100), itemCount: visible.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (_, i) => NoteCard(note: visible[i], store: widget.store, onOpen: () => open(visible[i]), wide: true))),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => open(), icon: const Icon(Icons.edit_outlined), label: const Text('Nova nota')),
    );
  }
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
          onLongPress: () => showModalBottomSheet(context: context, builder: (_) => SafeArea(child: Wrap(children: [ListTile(leading: Icon(note.pinned ? Icons.push_pin_outlined : Icons.push_pin), title: Text(note.pinned ? 'Desafixar' : 'Fixar no topo'), onTap: () { Navigator.pop(context); store.togglePin(note); }), ListTile(leading: const Icon(Icons.delete_outline, color: Colors.red), title: const Text('Excluir nota', style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(context); store.delete(note); })]))),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text(note.title.trim().isEmpty ? 'Sem título' : note.title, maxLines: wide ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontFamily: family, fontWeight: FontWeight.w800, fontSize: 17))), if (note.pinned) Icon(Icons.push_pin, size: 17, color: fg.withValues(alpha: .7))]),
              const SizedBox(height: 9),
              Expanded(child: Text(note.body.trim().isEmpty ? 'Nota vazia' : note.body, maxLines: wide ? 2 : 7, overflow: TextOverflow.fade, style: TextStyle(color: fg.withValues(alpha: .9), fontFamily: family, height: 1.42))),
              const SizedBox(height: 10),
              Text(DateFormat('dd/MM • HH:mm').format(note.updatedAt), style: TextStyle(color: fg.withValues(alpha: .72), fontFamily: family, fontSize: 11, fontWeight: FontWeight.w600)),
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
          ]),
        ),
      ),
    );
  }
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
