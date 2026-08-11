import Foundation

/// Represents incremental diff changes in the photo library while crossing protocol boundaries safely.
public struct AssetLibraryChange: Sendable {
  public let inserted: IndexSet
  public let removed: IndexSet
  public let changed: IndexSet
  public let snapshotAfter: [AssetModel]
  public let hasIncrementalChanges: Bool

  public init(
    inserted: IndexSet = [],
    removed: IndexSet = [],
    changed: IndexSet = [],
    snapshotAfter: [AssetModel],
    hasIncrementalChanges: Bool
  ) {
    self.inserted = inserted
    self.removed = removed
    self.changed = changed
    self.snapshotAfter = snapshotAfter
    self.hasIncrementalChanges = hasIncrementalChanges
  }
}
