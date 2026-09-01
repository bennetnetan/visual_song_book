#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>

// ---------------------------------------------------------------------------
// Secondary-window decoration removal
// Called by desktop_multi_window whenever it creates a new child window.
// We receive the FlutterViewController*; from its native view HWND we walk
// up to the top-level Win32 window and strip the title bar / chrome before
// Flutter renders a single frame — eliminating the title-bar flash seen when
// the Dart-side Win32 calls arrive later.
// ---------------------------------------------------------------------------
static void OnSecondaryWindowCreated(void* flutter_view_controller) {
  auto* vc =
      reinterpret_cast<flutter::FlutterViewController*>(flutter_view_controller);
  if (!vc || !vc->view()) return;

  // The Flutter view is a child HWND; the projection window is its ancestor.
  HWND child_hwnd = vc->view()->GetNativeWindow();
  HWND toplevel   = GetAncestor(child_hwnd, GA_ROOT);
  if (!toplevel) return;

  // Strip every piece of Win32 chrome from the secondary window.
  LONG_PTR style = GetWindowLongPtrW(toplevel, GWL_STYLE);
  style &= ~(WS_CAPTION | WS_THICKFRAME | WS_SYSMENU |
             WS_MINIMIZEBOX | WS_MAXIMIZEBOX);
  SetWindowLongPtrW(toplevel, GWL_STYLE, style);

  // Enter OS fullscreen on the monitor containing this window — mirrors
  // Linux's gtk_window_fullscreen() in my_application.cc. The window
  // manager places the window on whichever display desktop_multi_window
  // assigned it to; we just fill that display.
  HMONITOR hMon = MonitorFromWindow(toplevel, MONITOR_DEFAULTTONEAREST);
  MONITORINFO mi = {};
  mi.cbSize = sizeof(mi);
  if (hMon && GetMonitorInfoW(hMon, &mi)) {
    const RECT& rc = mi.rcMonitor;
    SetWindowPos(toplevel, HWND_TOP,
                 rc.left, rc.top,
                 rc.right - rc.left, rc.bottom - rc.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    // Fallback: strip chrome only (no fullscreen).
    SetWindowPos(toplevel, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  }
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  // Register the secondary-window decoration callback so every projection
  // window created by desktop_multi_window starts chrome-free.
  DesktopMultiWindowSetWindowCreatedCallback(OnSecondaryWindowCreated);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
