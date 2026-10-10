import Cocoa
import FlutterMacOS

/// Real NSMenu pop-ups, so menus get system vibrancy, typography, keyboard
/// navigation, type-select and VoiceOver exactly as macOS defines them.
final class MenuBridge: NSObject, MenuApi {
  private weak var view: NSView?
  private var finish: ((String?) -> Void)?

  init(view: NSView) {
    self.view = view
  }

  func show(items: [NativeMenuItem], x: Double, y: Double) async throws -> String? {
    let menu = build(items)
    return await withCheckedContinuation { cont in
      var done = false
      finish = { id in
        guard !done else { return }
        done = true
        cont.resume(returning: id)
      }
      // Pop up from a plain run-loop turn, like a native right-click does.
      // We're currently inside a main-queue job (Swift concurrency); menu
      // tracking waits for the input-method service, whose reply needs the
      // main queue too, so the wait fails and AppKit aborts (SIGABRT).
      onMainRunLoop { [weak self] in
        guard let self, let view = self.view else { return self?.finish?(nil) ?? () }
        let point = NSPoint(x: x, y: view.isFlipped ? y : view.bounds.height - y)
        menu.popUp(positioning: nil, at: point, in: view)  // blocks until closed
        // An item's action may arrive just after tracking ends; let it win.
        self.onMainRunLoop {
          self.finish?(nil)
          self.finish = nil
        }
      }
    }
  }

  private func onMainRunLoop(_ block: @escaping () -> Void) {
    let loop = CFRunLoopGetMain()
    CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue, block)
    CFRunLoopWakeUp(loop)
  }

  @objc private func pick(_ sender: NSMenuItem) {
    finish?(sender.representedObject as? String)
  }

  private func build(_ items: [NativeMenuItem]) -> NSMenu {
    let menu = NSMenu()
    for item in items {
      guard let title = item.title else {
        menu.addItem(.separator())
        continue
      }
      let entry = NSMenuItem(title: title, action: #selector(pick(_:)), keyEquivalent: "")
      entry.target = self
      entry.representedObject = item.id
      entry.state = item.checked ? .on : .off
      if let children = item.children {
        entry.action = nil
        entry.submenu = build(children)
      }
      menu.addItem(entry)
    }
    return menu
  }
}
