import 'package:flutter/material.dart';

class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
    this.color = 0,
    this.pinned = false,
    this.wallpaper = 0,
    this.customWallpaper,
    this.textColor = 0,
    this.font = 0,
    this.titleFont,
    this.bodyFont,
    this.favorite = false,
    this.folder = 'Geral',
    this.tags = const [],
    this.checklist = false,
    this.deletedAt,
    this.reminderAt,
    this.archived = false,
    this.wallpaperDarkness = .38,
    this.wallpaperBlur = 0,
    this.emoji = '',
    this.coverImage,
    this.cardOpacity = 1,
    this.priority = 0,
    this.dueAt,
  });

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
  int? titleFont;
  int? bodyFont;
  bool favorite;
  String folder;
  List<String> tags;
  bool checklist;
  DateTime? deletedAt;
  DateTime? reminderAt;
  bool archived;
  double wallpaperDarkness;
  double wallpaperBlur;
  String emoji;
  String? coverImage;
  double cardOpacity;
  int priority;
  DateTime? dueAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updatedAt': updatedAt.toIso8601String(),
        'color': color,
        'pinned': pinned,
        'wallpaper': wallpaper,
        'customWallpaper': customWallpaper,
        'textColor': textColor,
        'font': font,
        'titleFont': titleFont,
        'bodyFont': bodyFont,
        'favorite': favorite,
        'folder': folder,
        'tags': tags,
        'checklist': checklist,
        'deletedAt': deletedAt?.toIso8601String(),
        'reminderAt': reminderAt?.toIso8601String(),
        'archived': archived,
        'wallpaperDarkness': wallpaperDarkness,
        'wallpaperBlur': wallpaperBlur,
        'emoji': emoji,
        'coverImage': coverImage,
        'cardOpacity': cardOpacity,
        'priority': priority,
        'dueAt': dueAt?.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
        color: json['color'] ?? 0,
        pinned: json['pinned'] ?? false,
        wallpaper: json['wallpaper'] ?? 0,
        customWallpaper: json['customWallpaper'],
        textColor: json['textColor'] ?? 0,
        font: json['font'] ?? 0,
        titleFont: json['titleFont'] is int ? json['titleFont'] as int : null,
        bodyFont: json['bodyFont'] is int ? json['bodyFont'] as int : null,
        favorite: json['favorite'] ?? false,
        folder: json['folder'] ?? 'Geral',
        tags: List<String>.from(json['tags'] ?? const []),
        checklist: json['checklist'] ?? false,
        deletedAt: json['deletedAt'] == null ? null : DateTime.tryParse(json['deletedAt']),
        reminderAt: json['reminderAt'] == null ? null : DateTime.tryParse(json['reminderAt']),
        archived: json['archived'] ?? false,
        wallpaperDarkness: (json['wallpaperDarkness'] ?? .38).toDouble(),
        wallpaperBlur: (json['wallpaperBlur'] ?? 0).toDouble(),
        emoji: json['emoji']?.toString() ?? '',
        coverImage: json['coverImage']?.toString(),
        cardOpacity: (json['cardOpacity'] ?? 1).toDouble().clamp(.35, 1),
        priority: (json['priority'] ?? 0).toInt().clamp(0, 3),
        dueAt: json['dueAt'] == null ? null : DateTime.tryParse(json['dueAt']),
      );
}

class NotoTemplate {
  NotoTemplate({
    required this.id,
    required this.name,
    this.title = '',
    this.body = '',
    this.checklist = false,
    this.emoji = '',
  });

  final String id;
  String name;
  String title;
  String body;
  bool checklist;
  String emoji;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'title': title,
        'body': body,
        'checklist': checklist,
        'emoji': emoji,
      };

  factory NotoTemplate.fromJson(Map<String, dynamic> json) => NotoTemplate(
        id: json['id']?.toString() ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name']?.toString() ?? 'Modelo',
        title: json['title']?.toString() ?? '',
        body: json['body']?.toString() ?? '',
        checklist: json['checklist'] ?? false,
        emoji: json['emoji']?.toString() ?? '',
      );
}

class NotoAccent {
  const NotoAccent(this.name, this.color);
  final String name;
  final Color color;
}

class NotoFont {
  const NotoFont(this.name, this.family, {this.subtitle = 'A imaginação começa aqui'});
  final String name;
  final String? family;
  final String subtitle;
}

class NotoAppearance {
  static const accents = <NotoAccent>[
    NotoAccent('Uva', Color(0xFF7454D6)),
    NotoAccent('Índigo', Color(0xFF4F5FD7)),
    NotoAccent('Azul', Color(0xFF2D6FD6)),
    NotoAccent('Céu', Color(0xFF1687C9)),
    NotoAccent('Ciano', Color(0xFF0D8F9F)),
    NotoAccent('Menta', Color(0xFF218C74)),
    NotoAccent('Verde', Color(0xFF3B7D44)),
    NotoAccent('Lima', Color(0xFF6F8F2D)),
    NotoAccent('Âmbar', Color(0xFFB17A14)),
    NotoAccent('Laranja', Color(0xFFCA6718)),
    NotoAccent('Coral', Color(0xFFC95746)),
    NotoAccent('Vermelho', Color(0xFFB8424A)),
    NotoAccent('Rosa', Color(0xFFC24878)),
    NotoAccent('Magenta', Color(0xFFA744A3)),
    NotoAccent('Café', Color(0xFF7C6257)),
    NotoAccent('Grafite', Color(0xFF59636B)),
  ];

  static const fonts = <NotoFont>[
    NotoFont('Moderna', null),
    NotoFont('Livro', 'serif'),
    NotoFont('Máquina', 'monospace'),
    NotoFont('Poppins', 'Poppins'),
    NotoFont('Montserrat', 'Montserrat'),
    NotoFont('Playfair', 'Playfair'),
    NotoFont('Bebas Neue', 'BebasNeue'),
    NotoFont('Lobster', 'Lobster'),
    NotoFont('Pacifico', 'Pacifico'),
    NotoFont('Caveat', 'Caveat'),
    NotoFont('Dancing Script', 'DancingScript'),
    NotoFont('Oswald', 'Oswald'),
    NotoFont('Raleway', 'Raleway'),
    NotoFont('Lora', 'Lora'),
    NotoFont('Nunito', 'Nunito'),
    NotoFont('Quicksand', 'Quicksand'),
    NotoFont('Rubik', 'Rubik'),
    NotoFont('Cinzel', 'Cinzel'),
    NotoFont('Bangers', 'Bangers'),
    NotoFont('Comfortaa', 'Comfortaa'),
    NotoFont('Inter', 'Inter'),
    NotoFont('Fira Sans', 'FiraSans'),
    NotoFont('Fira Code', 'FiraCode'),
    NotoFont('Josefin Sans', 'JosefinSans'),
    NotoFont('Abril Fatface', 'AbrilFatface'),
    NotoFont('Fredoka', 'Fredoka'),
    NotoFont('Kalam', 'Kalam'),
    NotoFont('Satisfy', 'Satisfy'),
    NotoFont('Righteous', 'Righteous'),
    NotoFont('Space Grotesk', 'SpaceGrotesk'),
    NotoFont('Manrope', 'Manrope'),
    NotoFont('Urbanist', 'Urbanist'),
    NotoFont('DM Serif', 'DMSerifDisplay'),
    NotoFont('Libre Baskerville', 'LibreBaskerville'),
  ];

  static const noteColors = <Color>[
    Color(0x00000000),
    Color(0xFFFFE39D),
    Color(0xFFFFC8B8),
    Color(0xFFFFC6D8),
    Color(0xFFE6CBFF),
    Color(0xFFC9D8FF),
    Color(0xFFBDEAFF),
    Color(0xFFBFEDE3),
    Color(0xFFCDEBBE),
    Color(0xFFE4E7AB),
    Color(0xFFE1D5C8),
    Color(0xFFD8DDE3),
  ];

  static const textColors = <Color>[
    Colors.transparent,
    Colors.white,
    Color(0xFF171717),
    Color(0xFFFFD54F),
    Color(0xFFFF8A80),
    Color(0xFF80DEEA),
    Color(0xFFCE93D8),
    Color(0xFFA5D6A7),
    Color(0xFFFFAB91),
  ];

  static const wallpaperPaths = <String>[
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

  static const wallpaperNames = <String>[
    'Sem foto',
    'Estrelas',
    'Floresta',
    'Oceano',
    'Flores',
    'Aurora',
    'Cachoeira',
    'Cerejeiras',
    'Lago alpino',
    'Chuva',
    'Nebulosa',
    'Supercarro',
    'Dragão de fogo',
    'Eternum',
    'Ultrapassagem',
    'Vale pixelado',
    'Cavaleiro lunar',
    'Reino de cristal',
    'Buraco negro',
    'Cidade neon',
    'Dragão celestial',
  ];

  static int safeFontIndex(int index) => index.clamp(0, fonts.length - 1).toInt();
  static int safeAccentIndex(int index) => index.clamp(0, accents.length - 1).toInt();
  static int safeNoteColorIndex(int index) => index.clamp(0, noteColors.length - 1).toInt();
  static int safeTextColorIndex(int index) => index.clamp(0, textColors.length - 1).toInt();
  static String? familyAt(int index) => fonts[safeFontIndex(index)].family;
}
