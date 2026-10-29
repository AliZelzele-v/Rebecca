import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;

  static ColorScheme _monochrome(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final ink = dark ? Colors.white : Colors.black;
    final paper = dark ? Colors.black : Colors.white;
    return ColorScheme.fromSeed(
      seedColor: Colors.grey,
      brightness: brightness,
    ).copyWith(
      primary: ink,
      onPrimary: paper,
      primaryContainer: dark
          ? const Color(0xFF303030)
          : const Color(0xFFE0E0E0),
      onPrimaryContainer: ink,
      secondary: ink,
      onSecondary: paper,
      secondaryContainer: dark
          ? const Color(0xFF252525)
          : const Color(0xFFEEEEEE),
      onSecondaryContainer: ink,
      tertiary: ink,
      onTertiary: paper,
      tertiaryContainer: dark
          ? const Color(0xFF303030)
          : const Color(0xFFE0E0E0),
      onTertiaryContainer: ink,
      surface: paper,
      onSurface: ink,
      surfaceContainerLowest: paper,
      surfaceContainerLow: dark
          ? const Color(0xFF141414)
          : const Color(0xFFF8F8F8),
      surfaceContainer: dark
          ? const Color(0xFF1D1D1D)
          : const Color(0xFFF0F0F0),
      surfaceContainerHigh: dark
          ? const Color(0xFF282828)
          : const Color(0xFFE8E8E8),
      surfaceContainerHighest: dark
          ? const Color(0xFF333333)
          : const Color(0xFFE0E0E0),
      error: ink,
      onError: paper,
      errorContainer: const Color(0xFF505050),
      onErrorContainer: Colors.white,
      outline: Colors.grey,
    );
  }

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    final ColorScheme scheme = _monochrome(Brightness.light);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final ColorScheme scheme = _monochrome(Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : scheme.surface,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  CupertinoThemeData cupertinoThemeData(
    bool sysDark,
    ColorScheme? lightColorScheme,
    ColorScheme? darkColorScheme,
  ) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark
        ? darkTheme(darkColorScheme)
        : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(
              fontFamily: fontFamily,
            ),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(
              fontFamily: fontFamily,
            ),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(
              fontFamily: fontFamily,
            ),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle
                .copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(
              fontFamily: fontFamily,
            ),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle
                .copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(
              fontFamily: fontFamily,
            ),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
