import Foundation

/// Summary result of a swipe session, consumed by Feature 004 for batch deletion.
public struct SessionResult: Sendable, Equatable {
  public let keep: [AssetModel]
  public let pendingDeletion: [AssetModel]

  public init(keep: [AssetModel], pendingDeletion: [AssetModel]) {
    self.keep = keep
    self.pendingDeletion = pendingDeletion
  }
}
