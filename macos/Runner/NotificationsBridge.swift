import Cocoa
import UserNotifications

/// Local notifications for phase ends. Scheduled ahead of time so they fire
/// on time even when App Nap slows Benkyo's own timers in the background.
final class NotificationsBridge: NSObject, NotificationsApi, UNUserNotificationCenterDelegate {
  private let center = UNUserNotificationCenter.current()

  override init() {
    super.init()
    center.delegate = self
  }

  func requestPermission() async throws -> Bool {
    try await center.requestAuthorization(options: [.alert, .sound])
  }

  func schedule(id: String, title: String, body: String, atMillis: Int64) throws {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    let seconds = max(1, Double(atMillis) / 1000 - Date().timeIntervalSince1970)
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
  }

  func cancel(id: String) throws {
    center.removePendingNotificationRequests(withIdentifiers: [id])
  }

  // Show the banner even while Benkyo is the frontmost app.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}
