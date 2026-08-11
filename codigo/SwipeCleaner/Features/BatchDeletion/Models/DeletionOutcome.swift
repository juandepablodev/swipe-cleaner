import Foundation

/// Outcome of a batch deletion operation.
public struct DeletionOutcome: Sendable, Equatable {
  public let deletedIDs: [String]
  public let inaccessibleIDs: [String]

  public init(deletedIDs: [String], inaccessibleIDs: [String]) {
    self.deletedIDs = deletedIDs
    self.inaccessibleIDs = inaccessibleIDs
  }
}
