import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_item.dart';

final _log = AppLogger.get('LowerThirdController');

class LowerThirdController extends StateNotifier<LowerThirdState> {
  final Ref ref;
  Timer? _carouselTimer;
  SharedPreferences? _prefs;

  LowerThirdController(this.ref) : super(LowerThirdState.initial()) {
    _load();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselTimer = null;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs?.getString('lower_third_state');
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        state = LowerThirdState.fromJson(decoded);
      }
    } catch (e, st) {
      _log.fine('Failed to load lower third state from preferences: $e', e, st);
    }
    _syncTimer();
  }

  Future<void> _persist(LowerThirdState newState) async {
    state = newState;
    _syncTimer();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString('lower_third_state', jsonEncode(newState.toJson()));
    } catch (e, st) {
      _log.fine('Failed to persist lower third state to preferences: $e', e, st);
    }
  }

  void _syncTimer() {
    _carouselTimer?.cancel();
    _carouselTimer = null;

    final shouldRun = state.isEnabled &&
        !state.isPaused &&
        state.enabledItems.length > 1;

    if (shouldRun) {
      final interval = Duration(
        seconds: state.config.intervalSeconds.clamp(3, 120),
      );
      _carouselTimer = Timer.periodic(interval, (_) => nextItem());
    }
  }

  void toggleEnabled() {
    _persist(state.copyWith(isEnabled: !state.isEnabled));
  }

  void setEnabled(bool enabled) {
    if (state.isEnabled == enabled) return;
    _persist(state.copyWith(isEnabled: enabled));
  }

  void updateConfig(LowerThirdConfig config) {
    _persist(state.copyWith(config: config));
  }

  void addItem(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final newItem = LowerThirdItem.create(trimmed);
    final updatedList = [...state.items, newItem];
    _persist(state.copyWith(items: updatedList));
  }

  void editItem(String id, String text, bool isEnabled) {
    final trimmed = text.trim();
    final updatedList = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(
          text: trimmed.isNotEmpty ? trimmed : item.text,
          isEnabled: isEnabled,
        );
      }
      return item;
    }).toList();
    _persist(state.copyWith(items: updatedList));
  }

  void toggleItemEnabled(String id) {
    final updatedList = state.items.map((item) {
      if (item.id == id) {
        return item.copyWith(isEnabled: !item.isEnabled);
      }
      return item;
    }).toList();
    _persist(state.copyWith(items: updatedList));
  }

  void deleteItem(String id) {
    final updatedList = state.items.where((i) => i.id != id).toList();
    _persist(
      state.copyWith(
        items: updatedList,
        activeIndex: 0,
      ),
    );
  }

  void reorderItems(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= state.items.length ||
        newIndex < 0 ||
        newIndex >= state.items.length) {
      return;
    }
    final list = List<LowerThirdItem>.from(state.items);
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _persist(state.copyWith(items: list));
  }

  void nextItem() {
    final count = state.enabledItems.length;
    if (count <= 1) return;
    final nextIdx = (state.activeIndex + 1) % count;
    state = state.copyWith(activeIndex: nextIdx);
  }

  void prevItem() {
    final count = state.enabledItems.length;
    if (count <= 1) return;
    final prevIdx = (state.activeIndex - 1 + count) % count;
    state = state.copyWith(activeIndex: prevIdx);
  }

  void setPaused(bool paused) {
    _persist(state.copyWith(isPaused: paused));
  }

  void togglePaused() {
    _persist(state.copyWith(isPaused: !state.isPaused));
  }

  void resetToDefaults() {
    _persist(LowerThirdState.initial());
  }

  /// Reverts text properties (color, font, size, weight) to default standards.
  void resetTextSettings() {
    const defaults = LowerThirdConfig();
    final updated = state.config.copyWith(
      textColor: defaults.textColor,
      fontFamily: defaults.fontFamily,
      fontSize: defaults.fontSize,
      fontWeight: defaults.fontWeight,
    );
    _persist(state.copyWith(config: updated));
  }

  /// Reverts theme properties (display style, dimensions, background, timing) to default standards.
  void resetThemeSettings() {
    const defaults = LowerThirdConfig();
    final updated = state.config.copyWith(
      style: defaults.style,
      height: defaults.height,
      backgroundColor: defaults.backgroundColor,
      backgroundOpacity: defaults.backgroundOpacity,
      intervalSeconds: defaults.intervalSeconds,
      animation: defaults.animation,
    );
    _persist(state.copyWith(config: updated));
  }
}

final lowerThirdControllerProvider =
    StateNotifierProvider<LowerThirdController, LowerThirdState>(
  (ref) => LowerThirdController(ref),
);
