#include "flutter_window.h"

#include <optional>
#include <windows.h>

#include "flutter/generated_plugin_registrant.h"
#include <desktop_multi_window/desktop_multi_window_plugin.h>

namespace {

// Which monitor the projection output window should fill.
struct MonitorChoice {
  RECT primary_rect = {0, 0, 0, 0};
  RECT secondary_rect = {0, 0, 0, 0};
  bool has_primary = false;
  bool has_secondary = false;
};

// Collects the primary monitor's rect and the first non-primary monitor's
// rect. Needed because desktop_multi_window always creates its child window
// near (10, 10) on the primary display, so we must move it ourselves.
BOOL CALLBACK FindProjectionMonitorProc(HMONITOR monitor, HDC hdc,
                                        LPRECT rect, LPARAM data) {
  auto* choice = reinterpret_cast<MonitorChoice*>(data);
  MONITORINFO info = {};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) {
    return TRUE;
  }
  if (info.dwFlags & MONITORINFOF_PRIMARY) {
    choice->primary_rect = info.rcMonitor;
    choice->has_primary = true;
  } else if (!choice->has_secondary) {
    // First non-primary display wins.
    choice->secondary_rect = info.rcMonitor;
    choice->has_secondary = true;
  }
  return TRUE;
}

}  // namespace

// ---------------------------------------------------------------------------
// Secondary-window decoration removal and second-screen placement.
// Called by desktop_multi_window whenever it creates a new child window.
// desktop_multi_window positions its child window near (10, 10) with a
// hardcoded 800x600 size, which always lands on the primary display. Before
// stripping chrome we move the window onto the projector display (a
// non-primary monitor when one is connected) and resize it to fill that
// display exactly, so operators never have to drag it there by hand.
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

  // Prefer a non-primary display (the projector). Falls back to the primary
  // display when only one monitor is connected.
  MonitorChoice choice;
  EnumDisplayMonitors(nullptr, nullptr, FindProjectionMonitorProc,
                      reinterpret_cast<LPARAM>(&choice));

  bool has_target = choice.has_secondary || choice.has_primary;
  RECT target = choice.has_secondary ? choice.secondary_rect : choice.primary_rect;

  // Cover the whole display (mirrors gtk_window_fullscreen on Linux and keeps
  // the OS taskbar hidden behind the projection).
  if (has_target && target.right > target.left &&
      target.bottom > target.top) {
    SetWindowPos(toplevel, HWND_TOP, target.left, target.top,
                 target.right - target.left, target.bottom - target.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    // Fallback: strip chrome only (no geometry is known).
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
