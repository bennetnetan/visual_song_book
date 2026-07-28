import 'dart:ffi';
import 'dart:io';

// Win32 function typedefs using standard FFI types (HWND = IntPtr)
typedef GetActiveWindowNative = IntPtr Function();
typedef GetActiveWindowDart = int Function();

typedef ShowWindowNative = Bool Function(IntPtr hWnd, Int32 nCmdShow);
typedef ShowWindowDart = bool Function(int hWnd, int nCmdShow);

typedef SetWindowPosNative = Bool Function(
    IntPtr hWnd, IntPtr hWndInsertAfter, Int32 X, Int32 Y, Int32 cx, Int32 cy, Uint32 uFlags);
typedef SetWindowPosDart = bool Function(
    int hWnd, int hWndInsertAfter, int X, int Y, int cx, int cy, int uFlags);

// Win32 constants
const int swMaximize = 3;
const int swShowMaximized = 3;
const int swRestore = 9;
const int swpShowWindow = 0x0040;
const int hwndTop = 0;
const int hwndTopmost = -1;

class Win32WindowHelper {
  static final _user32 = DynamicLibrary.open('user32.dll');

  static final _getActiveWindow =
      _user32.lookupFunction<GetActiveWindowNative, GetActiveWindowDart>(
          'GetActiveWindow');

  static final _showWindow =
      _user32.lookupFunction<ShowWindowNative, ShowWindowDart>('ShowWindow');

  static final _setWindowPos =
      _user32.lookupFunction<SetWindowPosNative, SetWindowPosDart>(
          'SetWindowPos');

  static int getActiveWindowHandle() {
    return _getActiveWindow();
  }

  static bool maximizeWindow(int hwnd) {
    return _showWindow(hwnd, swMaximize);
  }

  static bool setWindowBounds(int hwnd, int x, int y, int width, int height,
      {bool topmost = false}) {
    return _setWindowPos(
          hwnd,
          topmost ? hwndTopmost : hwndTop,
          x,
          y,
          width,
          height,
          swpShowWindow);
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
