import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'noto_models.dart';
import 'noto_store.dart';

class NotoPalette {
  static const ink = Color(0xFF211536);
  static const inkSoft = Color(0xFF35244D);
  static const cocoa = Color(0xFF402566);
  static const paper = Color(0xFFF7F3FF);
  static const paperSoft = Color(0xFFFEFCFF);
  static const paperDeep = Color(0xFFE3D6FF);
  static const ember = Color(0xFF7C3AED);
  static const emberSoft = Color(0xFFB89AFF);
}

ThemeData notoTheme(AppStore store, Brightness brightness) {
  final selectedAccent = NotoAppearance
      .accents[NotoAppearance.safeAccentIndex(store.accent)]
      .color;
  final dark = brightness == Brightness.dark;
  final accent = dark
      ? Color.lerp(selectedAccent, Colors.white, .25)!
      : selectedAccent;
  final surface = dark ? const Color(0xFF171023) : NotoPalette.paper;
  final raised = dark ? const Color(0xFF261B38) : NotoPalette.paperSoft;
  final text = dark ? const Color(0xFFF7F0FF) : NotoPalette.ink;
  final muted = dark ? const Color(0xFFC0AFD5) : const Color(0xFF685979);
  final line = dark ? const Color(0xFF4B3862) : const Color(0xFFD9C8F0);

  final generated = ColorScheme.fromSeed(
    seedColor: selectedAccent,
    brightness: brightness,
  );
  final scheme = generated.copyWith(
    primary: accent,
    onPrimary: accent.computeLuminance() > .179 ? Colors.black : Colors.white,
    surface: surface,
    onSurface: text,
    outline: muted,
    outlineVariant: line,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: raised,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: Color.alphaBlend(
      accent.withValues(alpha: .08),
      raised,
    ),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: NotoAppearance.familyAt(store.font),
  );

  return base.copyWith(
    scaffoldBackgroundColor: surface,
    canvasColor: surface,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: text,
      titleTextStyle: TextStyle(
        color: text,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -.4,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: line),
      ),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(color: muted),
      labelStyle: TextStyle(color: muted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
      border: UnderlineInputBorder(borderSide: BorderSide(color: line)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: line)),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: accent, width: 1.6),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent,
      selectedColor: accent.withValues(alpha: .10),
      side: BorderSide(color: line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      labelStyle: TextStyle(
        color: text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 1,
      foregroundColor: scheme.onPrimary,
      backgroundColor: accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: false,
      backgroundColor: raised,
      modalBackgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFFEAE3DB) : NotoPalette.ink,
      contentTextStyle: TextStyle(color: dark ? NotoPalette.ink : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

ImageProvider? noteWallpaper(Note note) {
  final custom = note.customWallpaper;
  if (custom != null && File(custom).existsSync()) {
    return FileImage(File(custom));
  }
  if (note.wallpaper > 0 &&
      note.wallpaper < NotoAppearance.wallpaperPaths.length) {
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
    final hasBuiltIn =
        store.wallpaper > 0 &&
        store.wallpaper < NotoAppearance.wallpaperPaths.length;
    if (!hasCustom && !hasBuiltIn) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: store.wallpaperBlur,
            sigmaY: store.wallpaperBlur,
          ),
          child: hasCustom
              ? Image.file(file, fit: BoxFit.cover)
              : Image.asset(
                  NotoAppearance.wallpaperPaths[store.wallpaper],
                  fit: BoxFit.cover,
                ),
        ),
        ColoredBox(
          color: NotoPalette.ink.withValues(alpha: store.wallpaperDarkness),
        ),
        child,
      ],
    );
  }
}

class NotoMark extends StatelessWidget {
  const NotoMark({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/noto_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Noto',
    );
  }
}

class NotoSurface extends StatelessWidget {
  const NotoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    final content = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .62),
            ),
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: iconColor ?? cs.onSurface.withValues(alpha: .70),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurface.withValues(alpha: .58),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 19,
                color: cs.onSurface.withValues(alpha: .38),
              ),
          ],
        ),
      ),
    );
  }
}

/// Reserves system navigation space for every route, including modal sheets.
class NotoSafeFrame extends StatelessWidget {
  const NotoSafeFrame({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      top: false,
      maintainBottomViewPadding: true,
      child: Padding(padding: const EdgeInsets.only(bottom: 12), child: child),
    ),
  );
}
