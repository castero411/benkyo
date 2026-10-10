import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// True only when zen mode put us in full screen, so leaving zen
  /// never exits a full screen the user entered themselves.
  private var zenFullScreen = false

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Hidden title bar: content runs under the traffic lights.
    titlebarAppearsTransparent = true
    titleVisibility = .hidden
    styleMask.insert(.fullSizeContentView)
    collectionBehavior.insert(.fullScreenPrimary)
    minSize = NSSize(width: 1024, height: 680)
    backgroundColor = NSColor(red: 0x14 / 255, green: 0x12 / 255, blue: 0x23 / 255, alpha: 1)

    let channel = FlutterMethodChannel(
      name: "benkyo/window", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self, call.method == "setFullScreen", let on = call.arguments as? Bool else {
        return result(FlutterMethodNotImplemented)
      }
      let isFull = self.styleMask.contains(.fullScreen)
      if on && !isFull {
        self.zenFullScreen = true
        self.toggleFullScreen(nil)
      } else if !on && isFull && self.zenFullScreen {
        self.toggleFullScreen(nil)
      }
      if !on { self.zenFullScreen = false }
      result(nil)
    }
    NotificationCenter.default.addObserver(
      forName: NSWindow.didExitFullScreenNotification, object: self, queue: .main
    ) { [weak self] _ in
      self?.zenFullScreen = false
      channel.invokeMethod("didExitFullScreen", arguments: nil)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
