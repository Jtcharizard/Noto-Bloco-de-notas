import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'noto_models.dart';
import 'noto_store.dart';

ThemeData notoTheme(AppStore store, Brightness brightness) {
  final accent = NotoAppearance.accents[store.accent.clamp(0, NotoAppearance.accents.length - 1)].color;
  final scheme = ColorScheme.fromSeed(seedColor: accent, brightness: brightness);
  final dark = brightness == Brightness.dark;
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: NotoAppearance.familyAt(store.font),
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? const Color(0xFF101114) : const Color(0xFFF7F7F8),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: scheme.onSurface,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF191B20) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1B1D22) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: scheme.primary, width: 1.4),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      elevation: 0,
      backgroundColor: dark ? const Color(0xFF17191E) : Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface, fontSize: 12),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: dark ? const Color(0xFF17191E) : const Color(0xFFFBFBFC),
      modalBackgroundColor: dark ? const Color(0xFF17191E) : const Color(0xFFFBFBFC),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
  );
}

ImageProvider? noteWallpaper(Note note) {
  final custom = note.customWallpaper;
  if (custom != null && File(custom).existsSync()) return FileImage(File(custom));
  if (note.wallpaper > 0 && note.wallpaper < NotoAppearance.wallpaperPaths.length) {
    return AssetImage(NotoAppearance.wallpaperPaths[note.wallpaper]);
  }
  return null;
}

class GlobalWallpaper extends StatelessWidget {
  const GlobalWallpaper({super.key, required this.store, required this.child});
  final AppStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final custom = store.customWallpaper;
    final file = custom == null ? null : File(custom);
    final hasCustom = file != null && file.existsSync();
    final hasBuiltIn = store.wallpaper > 0 && store.wallpaper < NotoAppearance.wallpaperPaths.length;
    if (!hasCustom && !hasBuiltIn) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: store.wallpaperBlur, sigmaY: store.wallpaperBlur),
          child: hasCustom
              ? Image.file(file, fit: BoxFit.cover)
              : Image.asset(NotoAppearance.wallpaperPaths[store.wallpaper], fit: BoxFit.cover),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: store.wallpaperDarkness)),
        child,
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class NotoTile extends StatelessWidget {
  const NotoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? cs.primary).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor ?? cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing! else const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
