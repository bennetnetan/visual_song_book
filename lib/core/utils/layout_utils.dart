import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum LayoutMode { mobile, desktop }

LayoutMode getLayoutMode(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  final isMobilePlatform =
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  if (isMobilePlatform) return LayoutMode.mobile;
  if (width >= 900) return LayoutMode.desktop;
  return LayoutMode.mobile;
}

bool isDesktopPlatform() {
  return !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
}

bool isMobilePlatformCheck() {
  return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
}
