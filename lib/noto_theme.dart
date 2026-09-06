import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'noto_models.dart';
import 'noto_store.dart';

class NotoPalette {
  static const ink = Color(0xFF17120F);
  static const inkSoft = Color(0xFF231A16);
  static const cocoa = Color(0xFF33241C);
  static const paper = Color(0xFFF7F0E8);
  static const paperSoft = Color(0xFFFFFBF6);
  static const paperDeep = Color(0xFFECE0D3);
  static const ember = Color(0xFFE7762D);
  static const emberSoft = Color(0xFFFFC49C);
}

ThemeData notoTheme(AppStore store, Brightness brightness) {
  final accent = NotoAppearance
      .accents[NotoAppearance.safeAccentIndex(store.accent)]
      .color;
  final dark = brightness == Brightness.dark;
  final baseScheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
  );

  final scheme = baseScheme.copyWith(
    primary: accent,
    onPrimary: Colors.white,
    secondary: dark ? NotoPalette.emberSoft : NotoPalette.ember,
    onSecondary: dark ? NotoPalette.ink : Colors.white,
    surface: dark ? NotoPalette.inkSoft : NotoPalette.paperSoft,
    onSurface: dark ? const Color(0xFFFFF8F2) : NotoPalette.ink,
    surfaceContainerLowest:
        dark ? const Color(0xFF110E0C) : const Color(0xFFFFFDF9),
    surfaceContainerLow:
        dark ? const Color(0xFF191411) : const Color(0xFFFBF5EE),
    surfaceContainer:
        dark ? const Color(0xFF211916) : const Color(0xFFF6EEE5),
    surfaceContainerHigh:
        dark ? const Color(0xFF2A201B) : const Color(0xFFF0E5D9),
    surfaceContainerHighest:
        dark ? const Color(0xFF352821) : const Color(0xFFE8D9CB),
    outline: dark ? const Color(0xFF70594C) : const Color(0xFF9A7C6C),
    outlineVariant:
        dark ? const Color(0xFF45372F) : const Color(0xFFD9C5B7),
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: NotoAppearance.familyAt(store.font),
  );

  return base.copyWith(
    scaffoldBackgroundColor: dark ? NotoPalette.ink : NotoPalette.paper,
    canvasColor: dark ? NotoPalette.ink : NotoPalette.paper,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -.5,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF211916) : NotoPalette.paperSoft,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: dark ? .42 : .62),
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .55),
      thickness: 1,
      space: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark
          ? const Color(0xFF211916).withValues(alpha: .94)
          : NotoPalette.paperSoft,
      hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .46)),
      labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: .66)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: .55),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: scheme.surfaceContainer,
      selectedColor: scheme.primary.withValues(alpha: .16),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .6)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 8,
      foregroundColor: Colors.white,
      backgroundColor: accent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: dark ? const Color(0xFF1B1512) : NotoPalette.paperSoft,
      modalBackgroundColor:
          dark ? const Color(0xFF1B1512) : NotoPalette.paperSoft,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xFF1B1512) : NotoPalette.paperSoft,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF3A2A22) : NotoPalette.ink,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
  const GlobalWallpaper({
    super.key,
    required this.store,
    required this.child,
  });

  final AppStore store;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final custom = store.customWallpaper;
    final file = custom == null ? null : File(custom);
    final hasCustom = file != null && file.existsSync();
    final hasBuiltIn = store.wallpaper > 0 &&
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
  const NotoMark({super.key, this.size = 46});
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, Color.lerp(primary, NotoPalette.emberSoft, .45)!],
        ),
        borderRadius: BorderRadius.circular(size * .31),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .24),
            blurRadius: size * .45,
            offset: Offset(0, size * .16),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        'N',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .47,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -1,
        ),
      ),
    );
  }
}

class NotoSurface extends StatelessWidget {
  const NotoSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow.withValues(alpha: .96),
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: .48),
            ),
          ),
          child: child,
        ),
      ),
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -.25,
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
    return NotoSurface(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (iconColor ?? cs.primary).withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor ?? cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurface.withValues(alpha: .5),
            ),
        ],
      ),
    );
  }
}
