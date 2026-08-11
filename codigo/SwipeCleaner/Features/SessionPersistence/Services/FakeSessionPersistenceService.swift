import Foundation

public final class FakeSessionPersistenceService: SessionPersistenceServiceProtocol, @unchecked Sendable {
  public var savedState: SavedSessionState?

  public init(savedState: SavedSessionState? = nil) {
    self.savedState = savedState
  }

  public func saveSession(_ state: SavedSessionState) {
    self.savedState = state
  }

  public func loadSavedSession() -> SavedSessionState? {
    self.savedState
  }

  public func clearSavedSession() {
    self.savedState = nil
  }
}
