import Cocoa
import EventKit
import FlutterMacOS

/// Apple Reminders via EventKit. Benkyo keeps its tasks in one Reminders list.
final class RemindersBridge: RemindersApi {
  private static let listTitle = "Benkyo"
  private let store = EKEventStore()
  private let events: RemindersEvents

  init(binaryMessenger: FlutterBinaryMessenger) {
    events = RemindersEvents(binaryMessenger: binaryMessenger)
    NotificationCenter.default.addObserver(
      forName: .EKEventStoreChanged, object: store, queue: .main
    ) { [weak self] _ in
      Task { @MainActor in try? await self?.events.changed() }
    }
  }

  func status() throws -> AccessStatus {
    switch EKEventStore.authorizationStatus(for: .reminder) {
    case .notDetermined: return .notDetermined
    case .fullAccess: return .granted
    default: return .denied
    }
  }

  func requestAccess() async throws -> Bool {
    try await store.requestFullAccessToReminders()
  }

  func fetch() async throws -> [ReminderDto] {
    let list = try benkyoList()
    let open = store.predicateForIncompleteReminders(
      withDueDateStarting: nil, ending: nil, calendars: [list])
    let done = store.predicateForCompletedReminders(
      withCompletionDateStarting: Date(timeIntervalSinceNow: -7 * 86400), ending: nil,
      calendars: [list])
    return try await fetch(open) + fetch(done)
  }

  func save(reminder dto: ReminderDto) throws -> String {
    let r: EKReminder
    if let id = dto.id, let existing = store.calendarItem(withIdentifier: id) as? EKReminder {
      r = existing  // edits keep fields we don't model (alarms, URL, subtasks)
    } else {
      r = EKReminder(eventStore: store)
      r.calendar = try benkyoList()
    }
    r.title = dto.title
    r.notes = dto.notes
    r.priority = Int(dto.priority)
    r.dueDateComponents = dto.dueMillis.map(Self.components)
    r.isCompleted = dto.completed
    try store.save(r, commit: true)
    return r.calendarItemIdentifier
  }

  func delete(id: String) throws {
    guard let r = store.calendarItem(withIdentifier: id) as? EKReminder else { return }
    try store.remove(r, commit: true)
  }

  func openPrivacySettings() throws {
    let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders"
    NSWorkspace.shared.open(URL(string: url)!)
  }

  // MARK: - Helpers

  // ponytail: found by title, so renaming the list in Reminders makes us create a new
  // "Benkyo" list. Persist the calendar id (or add a list picker) if that matters.
  private func benkyoList() throws -> EKCalendar {
    if let list = store.calendars(for: .reminder).first(where: { $0.title == Self.listTitle }) {
      return list
    }
    let list = EKCalendar(for: .reminder, eventStore: store)
    list.title = Self.listTitle
    guard
      let source = store.defaultCalendarForNewReminders()?.source
        ?? store.sources.first(where: { $0.sourceType == .local })
    else {
      throw PigeonError(code: "no-source", message: "No Reminders account available", details: nil)
    }
    list.source = source
    try store.saveCalendar(list, commit: true)
    return list
  }

  private func fetch(_ predicate: NSPredicate) async throws -> [ReminderDto] {
    await withCheckedContinuation { cont in
      store.fetchReminders(matching: predicate) { reminders in
        cont.resume(returning: (reminders ?? []).map(Self.dto))
      }
    }
  }

  private static func dto(_ r: EKReminder) -> ReminderDto {
    ReminderDto(
      id: r.calendarItemIdentifier,
      title: r.title ?? "",
      notes: r.notes,
      priority: Int64(r.priority),
      dueMillis: r.dueDateComponents
        .flatMap { Calendar.current.date(from: $0) }
        .map { Int64($0.timeIntervalSince1970 * 1000) },
      completed: r.isCompleted,
      completedMillis: r.completionDate.map { Int64($0.timeIntervalSince1970 * 1000) })
  }

  // ponytail: midnight = date-only, so a reminder due exactly 00:00 loses its time.
  private static func components(_ millis: Int64) -> DateComponents {
    let date = Date(timeIntervalSince1970: Double(millis) / 1000)
    let cal = Calendar.current
    let hasTime = cal.component(.hour, from: date) != 0 || cal.component(.minute, from: date) != 0
    return cal.dateComponents(hasTime ? [.year, .month, .day, .hour, .minute] : [.year, .month, .day], from: date)
  }
}
