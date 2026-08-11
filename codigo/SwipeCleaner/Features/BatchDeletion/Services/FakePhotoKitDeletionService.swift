import Foundation

/// Fake deletion service for fast, deterministic testing without PhotoKit system dialogs.
public final class FakePhotoKitDeletionService: PhotoKitDeletionServiceProtocol, @unchecked Sendable {
  public var shouldFailWithUserCancellation: Bool = false
  public var shouldFailWithGeneralError: Bool = false
  public var mockBytesPerAsset: Int64 = 15_000_000
  public var mockUnknownCount: Int = 0

  public private(set) var deletedAssetsHistory: [[AssetModel]] = []

  public init() {}

  public func estimateSize(for assets: [AssetModel]) async -> SizeEstimate {
    let total = Int64(assets.count) * mockBytesPerAsset
    return SizeEstimate(totalBytes: total, assetsWithUnknownSize: mockUnknownCount)
  }

  public func deleteAssets(_ assets: [AssetModel]) async throws -> DeletionOutcome {
    deletedAssetsHistory.append(assets)

    if shouldFailWithUserCancellation {
      throw DeletionError.userCancelled
    }

    if shouldFailWithGeneralError {
      throw DeletionError.deletionFailed("Simulated deletion error")
    }

    let ids = assets.map(\.id)
    return DeletionOutcome(deletedIDs: ids, inaccessibleIDs: [])
  }
}
