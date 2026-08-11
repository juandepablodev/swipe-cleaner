import Foundation

public final class SessionPersistenceService: SessionPersistenceServiceProtocol, @unchecked Sendable {
  private let userDefaults: UserDefaults
  private let key = "com.tindercleaner.saved_session"

  public init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  public func saveSession(_ state: SavedSessionState) {
    do {
      let data = try JSONEncoder().encode(state)
      userDefaults.set(data, forKey: key)
    } catch {
      // Silent failure for persistence - no crash
    }
  }

  public func loadSavedSession() -> SavedSessionState? {
    guard let data = userDefaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(SavedSessionState.self, from: data)
  }

  public func clearSavedSession() {
    userDefaults.removeObject(forKey: key)
  }
}
