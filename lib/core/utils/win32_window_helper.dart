import 'dart:ffi';
import 'dart:io';
import 'package:flutter/foundation.dart';

// Win32 function typedefs using standard FFI types (HWND = IntPtr)
typedef GetForegroundWindowNative = IntPtr Function();
typedef GetForegroundWindowDart = int Function();

typedef ShowWindowNative = Bool Function(IntPtr hWnd, Int32 nCmdShow);
typedef ShowWindowDart = bool Function(int hWnd, int nCmdShow);

typedef SetWindowPosNative = Bool Function(
    IntPtr hWnd, IntPtr hWndInsertAfter, Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef SetWindowPosDart = bool Function(
    int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

typedef SetWindowLongPtrWNative = IntPtr Function(IntPtr hWnd, Int32 nIndex, IntPtr dwNewLong);
typedef SetWindowLongPtrWDart = int Function(int hWnd, int nIndex, int dwNewLong);

typedef GetWindowLongPtrWNative = IntPtr Function(IntPtr hWnd, Int32 nIndex);
typedef GetWindowLongPtrWDart = int Function(int hWnd, int nIndex);

typedef GetSystemMetricsNative = Int32 Function(Int32 nIndex);
typedef GetSystemMetricsDart = int Function(int nIndex);

// Win32 constants
const int swMaximize = 3;
const int swShowMaximized = 3;
const int swRestore = 9;
const int swpShowWindow = 0x0040;
const int swpFramechanged = 0x0020;
const int hwndTop = 0;
const int hwndTopmost = -1;
const int gwlStyle = -16;

// Window styles
const int wsCaption = 0x00C00000; // WS_BORDER | WS_DLGFRAME
const int wsThickframe = 0x00040000; // WS_SIZEBOX (resizable border)
const int wsSysmenu = 0x00080000;
const int wsMaximizebox = 0x00010000;
const int wsMinimizebox = 0x00020000;

// System metrics
const int smCxscreen = 0;
const int smCyscreen = 1;

class Win32WindowHelper {
  static final _user32 = DynamicLibrary.open('user32.dll');

  static final _getForegroundWindow =
      _user32.lookupFunction<GetForegroundWindowNative, GetForegroundWindowDart>(
          'GetForegroundWindow');

  static final _showWindow =
      _user32.lookupFunction<ShowWindowNative, ShowWindowDart>('ShowWindow');

  static final _setWindowPos =
      _user32.lookupFunction<SetWindowPosNative, SetWindowPosDart>(
          'SetWindowPos');

  static final _setWindowLongPtrW =
      _user32.lookupFunction<SetWindowLongPtrWNative, SetWindowLongPtrWDart>(
          'SetWindowLongPtrW');

  static final _getWindowLongPtrW =
      _user32.lookupFunction<GetWindowLongPtrWNative, GetWindowLongPtrWDart>(
          'GetWindowLongPtrW');

  static final _getSystemMetrics =
      _user32.lookupFunction<GetSystemMetricsNative, GetSystemMetricsDart>(
          'GetSystemMetrics');

  static int getActiveWindowHandle() {
    return _getForegroundWindow();
  }

  static bool maximizeWindow(int hwnd) {
    return _showWindow(hwnd, swMaximize);
  }

  static int getWindowStyle(int hwnd) {
    return _getWindowLongPtrW(hwnd, gwlStyle);
  }

  static int setWindowStyle(int hwnd, int style) {
    if (hwnd == 0) return 0;
    return _setWindowLongPtrW(hwnd, gwlStyle, style);
  }

  static int getSystemMetrics(int nIndex) {
    return _getSystemMetrics(nIndex);
  }

  static bool setWindowBounds(int hwnd, int x, int y, int width, int height,
      {bool topmost = false, bool frameChanged = false}) {
    if (hwnd == 0) return false;
    final flags = swpShowWindow | (frameChanged ? swpFramechanged : 0);
    return _setWindowPos(
          hwnd,
          topmost ? hwndTopmost : hwndTop,
          x,
          y,
          width,
          height,
          flags);
  }

  static bool fullscreenWindow(int hwnd, {bool topmost = false}) {
    return _setWindowPos(
          hwnd,
          topmost ? hwndTopmost : hwndTop,
          0,
          0,
          1920,
          1080,
          swpShowWindow);
  }

  /// Enters true borderless fullscreen by stripping the title bar and
  /// resizing the window to fill the screen. Returns the original window
  /// style so it can be restored later.
  static int enterBorderlessFullscreen(int hwnd) {
    if (hwnd == 0) return 0;
    final originalStyle = getWindowStyle(hwnd);

    // Remove title bar, thick frame (resize border), system menu,
    // minimize/maximize boxes — everything that adds chrome
    final newStyle = originalStyle &
        ~(wsCaption | wsThickframe | wsSysmenu | wsMaximizebox | wsMinimizebox);
    setWindowStyle(hwnd, newStyle);

    // Get current monitor's screen dimensions
    final screenWidth = getSystemMetrics(smCxscreen);
    final screenHeight = getSystemMetrics(smCyscreen);

    // Position at (0,0) covering the entire screen, with frame change
    setWindowBounds(hwnd, 0, 0, screenWidth, screenHeight,
        frameChanged: true);

    return originalStyle;
  }

  /// Restores original window style after leaving borderless fullscreen.
  static void exitBorderlessFullscreen(int hwnd, int originalStyle) {
    setWindowStyle(hwnd, originalStyle);
    final screenWidth = getSystemMetrics(smCxscreen);
    final screenHeight = getSystemMetrics(smCyscreen);
    setWindowBounds(hwnd, 0, 0, screenWidth, screenHeight,
        frameChanged: true);
  }
}

/// Attempts to maximize the current window using Win32 APIs.
/// This is needed because `window_manager` plugin is not registered in
/// `desktop_multi_window` secondary engines on Windows.
Future<void> maximizeCurrentWindow({bool topmost = false}) async {
  if (!Platform.isWindows) return;

  try {
    final hwnd = Win32WindowHelper.getActiveWindowHandle();
    if (hwnd == 0) {
      // Try again after a short delay - the window may not be active yet
      await Future.delayed(const Duration(milliseconds: 200));
      final hwnd2 = Win32WindowHelper.getActiveWindowHandle();
      if (hwnd2 == 0) return;
      Win32WindowHelper.maximizeWindow(hwnd2);
      if (topmost) {
        Win32WindowHelper.setWindowBounds(hwnd2, 0, 0, 1920, 1080,
            topmost: true);
      }
      return;
    }
    Win32WindowHelper.maximizeWindow(hwnd);
    if (topmost) {
      Win32WindowHelper.setWindowBounds(hwnd, 0, 0, 1920, 1080, topmost: true);
    }
  } catch (e) {
    // Best effort - don't crash if Win32 calls fail
  }
}

/// Enters true borderless fullscreen on the current window.
/// Strips the title bar and sizes the window to the full screen.
/// Returns the original style handle for restoration, or 0 on failure.
Future<int> enterBorderlessFullscreenCurrentWindow() async {
  if (!Platform.isWindows) return 0;

  for (var attempt = 0; attempt < 5; attempt++) {
    try {
      final hwnd = Win32WindowHelper.getActiveWindowHandle();
      if (hwnd == 0) {
        await Future.delayed(const Duration(milliseconds: 150));
        continue;
      }
      return Win32WindowHelper.enterBorderlessFullscreen(hwnd);
    } catch (e) {
      debugPrint('enterBorderlessFullscreen attempt $attempt failed: $e');
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }
  return 0;
}

/// Restores the window style and position after borderless fullscreen.
void exitBorderlessFullscreenCurrentWindow(int originalStyle) {
  if (!Platform.isWindows || originalStyle == 0) return;

  try {
    final hwnd = Win32WindowHelper.getActiveWindowHandle();
    if (hwnd == 0) return;
    Win32WindowHelper.exitBorderlessFullscreen(hwnd, originalStyle);
  } catch (e) {
    debugPrint('exitBorderlessFullscreen error: $e');
  }
}
