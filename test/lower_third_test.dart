import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visual_song_book/features/lower_third/lower_third_controller.dart';
import 'package:visual_song_book/features/lower_third/lower_third_state.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_config.dart';
import 'package:visual_song_book/features/lower_third/models/lower_third_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LowerThirdConfig', () {
    test('default configuration values', () {
      const config = LowerThirdConfig();
      expect(config.style, LowerThirdStyle.fullWidth);
      expect(config.isFloating, isFalse);
      expect(config.height, 64.0);
      expect(config.fontSize, 20.0);
      expect(config.fontFamily, 'Outfit');
      expect(config.fontWeight, FontWeight.w600);
      expect(config.backgroundOpacity, 0.88);
      expect(config.intervalSeconds, 8);
      expect(config.animation, LowerThirdAnimation.fade);
    });

    test('serializes and deserializes correctly via JSON', () {
      const original = LowerThirdConfig(
        style: LowerThirdStyle.fullWidth,
        height: 75.0,
        backgroundColor: Color(0xFF123456),
        backgroundOpacity: 0.75,
        textColor: Color(0xFFFEDCBA),
        fontFamily: 'Inter',
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        intervalSeconds: 12,
        animation: LowerThirdAnimation.slide,
      );

      final json = original.toJson();
      final restored = LowerThirdConfig.fromJson(json);

      expect(restored.style, LowerThirdStyle.fullWidth);
      expect(restored.isFloating, isFalse);
      expect(restored.height, 75.0);
      expect(restored.backgroundColor.toARGB32(), original.backgroundColor.toARGB32());
      expect(restored.backgroundOpacity, 0.75);
      expect(restored.textColor.toARGB32(), original.textColor.toARGB32());
      expect(restored.fontFamily, 'Inter');
      expect(restored.fontSize, 24.0);
      expect(restored.fontWeight, FontWeight.bold);
      expect(restored.intervalSeconds, 12);
      expect(restored.animation, LowerThirdAnimation.slide);
    });
  });

  group('LowerThirdItem', () {
    test('creates with UUID and default disabled status', () {
      final item = LowerThirdItem.create('Special Announcement');
      expect(item.id.isNotEmpty, isTrue);
      expect(item.text, 'Special Announcement');
      expect(item.isEnabled, isFalse);
    });

    test('JSON serialization roundtrip', () {
      final item = LowerThirdItem(
        id: 'announcement-1',
        text: 'Prayer meeting at 7pm',
        isEnabled: false,
      );

      final json = item.toJson();
      final restored = LowerThirdItem.fromJson(json);

      expect(restored.id, 'announcement-1');
      expect(restored.text, 'Prayer meeting at 7pm');
      expect(restored.isEnabled, isFalse);
    });
  });

  group('LowerThirdState', () {
    test('initial state has default sample announcements and is disabled', () {
      final state = LowerThirdState.initial();
      expect(state.isEnabled, isFalse);
      expect(state.hasActiveItem, isFalse);
      expect(state.items.isNotEmpty, isTrue);
      expect(state.enabledItems.isEmpty, isTrue);
    });

    test('hasActiveItem requires both isEnabled and a non-empty enabled item', () {
      var state = LowerThirdState.initial();
      expect(state.hasActiveItem, isFalse);

      // Enabling master toggle without any active items still has no active item
      state = state.copyWith(isEnabled: true);
      expect(state.hasActiveItem, isFalse);

      // Activating an announcement makes hasActiveItem true
      final enabledItems = state.items.map((i) => i.copyWith(isEnabled: true)).toList();
      state = state.copyWith(items: enabledItems);
      expect(state.hasActiveItem, isTrue);
      expect(state.currentItem?.text, contains('Welcome'));

      // If all items are disabled, hasActiveItem should be false
      final disabledItems = state.items.map((i) => i.copyWith(isEnabled: false)).toList();
      state = state.copyWith(items: disabledItems);
      expect(state.hasActiveItem, isFalse);
      expect(state.currentItem, isNull);
    });
  });

  group('LowerThirdController', () {
    test('toggles and sets enabled state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      expect(container.read(lowerThirdControllerProvider).isEnabled, isFalse);

      notifier.toggleEnabled();
      expect(container.read(lowerThirdControllerProvider).isEnabled, isTrue);

      notifier.setEnabled(false);
      expect(container.read(lowerThirdControllerProvider).isEnabled, isFalse);
    });

    test('adds, edits, toggles, and deletes announcements', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      final initialCount = container.read(lowerThirdControllerProvider).items.length;

      // Add
      notifier.addItem('Youth fellowship this Saturday');
      var state = container.read(lowerThirdControllerProvider);
      expect(state.items.length, initialCount + 1);
      final addedItem = state.items.last;
      expect(addedItem.text, 'Youth fellowship this Saturday');

      // Edit
      notifier.editItem(addedItem.id, 'Youth fellowship rescheduled to Sunday', true);
      state = container.read(lowerThirdControllerProvider);
      expect(state.items.last.text, 'Youth fellowship rescheduled to Sunday');

      // Toggle enabled
      notifier.toggleItemEnabled(addedItem.id);
      state = container.read(lowerThirdControllerProvider);
      expect(state.items.last.isEnabled, isFalse);

      // Delete
      notifier.deleteItem(addedItem.id);
      state = container.read(lowerThirdControllerProvider);
      expect(state.items.length, initialCount);
      expect(state.items.any((i) => i.id == addedItem.id), isFalse);
    });

    test('reorders items properly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      final itemA = container.read(lowerThirdControllerProvider).items[0];
      final itemB = container.read(lowerThirdControllerProvider).items[1];

      notifier.reorderItems(0, 1);
      final state = container.read(lowerThirdControllerProvider);
      expect(state.items[0].id, itemB.id);
      expect(state.items[1].id, itemA.id);
    });

    test('cycles items with nextItem and prevItem', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      // Enable items since default is disabled
      final items = container.read(lowerThirdControllerProvider).items;
      notifier.editItem(items[0].id, items[0].text, true);
      notifier.editItem(items[1].id, items[1].text, true);

      expect(container.read(lowerThirdControllerProvider).activeIndex, 0);

      notifier.nextItem();
      expect(container.read(lowerThirdControllerProvider).activeIndex, 1);

      notifier.nextItem();
      // Wraps back to 0
      expect(container.read(lowerThirdControllerProvider).activeIndex, 0);

      notifier.prevItem();
      // Wraps back to 1
      expect(container.read(lowerThirdControllerProvider).activeIndex, 1);
    });

    test('resetTextSettings reverts text styling to standard defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      // Customize text
      notifier.updateConfig(
        container.read(lowerThirdControllerProvider).config.copyWith(
              textColor: Colors.deepOrange,
              fontFamily: 'Lora',
              fontSize: 56.0,
              fontWeight: FontWeight.w400,
              style: LowerThirdStyle.floatingPill, // theme property
            ),
      );

      notifier.resetTextSettings();
      final config = container.read(lowerThirdControllerProvider).config;

      // Text should be back to standard
      expect(config.textColor, Colors.white);
      expect(config.fontFamily, 'Outfit');
      expect(config.fontSize, 20.0);
      expect(config.fontWeight, FontWeight.w600);
      // Theme should be preserved
      expect(config.style, LowerThirdStyle.floatingPill);
    });

    test('resetThemeSettings reverts theme and dimensions to standard defaults', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(lowerThirdControllerProvider.notifier);
      // Customize theme & text
      notifier.updateConfig(
        container.read(lowerThirdControllerProvider).config.copyWith(
              style: LowerThirdStyle.floatingPill,
              height: 120.0,
              backgroundColor: Colors.blue,
              backgroundOpacity: 0.5,
              intervalSeconds: 25,
              textColor: Colors.purple, // text property
              fontSize: 48.0, // text property
            ),
      );

      notifier.resetThemeSettings();
      final config = container.read(lowerThirdControllerProvider).config;

      // Theme should be back to standard (fullWidth)
      expect(config.style, LowerThirdStyle.fullWidth);
      expect(config.height, 64.0);
      expect(config.backgroundColor, const Color(0xFF0A1A18));
      expect(config.backgroundOpacity, 0.88);
      expect(config.intervalSeconds, 8);
      // Text properties preserved
      expect(config.textColor, Colors.purple);
      expect(config.fontSize, 48.0);
    });
  });
}
