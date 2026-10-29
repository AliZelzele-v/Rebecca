import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/theme/app_theme.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';

void main() {
  test('device accent does not override the monochrome black theme', () {
    final theme = AppTheme(AppThemeMode.black, 'sans-serif').darkTheme(
      ColorScheme.fromSeed(
        seedColor: Colors.purple,
        brightness: Brightness.dark,
      ),
    );
    expect(theme.scaffoldBackgroundColor, Colors.black);
    expect(theme.colorScheme.primary, Colors.white);
    expect(theme.colorScheme.onPrimary, Colors.black);
    for (final color in [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.surface,
    ]) {
      expect(color.r, color.g);
      expect(color.g, color.b);
    }
  });
}
