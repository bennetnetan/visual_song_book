import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareService {
  /// Share plain text using the native share sheet.
  static Future<void> shareText(String text, {String? subject}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject ?? ''),
      );
    } catch (e) {
      throw Exception('Share failed: $e');
    }
  }

  /// Share text via WhatsApp. Tries to open WhatsApp directly; falls back
  /// to the generic share sheet if WhatsApp is not available.
  static Future<void> shareViaWhatsApp(String text) async {
    final encoded = Uri.encodeComponent(text);
    final url = 'https://wa.me/?text=$encoded';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (e) {
      debugPrint('WhatsApp direct launch failed: $e');
    }

    await shareText(text, subject: 'Shared via Visual Song Book');
  }
}
