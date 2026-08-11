import Foundation

public protocol SessionPersistenceServiceProtocol: Sendable {
  func saveSession(_ state: SavedSessionState)
  func loadSavedSession() -> SavedSessionState?
  func clearSavedSession()
}
