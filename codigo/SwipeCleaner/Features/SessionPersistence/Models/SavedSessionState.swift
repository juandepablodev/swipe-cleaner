import Foundation

public struct SavedClassifiedAsset: Codable, Sendable, Equatable {
  public let assetID: String
  public let decision: SwipeDecision
  public let timestamp: Date

  public init(assetID: String, decision: SwipeDecision, timestamp: Date) {
    self.assetID = assetID
    self.decision = decision
    self.timestamp = timestamp
  }
}

public struct SavedSessionState: Codable, Sendable, Equatable {
  public let lastModified: Date
  public let classifiedAssets: [SavedClassifiedAsset]
  public let remainingAssetIDs: [String]

  public init(lastModified: Date = Date(), classifiedAssets: [SavedClassifiedAsset], remainingAssetIDs: [String]) {
    self.lastModified = lastModified
    self.classifiedAssets = classifiedAssets
    self.remainingAssetIDs = remainingAssetIDs
  }
}
