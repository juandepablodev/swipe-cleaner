import Foundation

/// Protocol for estimating deletion size and triggering PhotoKit batch deletion.
public protocol PhotoKitDeletionServiceProtocol: Sendable {
  func estimateSize(for assets: [AssetModel]) async -> SizeEstimate
  func deleteAssets(_ assets: [AssetModel]) async throws -> DeletionOutcome
}
