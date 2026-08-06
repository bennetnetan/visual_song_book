import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:visual_song_book/core/utils/app_logger.dart';

final _log = AppLogger.get('Win32WindowHelper');

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

// Process / thread functions for HWND discovery
typedef GetCurrentProcessIdNative = Uint32 Function();
typedef GetCurrentProcessIdDart = int Function();

typedef GetWindowThreadProcessIdNative = Uint32 Function(IntPtr hWnd, Pointer<Int32> lpdwProcessId);
typedef GetWindowThreadProcessIdDart = int Function(int hWnd, Pointer<Int32> lpdwProcessId);

typedef IsWindowVisibleNative = Bool Function(IntPtr hWnd);
typedef IsWindowVisibleDart = bool Function(int hWnd);

// EnumWindows callback
typedef EnumWindowsNative = Bool Function(Pointer<NativeFunction<EnumWindowsProcNative>> lpEnumFunc, IntPtr lParam);
typedef EnumWindowsDart = bool Function(Pointer<NativeFunction<EnumWindowsProcNative>> lpEnumFunc, int lParam);

typedef EnumWindowsProcNative = Bool Function(IntPtr hWnd, IntPtr lParam);

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
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _getForegroundWindow =
      _user32.lookupFunction<GetForegroundWindowNative, GetForegroundWindowDart>(
          'GetForegroundWindow');

  static final _showWindow =
      _user32.lookupFunction<ShowWindowNative, ShowWindowDart>('ShowWindow');

  static final _setWindowPos = _user32.lookupFunction<SetWindowPosNative, SetWindowPosDart>(
      'SetWindowPos');

  static final _setWindowLongPtrW = _user32.lookupFunction<SetWindowLongPtrWNative, SetWindowLongPtrWDart>(
      'SetWindowLongPtrW');

  static final _getWindowLongPtrW = _user32.lookupFunction<GetWindowLongPtrWNative, GetWindowLongPtrWDart>(
      'GetWindowLongPtrW');

  static final _getSystemMetrics = _user32.lookupFunction<GetSystemMetricsNative, GetSystemMetricsDart>(
      'GetSystemMetrics');

  // Cached lookups for HWND discovery (avoid repeated FFI lookups)
  // GetCurrentProcessId is in kernel32.dll, not user32.dll!
  static final _getCurrentProcessId = _kernel32
      .lookupFunction<GetCurrentProcessIdNative, GetCurrentProcessIdDart>(
          'GetCurrentProcessId');

  static final _getWindowThreadProcessId = _user32
      .lookupFunction<GetWindowThreadProcessIdNative,
          GetWindowThreadProcessIdDart>('GetWindowThreadProcessId');

  static final _isWindowVisible = _user32
      .lookupFunction<IsWindowVisibleNative, IsWindowVisibleDart>(
          'IsWindowVisible');

  static final _enumWindowsNative = _user32
      .lookupFunction<EnumWindowsNative, EnumWindowsDart>('EnumWindows');

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

  // Monitor detection FFI
  static final _monitorFromWindow = _user32.lookupFunction<
      IntPtr Function(IntPtr hwnd, Uint32 dwFlags),
      int Function(int hwnd, int dwFlags)>('MonitorFromWindow');

  static final _getMonitorInfoW = _user32.lookupFunction<
      Bool Function(IntPtr hMonitor, Pointer<Uint8> lpmi),
      bool Function(int hMonitor, Pointer<Uint8> lpmi)>('GetMonitorInfoW');

  /// Enters true borderless fullscreen by stripping the title bar and
  /// resizing the window to fill the monitor containing the window.
  /// Returns the original window style so it can be restored later.
  static int enterBorderlessFullscreen(int hwnd) {
    if (hwnd == 0) return 0;
    final originalStyle = getWindowStyle(hwnd);

    // Remove title bar, thick frame (resize border), system menu,
    // minimize/maximize boxes — everything that adds chrome
    final newStyle = originalStyle &
        ~(wsCaption | wsThickframe | wsSysmenu | wsMaximizebox | wsMinimizebox);
    setWindowStyle(hwnd, newStyle);

    // Query display bounds dynamically using MonitorFromWindow
    int screenWidth = getSystemMetrics(smCxscreen);
    int screenHeight = getSystemMetrics(smCyscreen);
    int screenX = 0;
    int screenY = 0;

    try {
      final hMonitor = _monitorFromWindow(hwnd, 2); // MONITOR_DEFAULTTONEAREST = 2
      if (hMonitor != 0) {
        // Allocate space for MONITORINFO struct:
        // cbSize (4 bytes) + rcMonitor (16 bytes: left, top, right, bottom) + rcWork (16 bytes) + dwFlags (4 bytes) = 40 bytes total.
        final ptr = calloc<Uint8>(40);
        try {
          // Set cbSize to 40
          ptr.cast<Uint32>()[0] = 40;
          if (_getMonitorInfoW(hMonitor, ptr)) {
            final monitorRect = ptr.cast<Int32>();
            screenX = monitorRect[1]; // left
            screenY = monitorRect[2]; // top
            screenWidth = monitorRect[3] - screenX; // right - left
            screenHeight = monitorRect[4] - screenY; // bottom - top
            debugPrint('Detected monitor bounds: ($screenX, $screenY, $screenWidth, $screenHeight)');
          }
        } finally {
          calloc.free(ptr);
        }
      }
    } catch (e) {
      debugPrint('Failed to query monitor bounds dynamically: $e. Falling back to primary metrics.');
    }

    // Position at monitor coordinates covering the screen area
    setWindowBounds(hwnd, screenX, screenY, screenWidth, screenHeight,
        frameChanged: true);

    return originalStyle;
  }

  /// Restores original window style after leaving borderless fullscreen.
  static void exitBorderlessFullscreen(int hwnd, int originalStyle) {
    if (hwnd == 0) return;
    setWindowStyle(hwnd, originalStyle);

    // Re-query monitor bounds to restore at correct coordinates
    int screenWidth = getSystemMetrics(smCxscreen);
    int screenHeight = getSystemMetrics(smCyscreen);
    int screenX = 0;
    int screenY = 0;

    try {
      final hMonitor = _monitorFromWindow(hwnd, 2);
      if (hMonitor != 0) {
        final ptr = calloc<Uint8>(40);
        try {
          ptr.cast<Uint32>()[0] = 40;
          if (_getMonitorInfoW(hMonitor, ptr)) {
            final monitorRect = ptr.cast<Int32>();
            screenX = monitorRect[1];
            screenY = monitorRect[2];
            screenWidth = monitorRect[3] - screenX;
            screenHeight = monitorRect[4] - screenY;
          }
        } finally {
          calloc.free(ptr);
        }
      }
    } catch (e, st) {
      _log.fine('Failed to query monitor bounds during fullscreen restore; using primary metrics: $e', e, st);
    }

    setWindowBounds(hwnd, screenX, screenY, screenWidth, screenHeight,
        frameChanged: true);
  }

  /// Finds the current window's HWND reliably in a desktop_multi_window
  /// secondary engine. Uses EnumWindows + process ID matching instead of
  /// GetForegroundWindow, which returns the main window's HWND in secondary
  /// engines.
  ///
  /// Strategy:
  /// 1. Enumerate all visible windows in our process
  /// 2. Exclude the foreground window (which is typically the main window)
  /// 3. Return the remaining window (the secondary projector window)
  /// 4. Fall back to GetForegroundWindow if no match found
  static int findCurrentWindowHandle() {
    try {
      final currentPid = _getCurrentProcessId();
      final foregroundHwnd = _getForegroundWindow();

      // Collect visible windows in our process that are NOT the foreground
      // window. In a secondary engine, the foreground window is typically the
      // main window, so the secondary window is everything else.
      final foundHwnds = <int>[];

      // Allocate pidPtr once outside the callback to avoid repeated
      // calloc/free inside EnumWindows which can cause issues on some
      // Windows versions when called hundreds of times.
      final pidPtr = calloc<Int32>();
      try {
        final callback = NativeCallable<EnumWindowsProcNative>.isolateLocal(
          (int hWnd, int lParam) {
            try {
              _getWindowThreadProcessId(hWnd, pidPtr);
              final windowPid = pidPtr.value;
              if (windowPid == currentPid &&
                  _isWindowVisible(hWnd) &&
                  hWnd != foregroundHwnd) {
                foundHwnds.add(hWnd);
              }
            } catch (e, st) {
              // Swallow per-window errors to continue enumeration
              _log.fine('Failed to query a window during HWND enumeration; continuing: $e', e, st);
            }
            return true; // Continue enumeration
          },
          exceptionalReturn: true, // Continue enumeration even on Dart error
        );

        try {
          _enumWindowsNative(callback.nativeFunction, 0);
        } finally {
          callback.close();
        }
      } finally {
        calloc.free(pidPtr);
      }

      if (foundHwnds.isNotEmpty) {
        return foundHwnds.first;
      }

      // Fallback: if no non-foreground window found, the secondary window
      // might actually BE the foreground window. Return it.
      if (foregroundHwnd != 0) {
        final fallbackPidPtr = calloc<Int32>();
        try {
          _getWindowThreadProcessId(foregroundHwnd, fallbackPidPtr);
          if (fallbackPidPtr.value == currentPid) {
            return foregroundHwnd;
          }
        } finally {
          calloc.free(fallbackPidPtr);
        }
      }

      return 0;
    } catch (e) {
      debugPrint('findCurrentWindowHandle failed: $e');
      // Final fallback
      return _getForegroundWindow();
    }
  }
}

/// Attempts to maximize the current window using Win32 APIs.
/// This is needed because `window_manager` plugin is not registered in
/// `desktop_multi_window` secondary engines on Windows.
Future<void> maximizeCurrentWindow({bool topmost = false}) async {
  if (!Platform.isWindows) return;

  try {
    final hwnd = Win32WindowHelper.findCurrentWindowHandle();
    if (hwnd == 0) {
      await Future.delayed(const Duration(milliseconds: 200));
      final hwnd2 = Win32WindowHelper.findCurrentWindowHandle();
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
      final hwnd = Win32WindowHelper.findCurrentWindowHandle();
      if (hwnd == 0) {
        await Future.delayed(const Duration(milliseconds: 200));
        continue;
      }
      return Win32WindowHelper.enterBorderlessFullscreen(hwnd);
    } catch (e) {
      debugPrint('enterBorderlessFullscreen attempt $attempt failed: $e');
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }
  return 0;
}

/// Restores the window style and position after borderless fullscreen.
void exitBorderlessFullscreenCurrentWindow(int originalStyle) {
  if (!Platform.isWindows || originalStyle == 0) return;

  try {
    final hwnd = Win32WindowHelper.findCurrentWindowHandle();
    if (hwnd == 0) return;
    Win32WindowHelper.exitBorderlessFullscreen(hwnd, originalStyle);
  } catch (e) {
    debugPrint('exitBorderlessFullscreen error: $e');
  }
}
