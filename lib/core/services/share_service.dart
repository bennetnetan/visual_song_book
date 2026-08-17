import 'package:share_plus/share_plus.dart';

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

  /// Share text via the system-native share sheet, allowing the user to
  /// choose any available app (WhatsApp, Messages, Email, etc.).
  static Future<void> shareViaWhatsApp(String text) async {
    await shareText(text, subject: 'Shared via Visual Song Book');
  }
}
