import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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

    // Zen mode (F) is plain native full screen.
    FlutterMethodChannel(
      name: "benkyo/window", binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard call.method == "toggleFullScreen" else { return result(FlutterMethodNotImplemented) }
      self?.toggleFullScreen(nil)
      result(nil)
    }

    let messenger = flutterViewController.engine.binaryMessenger
    RemindersApiSetup.setUp(
      binaryMessenger: messenger, api: RemindersBridge(binaryMessenger: messenger))
    MenuApiSetup.setUp(
      binaryMessenger: messenger, api: MenuBridge(view: flutterViewController.view))
    NotificationsApiSetup.setUp(binaryMessenger: messenger, api: NotificationsBridge())
    SceneryApiSetup.setUp(binaryMessenger: messenger, api: SceneryBridge())

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
