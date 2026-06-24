import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppFontSizeNotifier extends StateNotifier<double> {
  AppFontSizeNotifier() : super(42.0) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('app_font_size');
      if (saved != null) {
        state = saved.clamp(12.0, 72.0);
      }
    } catch (_) {}
  }

  Future<void> setFontSize(double size) async {
    state = size.clamp(12.0, 72.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('app_font_size', state);
    } catch (_) {}
  }
}

final appFontSizeProvider = StateNotifierProvider<AppFontSizeNotifier, double>((
  ref,
) {
  return AppFontSizeNotifier();
});
