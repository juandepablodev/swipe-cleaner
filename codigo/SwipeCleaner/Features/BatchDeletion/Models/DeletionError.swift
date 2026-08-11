import Foundation

/// Errors that can occur during batch deletion operations.
public enum DeletionError: Error, Sendable, Equatable {
  case userCancelled
  case deletionFailed(String)
}
