import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';

final _log = AppLogger.get('ThemeProvider');

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt('theme_mode');
      if (saved != null) {
        state = ThemeMode.values[saved];
      }
    } catch (e, st) {
      _log.fine('Failed to load theme mode from preferences: $e', e, st);
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('theme_mode', mode.index);
    } catch (e, st) {
      _log.fine('Failed to persist theme mode to preferences: $e', e, st);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((
  ref,
) {
  return ThemeNotifier();
});
