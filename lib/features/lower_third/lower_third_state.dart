import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_item.dart';

/// State of the lower thirds carousel, including active item and configuration.
class LowerThirdState {
  final bool isEnabled;
  final List<LowerThirdItem> items;
  final int activeIndex;
  final LowerThirdConfig config;
  final bool isPaused;

  const LowerThirdState({
    required this.isEnabled,
    required this.items,
    required this.activeIndex,
    required this.config,
    this.isPaused = false,
  });

  List<LowerThirdItem> get enabledItems =>
      items.where((i) => i.isEnabled && i.text.trim().isNotEmpty).toList();

  LowerThirdItem? get currentItem {
    final active = enabledItems;
    if (active.isEmpty) return null;
    final idx = activeIndex.clamp(0, active.length - 1);
    return active[idx];
  }

  bool get hasActiveItem => isEnabled && currentItem != null;

  LowerThirdState copyWith({
    bool? isEnabled,
    List<LowerThirdItem>? items,
    int? activeIndex,
    LowerThirdConfig? config,
    bool? isPaused,
  }) {
    return LowerThirdState(
      isEnabled: isEnabled ?? this.isEnabled,
      items: items ?? this.items,
      activeIndex: activeIndex ?? this.activeIndex,
      config: config ?? this.config,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  factory LowerThirdState.initial() {
    return LowerThirdState(
      isEnabled: false,
      items: [
        LowerThirdItem.create('Welcome to our service! We are glad you are here.'),
        LowerThirdItem.create('Please remember to silence your mobile devices during the service.'),
      ],
      activeIndex: 0,
      config: const LowerThirdConfig(),
      isPaused: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'items': items.map((i) => i.toJson()).toList(),
      'activeIndex': activeIndex,
      'config': config.toJson(),
      'isPaused': isPaused,
    };
  }

  factory LowerThirdState.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final items = rawItems
        .map((e) => LowerThirdItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return LowerThirdState(
      isEnabled: (json['isEnabled'] as bool?) ?? false,
      items: items.isNotEmpty
          ? items
          : LowerThirdState.initial().items,
      activeIndex: (json['activeIndex'] as int?) ?? 0,
      config: json['config'] != null
          ? LowerThirdConfig.fromJson(
              Map<String, dynamic>.from(json['config'] as Map),
            )
          : const LowerThirdConfig(),
      isPaused: (json['isPaused'] as bool?) ?? false,
    );
  }
}
