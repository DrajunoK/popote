import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/models.dart';

/// Couleur de fond + couleur de texte d'un badge ou d'une vignette.
class Tone {
  const Tone(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

enum HeadingFont { fraunces, inter, spaceGrotesk }

/// Design tokens d'un thème (spec §6.2). Un `ThemeExtension` par thème.
@immutable
class MijoteColors extends ThemeExtension<MijoteColors> {
  const MijoteColors({
    required this.key,
    required this.name,
    required this.hint,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.outlineStrong,
    required this.onSurface,
    required this.soft,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.inverse,
    required this.onInverse,
    required this.danger,
    required this.track,
    required this.checkOutline,
    required this.slotBreakfast,
    required this.slotLunch,
    required this.slotDinner,
    required this.tiles,
    required this.proteins,
    required this.headingFont,
    required this.headingWeight,
    required this.scrim,
  });

  final String key;
  final String name;
  final String hint;
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color outlineStrong;
  final Color onSurface;

  /// Texte secondaire à fort contraste (un cran sous `onSurface`).
  final Color soft;

  /// `on-surface-muted`.
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color onSecondary;
  final Color tertiary;
  final Color inverse;
  final Color onInverse;
  final Color danger;
  final Color track;
  final Color checkOutline;
  final Color slotBreakfast;
  final Color slotLunch;
  final Color slotDinner;
  final Color scrim;

  /// Vignettes de recettes (3 teintes en rotation).
  final List<Tone> tiles;

  /// Badges de catégorie (protéines), contraste ≥ 4.5:1 dans chaque thème.
  final Map<Protein, Tone> proteins;
  final HeadingFont headingFont;
  final FontWeight headingWeight;

  bool get isDark => brightness == Brightness.dark;

  Tone tile(int i) => tiles[i % tiles.length];

  Color slotColor(SlotKind s) => switch (s) {
        SlotKind.breakfast || SlotKind.snack => slotBreakfast,
        SlotKind.lunch => slotLunch,
        SlotKind.dinner => slotDinner,
      };

  Tone slotTone(SlotKind s) => switch (s) {
        SlotKind.breakfast || SlotKind.snack => tiles[2],
        SlotKind.lunch => tiles[1],
        SlotKind.dinner => tiles[0],
      };

  /// Style des titres (Fraunces / Inter / Space Grotesk selon le thème).
  TextStyle heading(double size, {Color? color, double? letterSpacing}) {
    final base = TextStyle(
      fontSize: size,
      fontWeight: headingWeight,
      color: color ?? onSurface,
      letterSpacing: letterSpacing,
      height: 1.15,
    );
    return switch (headingFont) {
      HeadingFont.fraunces => GoogleFonts.fraunces(textStyle: base),
      HeadingFont.inter => GoogleFonts.inter(textStyle: base),
      HeadingFont.spaceGrotesk => GoogleFonts.spaceGrotesk(textStyle: base),
    };
  }

  @override
  MijoteColors copyWith() => this;

  @override
  MijoteColors lerp(ThemeExtension<MijoteColors>? other, double t) => t < 0.5 || other is! MijoteColors ? this : other;
}

extension MijoteContext on BuildContext {
  MijoteColors get c => Theme.of(this).extension<MijoteColors>()!;
}

// ---------------------------------------------------------------------------
// Palettes
// ---------------------------------------------------------------------------

const _darkProteins = {
  Protein.veg: Tone(Color(0xFF22302A), Color(0xFF8DD3A8)),
  Protein.vegan: Tone(Color(0xFF22302A), Color(0xFF8DD3A8)),
  Protein.fish: Tone(Color(0xFF1E2C3A), Color(0xFF8CC0E8)),
  Protein.poultry: Tone(Color(0xFF3A3220), Color(0xFFF2C35B)),
  Protein.beef: Tone(Color(0xFF3A2A1C), Color(0xFFF7B57A)),
  Protein.pork: Tone(Color(0xFF3A2230), Color(0xFFF0A3BC)),
  Protein.eggs: Tone(Color(0xFF332E22), Color(0xFFE3CF9A)),
};

const _lightProteins = {
  Protein.veg: Tone(Color(0xFFDDEBDF), Color(0xFF2B5733)),
  Protein.vegan: Tone(Color(0xFFDDEBDF), Color(0xFF2B5733)),
  Protein.fish: Tone(Color(0xFFDCE8F4), Color(0xFF1D4C77)),
  Protein.poultry: Tone(Color(0xFFF6EAC4), Color(0xFF6E5105)),
  Protein.beef: Tone(Color(0xFFF6DED6), Color(0xFF8A3220)),
  Protein.pork: Tone(Color(0xFFF6DCE6), Color(0xFF85294F)),
  Protein.eggs: Tone(Color(0xFFEFE6CC), Color(0xFF63531A)),
};

const nuit = MijoteColors(
  key: 'nuit',
  name: 'Nuit',
  hint: 'Par défaut',
  brightness: Brightness.dark,
  background: Color(0xFF14161B),
  surface: Color(0xFF1E2229),
  surfaceVariant: Color(0xFF262A32),
  outline: Color(0xFF2C313A),
  outlineStrong: Color(0xFF434A55),
  onSurface: Color(0xFFF1EEE8),
  soft: Color(0xFFD4D0C8),
  muted: Color(0xFFA7ACB5),
  primary: Color(0xFFF2994A),
  onPrimary: Color(0xFF14161B),
  primaryContainer: Color(0xFF3A2A1C),
  onPrimaryContainer: Color(0xFFF7B57A),
  secondary: Color(0xFF8DD3A8),
  onSecondary: Color(0xFF14161B),
  tertiary: Color(0xFFF2C35B),
  inverse: Color(0xFFF1EEE8),
  onInverse: Color(0xFF14161B),
  danger: Color(0xFFF59A8A),
  track: Color(0xFF434A55),
  checkOutline: Color(0xFF5A616C),
  slotBreakfast: Color(0xFFF2C35B),
  slotLunch: Color(0xFF8DD3A8),
  slotDinner: Color(0xFFF2994A),
  scrim: Color(0xFF08090B),
  tiles: [
    Tone(Color(0xFF33291F), Color(0xFFF2994A)),
    Tone(Color(0xFF22302A), Color(0xFF8DD3A8)),
    Tone(Color(0xFF3A3220), Color(0xFFF2C35B)),
  ],
  proteins: _darkProteins,
  headingFont: HeadingFont.fraunces,
  headingWeight: FontWeight.w600,
);

const terracotta = MijoteColors(
  key: 'terracotta',
  name: 'Terracotta',
  hint: 'Clair, chaleureux',
  brightness: Brightness.light,
  background: Color(0xFFFBF7F1),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFF3ECE2),
  outline: Color(0xFFE4DACD),
  outlineStrong: Color(0xFFD0C0AB),
  onSurface: Color(0xFF2A2420),
  soft: Color(0xFF4A413A),
  muted: Color(0xFF6F635A),
  primary: Color(0xFFB54A33),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFF6DED6),
  onPrimaryContainer: Color(0xFFB54A33),
  secondary: Color(0xFF4A6B51),
  onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFFE0A526),
  inverse: Color(0xFF2A2420),
  onInverse: Color(0xFFFBF7F1),
  danger: Color(0xFFA8321C),
  track: Color(0xFFCBBBA6),
  checkOutline: Color(0xFF9C8C7A),
  slotBreakfast: Color(0xFF8A6A10),
  slotLunch: Color(0xFF4A6B51),
  slotDinner: Color(0xFFB54A33),
  scrim: Color(0xFF2A2420),
  tiles: [
    Tone(Color(0xFFF2E3D5), Color(0xFFB54A33)),
    Tone(Color(0xFFE3EBDD), Color(0xFF4A6B51)),
    Tone(Color(0xFFF6E7C1), Color(0xFF8A6A10)),
  ],
  proteins: _lightProteins,
  headingFont: HeadingFont.fraunces,
  headingWeight: FontWeight.w600,
);

const menthe = MijoteColors(
  key: 'menthe',
  name: 'Menthe',
  hint: 'Clair, frais',
  brightness: Brightness.light,
  background: Color(0xFFF3F7F5),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFE6EFEA),
  outline: Color(0xFFDCE7E1),
  outlineStrong: Color(0xFFB9CEC4),
  onSurface: Color(0xFF13261F),
  soft: Color(0xFF2F443A),
  muted: Color(0xFF4F6359),
  primary: Color(0xFF1F6F5C),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFD8EDE5),
  onPrimaryContainer: Color(0xFF1A5E4E),
  secondary: Color(0xFFB0452E),
  onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFFF07A5A),
  inverse: Color(0xFF13261F),
  onInverse: Color(0xFFF3F7F5),
  danger: Color(0xFFA8321C),
  track: Color(0xFFB9CEC4),
  checkOutline: Color(0xFF7E9A8D),
  slotBreakfast: Color(0xFF8A6A10),
  slotLunch: Color(0xFF1F6F5C),
  slotDinner: Color(0xFFB0452E),
  scrim: Color(0xFF13261F),
  tiles: [
    Tone(Color(0xFFD8EDE5), Color(0xFF1F6F5C)),
    Tone(Color(0xFFFFE3DA), Color(0xFFB0452E)),
    Tone(Color(0xFFE3ECF6), Color(0xFF2F5A8A)),
  ],
  proteins: _lightProteins,
  headingFont: HeadingFont.inter,
  headingWeight: FontWeight.w700,
);

const myrtille = MijoteColors(
  key: 'myrtille',
  name: 'Myrtille',
  hint: 'Vif, moderne',
  brightness: Brightness.light,
  background: Color(0xFFF5F3FF),
  surface: Color(0xFFFFFFFF),
  surfaceVariant: Color(0xFFECE9FB),
  outline: Color(0xFFE4E0F7),
  outlineStrong: Color(0xFFC9C2EE),
  onSurface: Color(0xFF1D1A33),
  soft: Color(0xFF3A3656),
  muted: Color(0xFF5E5A78),
  primary: Color(0xFF4F3FD1),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE7E3FF),
  onPrimaryContainer: Color(0xFF4F3FD1),
  secondary: Color(0xFF3A6B12),
  onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFF9BCB3C),
  inverse: Color(0xFF1D1A33),
  onInverse: Color(0xFFF5F3FF),
  danger: Color(0xFFA8321C),
  track: Color(0xFFC9C2EE),
  checkOutline: Color(0xFF8D86B8),
  slotBreakfast: Color(0xFF8A6A10),
  slotLunch: Color(0xFF3A6B12),
  slotDinner: Color(0xFF4F3FD1),
  scrim: Color(0xFF1D1A33),
  tiles: [
    Tone(Color(0xFFE7E3FF), Color(0xFF4F3FD1)),
    Tone(Color(0xFFE6F5C9), Color(0xFF3A6B12)),
    Tone(Color(0xFFFFE6D5), Color(0xFFB4531F)),
  ],
  proteins: _lightProteins,
  headingFont: HeadingFont.spaceGrotesk,
  headingWeight: FontWeight.w700,
);

const appThemes = <String, MijoteColors>{
  'nuit': nuit,
  'terracotta': terracotta,
  'menthe': menthe,
  'myrtille': myrtille,
};

MijoteColors paletteFor(String key) => appThemes[key] ?? nuit;

/// `ThemeData` Material 3 construit depuis les tokens.
ThemeData buildTheme(MijoteColors c) {
  final base = ThemeData(brightness: c.brightness, useMaterial3: true);
  final scheme = ColorScheme(
    brightness: c.brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    primaryContainer: c.primaryContainer,
    onPrimaryContainer: c.onPrimaryContainer,
    secondary: c.secondary,
    onSecondary: c.onSecondary,
    tertiary: c.tertiary,
    error: c.danger,
    onError: c.onPrimary,
    surface: c.surface,
    onSurface: c.onSurface,
    surfaceContainerHighest: c.surfaceVariant,
    outline: c.outlineStrong,
    outlineVariant: c.outline,
    inverseSurface: c.inverse,
    onInverseSurface: c.onInverse,
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: c.onSurface, displayColor: c.onSurface),
    extensions: [c],
    splashFactory: InkSparkle.splashFactory,
    dividerTheme: DividerThemeData(color: c.outline, space: 1, thickness: 1),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      modalBarrierColor: c.scrim.withAlpha(180),
      showDragHandle: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.inverse,
      contentTextStyle: TextStyle(color: c.onInverse, fontWeight: FontWeight.w500),
      actionTextColor: c.isDark ? c.primaryContainer : c.tertiary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: c.primaryContainer,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.muted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? c.onPrimaryContainer : c.muted,
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.primaryContainer,
      selectedIconTheme: IconThemeData(color: c.onPrimaryContainer),
      unselectedIconTheme: IconThemeData(color: c.muted),
      selectedLabelTextStyle: TextStyle(color: c.onPrimaryContainer, fontWeight: FontWeight.w600, fontSize: 12),
      unselectedLabelTextStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500, fontSize: 12),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary),
  );
}

/// Échelle typographique (spec §6.2) : 12 / 14 / 16 / 20 / 24 / 32.
abstract final class Radii {
  static const chip = 12.0;
  static const card = 20.0;
  static const sheet = 28.0;
}
