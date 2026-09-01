import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';

final _log = AppLogger.get('AppFontScale');

class AppFontScaleNotifier extends StateNotifier<double> {
  AppFontScaleNotifier() : super(defaultScale) {
    _load();
  }

  static const _key = 'app_font_scale';
  static const defaultScale = 1.0;
  static const minScale = 0.8;
  static const maxScale = 1.6;

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(_key);
      if (saved != null && saved >= minScale && saved <= maxScale) {
        state = saved;
      }
    } catch (e, st) {
      _log.fine('Failed to load app font scale from preferences: $e', e, st);
    }
  }

  Future<void> setScale(double scale) async {
    final clamped = scale.clamp(minScale, maxScale).toDouble();
    state = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, clamped);
    } catch (e, st) {
      _log.fine('Failed to persist app font scale to preferences: $e', e, st);
    }
  }
}

final appFontScaleProvider =
    StateNotifierProvider<AppFontScaleNotifier, double>((ref) {
  return AppFontScaleNotifier();
});
