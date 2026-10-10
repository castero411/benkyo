import Cocoa
import FlutterMacOS

/// Controls the Spotify desktop app over AppleScript. Works with Free and
/// Premium accounts; audio plays in Spotify itself. Never launches Spotify
/// except through `launch()`.
final class SpotifyBridge: SpotifyApi {
  private static let bundleId = "com.spotify.client"
  private static let stateScript = """
    tell application id "com.spotify.client"
      set s to player state as string
      if s is "stopped" then return {s}
      set t to current track
      return {s, name of t, artist of t, artwork url of t, duration of t, player position}
    end tell
    """

  private let events: SpotifyEvents
  private var observers: [NSObjectProtocol] = []

  init(binaryMessenger: FlutterBinaryMessenger) {
    events = SpotifyEvents(binaryMessenger: binaryMessenger)
    // Spotify announces every play/pause/track change: no polling needed.
    observers.append(
      DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name("com.spotify.client.PlaybackStateChanged"), object: nil,
        queue: .main
      ) { [weak self] _ in self?.push() })
    let workspace = NSWorkspace.shared.notificationCenter
    for (name, running) in [
      (NSWorkspace.didLaunchApplicationNotification, true),
      (NSWorkspace.didTerminateApplicationNotification, false),
    ] {
      observers.append(
        workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
          let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
          if app?.bundleIdentifier == Self.bundleId { self?.push(running: running) }
        })
    }
  }

  func state() async throws -> SpotifyState { await currentState() }

  func playPause() async throws { try await command("playpause") }
  func next() async throws { try await command("next track") }
  func previous() async throws { try await command("previous track") }

  func play(uri: String) async throws {
    // Re-validated here so nothing else can reach the script.
    guard uri.range(of: #"^spotify:(playlist|album|track|artist):[A-Za-z0-9]+$"#, options: .regularExpression) != nil
    else { throw PigeonError(code: "bad-link", message: "Not a Spotify link", details: nil) }
    try await command("play track \"\(uri)\"")
  }

  func launch() async throws -> Bool {
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleId)
    else { return false }
    let config = NSWorkspace.OpenConfiguration()
    config.activates = false  // stay in Benkyo
    _ = try await NSWorkspace.shared.openApplication(at: url, configuration: config)
    return true
  }

  func openDownloadPage() throws {
    NSWorkspace.shared.open(URL(string: "https://www.spotify.com/download/mac/")!)
  }

  func openAutomationSettings() throws {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
  }

  // MARK: - Helpers

  private var isRunning: Bool {
    !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleId).isEmpty
  }

  private func push(running: Bool? = nil) {
    Task { @MainActor in
      let state = await self.currentState(running: running)
      try? await self.events.changed(state: state)
    }
  }

  private func currentState(running override: Bool? = nil) async -> SpotifyState {
    let installed = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Self.bundleId) != nil
    let running = override ?? isRunning
    var s = SpotifyState(installed: installed, running: running, playing: false, access: .notAsked)
    guard running else { return s }
    s.access = await access()
    guard s.access == .granted, let list = try? await run(Self.stateScript) else { return s }
    s.playing = list.atIndex(1)?.stringValue == "playing"
    if list.numberOfItems >= 6 {
      s.title = list.atIndex(2)?.stringValue
      s.artist = list.atIndex(3)?.stringValue
      s.artworkUrl = list.atIndex(4)?.stringValue
      s.durationMs = Int64(list.atIndex(5)?.int32Value ?? 0)
      s.positionMs = Int64((list.atIndex(6)?.doubleValue ?? 0) * 1000)
    }
    return s
  }

  /// Automation permission without prompting. Can block, so off the main thread.
  private func access() async -> SpotifyAccess {
    await withCheckedContinuation { cont in
      DispatchQueue.global(qos: .userInitiated).async {
        let target = NSAppleEventDescriptor(bundleIdentifier: Self.bundleId)
        let status = AEDeterminePermissionToAutomateTarget(
          target.aeDesc, typeWildCard, typeWildCard, false)
        cont.resume(
          returning: status == noErr
            ? .granted : status == OSStatus(errAEEventNotPermitted) ? .denied : .notAsked)
      }
    }
  }

  private func command(_ verb: String) async throws {
    guard isRunning else {
      throw PigeonError(code: "not-running", message: "Spotify isn't open", details: nil)
    }
    _ = try await run("tell application id \"\(Self.bundleId)\" to \(verb)")
  }

  /// Runs AppleScript from a plain main run-loop turn (not inside a Swift
  /// concurrency job), the same rule as MenuBridge, since sending Apple
  /// Events may wait on system services.
  private func run(_ source: String) async throws -> NSAppleEventDescriptor {
    try await withCheckedThrowingContinuation { cont in
      let loop = CFRunLoopGetMain()
      CFRunLoopPerformBlock(loop, CFRunLoopMode.defaultMode.rawValue) {
        var error: NSDictionary?
        if let result = NSAppleScript(source: source)?.executeAndReturnError(&error) {
          cont.resume(returning: result)
        } else {
          let code = error?[NSAppleScript.errorNumber] as? Int ?? 0
          cont.resume(
            throwing: PigeonError(
              code: code == -1743 ? "not-allowed" : "script",
              message: error?[NSAppleScript.errorMessage] as? String, details: nil))
        }
      }
      CFRunLoopWakeUp(loop)
    }
  }
}
