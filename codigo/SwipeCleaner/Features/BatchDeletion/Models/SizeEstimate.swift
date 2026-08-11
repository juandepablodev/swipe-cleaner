import Foundation

/// Calculated size estimate for a list of assets pending deletion.
public struct SizeEstimate: Sendable, Equatable {
  public let totalBytes: Int64
  public let assetsWithUnknownSize: Int

  public init(totalBytes: Int64, assetsWithUnknownSize: Int = 0) {
    self.totalBytes = totalBytes
    self.assetsWithUnknownSize = assetsWithUnknownSize
  }
}
