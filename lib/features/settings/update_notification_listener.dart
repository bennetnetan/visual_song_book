import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visual_song_book/data/services/release_update_service.dart';
import 'package:visual_song_book/routing/app_router.dart';

/// Checks the published GitHub release on app launch and prompts when newer.
class UpdateNotificationListener extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const UpdateNotificationListener({
    required this.child,
    this.enabled = true,
    super.key,
  });

  @override
  State<UpdateNotificationListener> createState() =>
      _UpdateNotificationListenerState();
}

class _UpdateNotificationListenerState
    extends State<UpdateNotificationListener> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    if (kReleaseMode && widget.enabled) _waitForAppThenCheck();
  }

  Future<void> _waitForAppThenCheck() async {
    // Wait until startup setup has completed and the main router is available.
    for (var attempt = 0; attempt < 30 && mounted; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final context = appRouter.routerDelegate.navigatorKey.currentContext;
      if (context == null) continue;
      await _checkAndPrompt();
      return;
    }
  }

  Future<void> _checkAndPrompt() async {
    if (_checked || !mounted) return;
    _checked = true;
    final service = ReleaseUpdateService();
    try {
      final update = await service.checkForUpdate();
      if (!mounted || update == null) return;
      final navigatorContext =
          appRouter.routerDelegate.navigatorKey.currentContext;
      if (navigatorContext == null || !navigatorContext.mounted) return;
      await showDialog<void>(
        context: navigatorContext,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Update available'),
          content: _ReleaseDetails(update: update),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Later'),
            ),
            FilledButton.icon(
              onPressed: () => launchUrl(
                update.releaseUrl,
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Get update'),
            ),
          ],
        ),
      );
    } catch (_) {
      // Update checks are best effort and should never interrupt startup.
    } finally {
      service.close();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _ReleaseDetails extends StatelessWidget {
  final ReleaseUpdate update;

  const _ReleaseDetails({required this.update});

  @override
  Widget build(BuildContext context) {
    final notes = update.notes.trim();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${update.title} (v${update.version})'),
            if (notes.isNotEmpty) ...[const SizedBox(height: 12), Text(notes)],
            const SizedBox(height: 12),
            Text(
              'The release page provides the installer or package for your device.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
