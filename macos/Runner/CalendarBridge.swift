import Cocoa
import EventKit
import FlutterMacOS

/// Apple Calendar via EventKit. Reads today's events and adds events for
/// scheduled tasks to the user's default calendar.
final class CalendarBridge: CalendarApi {
  private let store = EKEventStore()
  private let events: CalendarEvents

  init(binaryMessenger: FlutterBinaryMessenger) {
    events = CalendarEvents(binaryMessenger: binaryMessenger)
    NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: store, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in try? await self?.events.changed() }
    }
  }

  func status() throws -> AccessStatus {
    switch EKEventStore.authorizationStatus(for: .event) {
    case .notDetermined: return .notDetermined
    case .fullAccess: return .granted
    default: return .denied
    }
  }

  func requestAccess() async throws -> Bool {
    try await store.requestFullAccessToEvents()
  }

  func events(fromMillis: Int64, toMillis: Int64) async throws -> [CalendarEventDto] {
    let predicate = store.predicateForEvents(
      withStart: Self.date(fromMillis), end: Self.date(toMillis), calendars: nil)
    return store.events(matching: predicate).map { e in
      CalendarEventDto(
        id: e.eventIdentifier ?? e.calendarItemIdentifier,
        title: e.title ?? "",
        startMillis: Self.millis(e.startDate),
        endMillis: Self.millis(e.endDate),
        allDay: e.isAllDay,
        calendarTitle: e.calendar.title,
        colorHex: Self.hex(e.calendar.color),
        taskId: e.url.flatMap { $0.scheme == "benkyo" && $0.host == "task" ? $0.lastPathComponent : nil })
    }
  }

  func createEvent(title: String, startMillis: Int64, endMillis: Int64, taskId: String?) throws -> String {
    guard let calendar = store.defaultCalendarForNewEvents else {
      throw PigeonError(code: "no-calendar", message: "No calendar to add events to", details: nil)
    }
    let event = EKEvent(eventStore: store)
    event.calendar = calendar
    event.title = title
    event.startDate = Self.date(startMillis)
    event.endDate = Self.date(endMillis)
    if let taskId,
      let id = taskId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
    {
      event.url = URL(string: "benkyo://task/\(id)")  // lets the Today panel link back
    }
    try store.save(event, span: .thisEvent, commit: true)
    return event.eventIdentifier ?? event.calendarItemIdentifier
  }

  func deleteEvent(id: String) throws {
    guard let event = store.event(withIdentifier: id) else { return }
    try store.remove(event, span: .thisEvent, commit: true)
  }

  func openPrivacySettings() throws {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!)
  }

  private static func date(_ millis: Int64) -> Date { Date(timeIntervalSince1970: Double(millis) / 1000) }
  private static func millis(_ date: Date) -> Int64 { Int64(date.timeIntervalSince1970 * 1000) }

  private static func hex(_ color: NSColor) -> String {
    guard let c = color.usingColorSpace(.sRGB) else { return "#8E8E93" }
    return String(
      format: "#%02X%02X%02X", Int(c.redComponent * 255), Int(c.greenComponent * 255),
      Int(c.blueComponent * 255))
  }
}
