/// Layout tokens. Every dimension comes from here so the whole app
/// shares one rhythm and one corner-radius language.
abstract final class AppDimens {
  // Spacing scale (4pt grid).
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space5 = 20;
  static const double space6 = 24;
  static const double space7 = 32;
  static const double space8 = 40;

  /// Horizontal page padding.
  static const double pagePadding = 20;

  // Corner radius language.
  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 20;
  static const double radiusSheet = 28;
  static const double radiusPill = 100;

  // Touch targets (spec: standard touch-safe dimensions).
  static const double minTouchTarget = 44;
  static const double buttonHeight = 52;
  static const double secondaryButtonHeight = 48;
  static const double navBarHeight = 64;

  // Level tiles.
  static const double levelTileMinSize = 56;
}
