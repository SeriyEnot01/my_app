import 'dart:io';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visual themes. Every colour in the app comes from the active palette through [C],
/// so switching a theme rebuilds the whole interface in new colours.
/// Ornament painted over the background. [fog] drifting mist bands, [scan] scanlines only,
/// [petals] a few red petals.
enum Decor { none, sakura, grid, embers, neon, fog, scan, petals }

class AppPalette {
  const AppPalette({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.line,
    required this.fg,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentInk,
    required this.deadline,
    required this.overdue,
    required this.workout,
    required this.workoutInk,
    required this.sun,
    required this.lilac,
    required this.hero,
    required this.glows,
    required this.displayFont,
    required this.displayWeight,
    this.decor = Decor.none,
    this.displayScale = 1.0,
    this.bgAsset,
    this.scrim = .55,
    this.customHint = false,
  });
  final String id, name, subtitle;
  final Color bg, surface, surface2, line, fg, muted, faint;
  final Color accent, accentInk, deadline, overdue, workout, workoutInk, sun, lilac;
  /// 3 colours of the big greeting card.
  final List<Color> hero;
  /// 3 soft background glows.
  final List<Color> glows;
  final String displayFont;
  final FontWeight displayWeight;
  final double displayScale;
  final Decor decor;
  /// Picture behind the interface (already blurred), e.g. 'assets/bg/mist_castle.jpg'.
  final String? bgAsset;
  /// Default darkening of a background picture, 0..1.
  final double scrim;
  /// The theme is meant for the user's own picture (shown as a hint in settings).
  final bool customHint;
}

const palettes = <AppPalette>[
  AppPalette(
    id: 'night',
    name: 'Ночь',
    subtitle: 'Спокойный тёмный, как на сайте',
    bg: Color(0xFF0E1016), surface: Color(0xFF161923), surface2: Color(0xFF1D2130), line: Color(0xFF2A2F40),
    fg: Color(0xFFE9EAF2), muted: Color(0xFF8A8FA6), faint: Color(0xFF5A5F74),
    accent: Color(0xFF9AA5FF), accentInk: Color(0xFF11142A), deadline: Color(0xFFFF9466), overdue: Color(0xFFFF5F7E),
    workout: Color(0xFF4FD6C4), workoutInk: Color(0xFF06221E), sun: Color(0xFFFFC46B), lilac: Color(0xFFC6A8FF),
    hero: [Color(0xFF262C58), Color(0xFF1A1D2D), Color(0xFF15302E)],
    glows: [Color(0x299AA5FF), Color(0x124FD6C4), Color(0x14C6A8FF)],
    displayFont: 'Unbounded', displayWeight: FontWeight.w700,
  ),
  AppPalette(
    id: 'sakura',
    name: 'Сакура',
    subtitle: 'Аниме-вечер: розовый, лаванда, лепестки',
    bg: Color(0xFF17101D), surface: Color(0xFF221829), surface2: Color(0xFF2C2035), line: Color(0xFF3E2D4A),
    fg: Color(0xFFFCEFF7), muted: Color(0xFFB9A0C4), faint: Color(0xFF7D6889),
    accent: Color(0xFFFF8FC8), accentInk: Color(0xFF2B0B1D), deadline: Color(0xFFFFB27A), overdue: Color(0xFFFF5C8A),
    workout: Color(0xFF7FE3D4), workoutInk: Color(0xFF07231F), sun: Color(0xFFFFD38A), lilac: Color(0xFFB79CFF),
    hero: [Color(0xFF5A1F55), Color(0xFF2B1B3A), Color(0xFF1C2A4D)],
    glows: [Color(0x33FF8FC8), Color(0x1FB79CFF), Color(0x1A7FE3D4)],
    displayFont: 'Comfortaa', displayWeight: FontWeight.w700, displayScale: 1.06,
    decor: Decor.sakura,
  ),
  AppPalette(
    id: 'gamer',
    name: 'Игровая',
    subtitle: 'Как в игровом лаунчере: сталь и голубой неон',
    bg: Color(0xFF0E151F), surface: Color(0xFF16212F), surface2: Color(0xFF1D2B3D), line: Color(0xFF2A3C53),
    fg: Color(0xFFE4EDF6), muted: Color(0xFF8EA3BA), faint: Color(0xFF5A6E86),
    accent: Color(0xFF66C0F4), accentInk: Color(0xFF052032), deadline: Color(0xFFF5A623), overdue: Color(0xFFE5484D),
    workout: Color(0xFFA4D007), workoutInk: Color(0xFF1A2400), sun: Color(0xFFFFC857), lilac: Color(0xFF8C9EFF),
    hero: [Color(0xFF1B3B60), Color(0xFF15233A), Color(0xFF102D2F)],
    glows: [Color(0x2966C0F4), Color(0x14A4D007), Color(0x148C9EFF)],
    displayFont: 'RussoOne', displayWeight: FontWeight.w400, displayScale: 1.04,
    decor: Decor.grid,
  ),
  AppPalette(
    id: 'fantasy',
    name: 'Тёмное фэнтези',
    subtitle: 'Обсидиан, золото и угли костра',
    bg: Color(0xFF0C0909), surface: Color(0xFF161011), surface2: Color(0xFF201618), line: Color(0xFF3A2628),
    fg: Color(0xFFF1E6D6), muted: Color(0xFFAB978A), faint: Color(0xFF6E5C54),
    accent: Color(0xFFD9A84E), accentInk: Color(0xFF1F1405), deadline: Color(0xFFE07A3F), overdue: Color(0xFFD23C46),
    workout: Color(0xFF79B98F), workoutInk: Color(0xFF0B1F12), sun: Color(0xFFF0C46A), lilac: Color(0xFFA584DA),
    hero: [Color(0xFF45141A), Color(0xFF1F1315), Color(0xFF1A140B)],
    glows: [Color(0x2ED9A84E), Color(0x22D23C46), Color(0x14A584DA)],
    displayFont: 'CormorantSC', displayWeight: FontWeight.w700, displayScale: 1.28,
    decor: Decor.embers,
  ),
  AppPalette(
    id: 'neon',
    name: 'Неон',
    subtitle: 'Киберпанк: бирюза и маджента',
    bg: Color(0xFF07070D), surface: Color(0xFF11111C), surface2: Color(0xFF181827), line: Color(0xFF2A2A44),
    fg: Color(0xFFEDEBFF), muted: Color(0xFF9592C2), faint: Color(0xFF5E5B86),
    accent: Color(0xFF00E5FF), accentInk: Color(0xFF00222A), deadline: Color(0xFFFF9F43), overdue: Color(0xFFFF2E88),
    workout: Color(0xFF3CFFB1), workoutInk: Color(0xFF00281A), sun: Color(0xFFFFE066), lilac: Color(0xFFD16BFF),
    hero: [Color(0xFF3B0D5C), Color(0xFF15122B), Color(0xFF052E3A)],
    glows: [Color(0x33FF2E88), Color(0x2900E5FF), Color(0x1FD16BFF)],
    displayFont: 'Unbounded', displayWeight: FontWeight.w700,
    decor: Decor.neon,
  ),
  AppPalette(
    id: 'mistcastle',
    name: 'Туманная крепость',
    subtitle: 'Замок на скале в тумане: серый и мох',
    bg: Color(0xFF0F1513), surface: Color(0xFF17201C), surface2: Color(0xFF1F2925), line: Color(0xFF34423B),
    fg: Color(0xFFE6ECE6), muted: Color(0xFF9DAAA2), faint: Color(0xFF64716A),
    accent: Color(0xFFA3C9AA), accentInk: Color(0xFF0C1A10), deadline: Color(0xFFD9B66C), overdue: Color(0xFFD26A60),
    workout: Color(0xFF7FB9B1), workoutInk: Color(0xFF082020), sun: Color(0xFFE6CF8E), lilac: Color(0xFFABA6CB),
    hero: [Color(0xFF2E3D35), Color(0xFF1A2320), Color(0xFF232E2B)],
    glows: [Color(0x1FA3C9AA), Color(0x10D9B66C), Color(0x10ABA6CB)],
    displayFont: 'CormorantSC', displayWeight: FontWeight.w700, displayScale: 1.28,
    decor: Decor.fog, bgAsset: 'assets/bg/mist_castle.jpg', scrim: .42,
  ),
  AppPalette(
    id: 'knight',
    name: 'Страж',
    subtitle: 'Рыцарь над туманной долиной',
    bg: Color(0xFF111512), surface: Color(0xFF191F1A), surface2: Color(0xFF212922), line: Color(0xFF364238),
    fg: Color(0xFFE8ECE3), muted: Color(0xFFA0AA9B), faint: Color(0xFF677164),
    accent: Color(0xFF9DBF77), accentInk: Color(0xFF111C06), deadline: Color(0xFFCFA653), overdue: Color(0xFFC75F52),
    workout: Color(0xFF86B8A6), workoutInk: Color(0xFF0A1F18), sun: Color(0xFFE2C77F), lilac: Color(0xFFA9AFC2),
    hero: [Color(0xFF34402D), Color(0xFF1B211C), Color(0xFF262C25)],
    glows: [Color(0x1F9DBF77), Color(0x10CFA653), Color(0x10A9AFC2)],
    displayFont: 'CormorantSC', displayWeight: FontWeight.w700, displayScale: 1.28,
    decor: Decor.fog, bgAsset: 'assets/bg/knight_field.jpg', scrim: .40,
  ),
  AppPalette(
    id: 'stormkeep',
    name: 'Штормовая цитадель',
    subtitle: 'Замок над скалами и тёмным озером, грозовое небо',
    bg: Color(0xFF0D0F11), surface: Color(0xFF15191C), surface2: Color(0xFF1C2125), line: Color(0xFF30373D),
    fg: Color(0xFFE6EAEE), muted: Color(0xFF9AA4AD), faint: Color(0xFF616B74),
    accent: Color(0xFFB9C7D4), accentInk: Color(0xFF12171C), deadline: Color(0xFFD6A75E), overdue: Color(0xFFC9564E),
    workout: Color(0xFF7FB0A2), workoutInk: Color(0xFF0A1E19), sun: Color(0xFFE3C77E), lilac: Color(0xFF9C9BC6),
    hero: [Color(0xFF2B333B), Color(0xFF171B1F), Color(0xFF22292B)],
    glows: [Color(0x1FB9C7D4), Color(0x10D6A75E), Color(0x109C9BC6)],
    displayFont: 'CormorantSC', displayWeight: FontWeight.w700, displayScale: 1.28,
    decor: Decor.fog, bgAsset: 'assets/bg/storm_keep.jpg', scrim: .35,
  ),
  AppPalette(
    id: 'sunset_knight',
    name: 'Закатный рыцарь',
    subtitle: 'Рыцарь в поле цветов, замок в огне заката',
    bg: Color(0xFF120D0C), surface: Color(0xFF1B1413), surface2: Color(0xFF241B19), line: Color(0xFF3E2E2A),
    fg: Color(0xFFF6EADF), muted: Color(0xFFBCA294), faint: Color(0xFF7E665B),
    accent: Color(0xFFF0A06C), accentInk: Color(0xFF2A1206), deadline: Color(0xFFF2C46A), overdue: Color(0xFFE0565E),
    workout: Color(0xFF8FB27A), workoutInk: Color(0xFF13200B), sun: Color(0xFFFFD08A), lilac: Color(0xFFE58FB0),
    hero: [Color(0xFF5A2A1E), Color(0xFF24191A), Color(0xFF3A2730)],
    glows: [Color(0x1FF0A06C), Color(0x14E0565E), Color(0x10E58FB0)],
    displayFont: 'CormorantSC', displayWeight: FontWeight.w700, displayScale: 1.28,
    decor: Decor.embers, bgAsset: 'assets/bg/sunset_knight.jpg', scrim: .45,
  ),
  AppPalette(
    id: 'cyber',
    name: 'Киберпанк',
    subtitle: 'Ночной город, дождь и неон',
    bg: Color(0xFF0A0812), surface: Color(0xFF130F1F), surface2: Color(0xFF1B152B), line: Color(0xFF302647),
    fg: Color(0xFFF3EEFF), muted: Color(0xFFA89DCB), faint: Color(0xFF6B608E),
    accent: Color(0xFFFCEE0A), accentInk: Color(0xFF1A1700), deadline: Color(0xFFFF9F43), overdue: Color(0xFFFF2E88),
    workout: Color(0xFF00F0FF), workoutInk: Color(0xFF00262A), sun: Color(0xFFFFE066), lilac: Color(0xFFC56BFF),
    hero: [Color(0xFF3D0E52), Color(0xFF151026), Color(0xFF07303D)],
    glows: [Color(0x26FF2E88), Color(0x2000F0FF), Color(0x14FCEE0A)],
    displayFont: 'Exo2', displayWeight: FontWeight.w700, displayScale: 1.04,
    decor: Decor.scan, bgAsset: 'assets/bg/cyber_city.jpg', scrim: .38,
  ),
  AppPalette(
    id: 'cyber_girl',
    name: 'Киберпанк: героиня',
    subtitle: 'Переливы бирюзы и розового. Поставьте свой арт фоном',
    bg: Color(0xFF080A12), surface: Color(0xFF10131F), surface2: Color(0xFF171B2B), line: Color(0xFF2A3047),
    fg: Color(0xFFEFF6FF), muted: Color(0xFF9CA8CC), faint: Color(0xFF5F6A8E),
    accent: Color(0xFF7EF6FF), accentInk: Color(0xFF00232A), deadline: Color(0xFFFFB86B), overdue: Color(0xFFFF4F9A),
    workout: Color(0xFFB8FF6B), workoutInk: Color(0xFF172800), sun: Color(0xFFFFE38A), lilac: Color(0xFFFF8AD8),
    hero: [Color(0xFF16405A), Color(0xFF151A2E), Color(0xFF4A1745)],
    glows: [Color(0x267EF6FF), Color(0x22FF8AD8), Color(0x14B8FF6B)],
    displayFont: 'Exo2', displayWeight: FontWeight.w700, displayScale: 1.04,
    decor: Decor.scan, bgAsset: 'assets/bg/cyber_city.jpg', scrim: .42, customHint: true,
  ),
  AppPalette(
    id: 'titan',
    name: 'За стенами',
    subtitle: 'Золотое поле, огромная стена, алый шарф',
    bg: Color(0xFF14110D), surface: Color(0xFF1D1914), surface2: Color(0xFF27211A), line: Color(0xFF41382B),
    fg: Color(0xFFF4ECDC), muted: Color(0xFFB8AA90), faint: Color(0xFF7A6E5A),
    accent: Color(0xFFD9473C), accentInk: Color(0xFFFFF4EC), deadline: Color(0xFFE2AA4C), overdue: Color(0xFFF0603F),
    workout: Color(0xFF7FA05A), workoutInk: Color(0xFF0F1A08), sun: Color(0xFFF2C86C), lilac: Color(0xFF95A8BC),
    hero: [Color(0xFF4E2418), Color(0xFF241D15), Color(0xFF2C3524)],
    glows: [Color(0x1FD9473C), Color(0x18E2AA4C), Color(0x1095A8BC)],
    displayFont: 'Oswald', displayWeight: FontWeight.w600, displayScale: 1.1,
    decor: Decor.petals, bgAsset: 'assets/bg/walls_field.jpg', scrim: .62, customHint: true,
  ),
];

AppPalette paletteById(String? id) => palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

/// Current colours. Read at build time, so widgets pick up a new theme on rebuild.
class C {
  static AppPalette p = palettes.first;
  static Color get bg => p.bg;
  static Color get surface => p.surface;
  static Color get surface2 => p.surface2;
  static Color get line => p.line;
  static Color get fg => p.fg;
  static Color get muted => p.muted;
  static Color get faint => p.faint;
  static Color get accent => p.accent;
  static Color get accentInk => p.accentInk;
  static Color get deadline => p.deadline;
  static Color get overdue => p.overdue;
  static Color get workout => p.workout;
  static Color get workoutInk => p.workoutInk;
  static Color get sun => p.sun;
  static Color get lilac => p.lilac;

  /// The user's own picture for the current theme (a file on this device), if any.
  static String? customBg;
  /// True when a picture is behind the interface: panels become translucent.
  static bool get glass => customBg != null || p.bgAsset != null;
  /// Surface colour for cards: translucent over a picture.
  static Color card([double opacity = .78]) => glass ? p.surface.withOpacity(opacity) : p.surface;
}

/// Display face for headings and big numbers (each theme has its own).
TextStyle display(double size, {FontWeight? weight, Color? color}) => TextStyle(
      fontFamily: C.p.displayFont,
      fontSize: size * C.p.displayScale,
      fontWeight: C.p.displayFont == 'Unbounded' ? (weight ?? FontWeight.w500) : C.p.displayWeight,
      color: color ?? C.fg,
      letterSpacing: C.p.displayFont == 'CormorantSC' ? .6 : .2,
      height: 1.15,
    );

/// Saves the chosen theme on this device and rebuilds the app when it changes.
///
/// Each theme can also have the user's own background picture. It is copied into the app's
/// private folder on this device and never synced or uploaded.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    C.p = paletteById(_prefs.getString('theme.id'));
    C.customBg = customBg(C.p.id);
  }
  final SharedPreferences _prefs;
  static const maxPictureBytes = 30 * 1024 * 1024;

  String get id => C.p.id;

  void select(String id) {
    if (id == C.p.id) return;
    C.p = paletteById(id);
    C.customBg = customBg(id);
    _prefs.setString('theme.id', id);
    notifyListeners();
  }

  /// Path of the user's picture for a theme, if it still exists.
  String? customBg(String themeId) {
    final path = _prefs.getString('theme.bg.$themeId');
    if (path == null) return null;
    try {
      return File(path).existsSync() ? path : null;
    } catch (_) {
      return null;
    }
  }

  /// Extra blur of the background picture (logical pixels).
  double blur(String themeId) => _prefs.getDouble('theme.blur.$themeId') ?? (customBg(themeId) != null ? 6 : 0);

  /// Darkening of the background picture, 0..0.9.
  double dim(String themeId) => _prefs.getDouble('theme.dim.$themeId') ?? paletteById(themeId).scrim;

  void setBlur(double v) {
    _prefs.setDouble('theme.blur.${C.p.id}', v);
    notifyListeners();
  }

  void setDim(double v) {
    _prefs.setDouble('theme.dim.${C.p.id}', v);
    notifyListeners();
  }

  /// Saves picture bytes as the current theme's background. Returns an error text or null.
  Future<String?> setCustomBg(List<int> bytes, String extension) async {
    if (bytes.isEmpty) return 'Файл пустой';
    if (bytes.length > maxPictureBytes) return 'Картинка больше 30 МБ, выберите поменьше';
    final ext = extension.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (!const ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp'].contains(ext)) return 'Нужна картинка JPG, PNG или WEBP';
    final themeId = C.p.id;
    final dir = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}backgrounds');
    await dir.create(recursive: true);
    // a new name each time, so the image cache never shows the old picture
    final file = File('${dir.path}${Platform.pathSeparator}${themeId}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await file.writeAsBytes(bytes, flush: true);
    await _deleteOld(themeId);
    await _prefs.setString('theme.bg.$themeId', file.path);
    if (_prefs.getDouble('theme.blur.$themeId') == null) await _prefs.setDouble('theme.blur.$themeId', 6);
    C.customBg = file.path;
    notifyListeners();
    return null;
  }

  Future<void> removeCustomBg() async {
    final themeId = C.p.id;
    await _deleteOld(themeId);
    await _prefs.remove('theme.bg.$themeId');
    await _prefs.remove('theme.blur.$themeId');
    C.customBg = null;
    notifyListeners();
  }

  Future<void> _deleteOld(String themeId) async {
    final old = _prefs.getString('theme.bg.$themeId');
    if (old == null) return;
    try {
      final f = File(old);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}

ThemeData buildTheme() {
  final radius10 = BorderRadius.circular(10);
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Onest',
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: C.accent,
      onPrimary: C.accentInk,
      secondary: C.workout,
      onSecondary: C.workoutInk,
      surface: C.surface,
      onSurface: C.fg,
      error: C.overdue,
    ),
    scaffoldBackgroundColor: C.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.fg, displayColor: C.fg),
    dividerColor: C.line,
    appBarTheme: AppBarTheme(
      backgroundColor: C.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: C.fg,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.bg,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      labelStyle: TextStyle(color: C.muted),
      floatingLabelStyle: TextStyle(color: C.accent),
      hintStyle: TextStyle(color: C.faint),
      border: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: C.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: C.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius10, borderSide: BorderSide(color: C.accent)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.accent,
        foregroundColor: C.accentInk,
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: radius10),
        textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.fg,
        side: BorderSide(color: C.line),
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: radius10),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: C.accent),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      side: BorderSide(color: C.faint, width: 1.5),
    ),
    dialogTheme: DialogTheme(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: C.surface, surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(color: C.surface2, surfaceTintColor: Colors.transparent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: C.surface2,
      contentTextStyle: TextStyle(color: C.fg),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

const tabular = [FontFeature.tabularFigures()];
