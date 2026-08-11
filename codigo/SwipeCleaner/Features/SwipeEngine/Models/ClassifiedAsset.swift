import Foundation

/// Represents an asset that has been classified during a swipe session.
public struct ClassifiedAsset: Identifiable, Sendable, Equatable {
  public let asset: AssetModel
  public let decision: SwipeDecision
  public let timestamp: Date

  public var id: String {
    asset.id
  }

  public init(asset: AssetModel, decision: SwipeDecision, timestamp: Date = Date()) {
    self.asset = asset
    self.decision = decision
    self.timestamp = timestamp
  }
}
