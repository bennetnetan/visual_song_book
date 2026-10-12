import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

/// Makes a secondary projection window fill the projector display.
///
/// `desktop_multi_window` creates its child windows at a hardcoded
/// `NSRect(x: 0, y: 0, width: 800, height: 600)` on the primary screen, so
/// without this the projection output appears on the laptop display instead of
/// the projector and the operator has to drag it there by hand. We move the
/// window onto the non-primary display (when one is connected), strip its
/// chrome, and size it to fill that display exactly.
private func placeProjectionWindowOnSecondScreen(
  _ window: NSWindow,
  contentViewController: NSViewController
) {
  guard let view = contentViewController.view else { return }

  // Prefer a non-primary display; fall back to the primary screen.
  let targetScreen: NSScreen?
  if NSScreen.screens.count > 1 {
    targetScreen = NSScreen.screens.first { $0 != NSScreen.main }
  } else {
    targetScreen = nil
  }
  guard let screen = targetScreen ?? NSScreen.main else { return }

  // Borderless so no title bar or resize handles are visible.
  window.styleMask = [.borderless, .fullSizeContentView]
  window.titleVisibility = .hidden
  window.titlebarAppearsTransparent = true

  // Size the window to the whole display before making it visible so it never
  // flashes at 800x600 on the primary screen first.
  window.setFrame(screen.frame, display: false)
  view.frame = screen.frame
  view.needsDisplay = true

  // Keep the projection above every other window (kiosk-style behaviour).
  window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) - 1)

  window.orderFrontRegardless()
}

// Called by desktop_multi_window for every secondary window it creates.
extension MainFlutterWindow {
  static func registerProjectionWindowCallback() {
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { flutterViewController in
      guard let window = flutterViewController.view.window else { return }
      placeProjectionWindowOnSecondScreen(window, contentViewController: flutterViewController)
    }
  }
}
