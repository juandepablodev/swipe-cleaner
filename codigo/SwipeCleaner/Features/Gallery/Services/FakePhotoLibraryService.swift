import Foundation
import Photos
import UIKit
import AVFoundation

/// Synthetic implementation of PhotoLibraryServiceProtocol for fast, isolated CI testing without PhotoKit.
public final class FakePhotoLibraryService: PhotoLibraryServiceProtocol, @unchecked Sendable {
  public var authorizationStatus: PHAuthorizationStatus
  public var mockAssets: [AssetModel] = []
  
  public private(set) var startCachingCalls: [(assets: [AssetModel], targetSize: CGSize)] = []
  public private(set) var stopCachingCalls: [(assets: [AssetModel], targetSize: CGSize)] = []
  public private(set) var cancelledRequestIDs: Set<PHImageRequestID> = []
  
  private var continuation: AsyncStream<AssetLibraryChange>.Continuation?
  private var nextRequestID: PHImageRequestID = 1

  public init(
    authorizationStatus: PHAuthorizationStatus = .authorized,
    assetCount: Int = 0
  ) {
    self.authorizationStatus = authorizationStatus
    if assetCount > 0 {
      self.mockAssets = Self.generateSyntheticAssets(count: assetCount)
    }
  }

  public func requestAuthorization() async -> PHAuthorizationStatus {
    authorizationStatus
  }

  public func fetchAssetCount() async -> Int {
    mockAssets.count
  }

  public func fetchAssets(in range: Range<Int>) async -> [AssetModel] {
    guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= mockAssets.count else {
      return []
    }
    return Array(mockAssets[range])
  }

  public var mockThumbnailImage: UIImage? = UIImage()
  public var onRequestThumbnailCalled: (@Sendable (AssetModel, (@Sendable (UIImage) -> Void)?) -> Void)? = nil

  public func requestThumbnail(
    for asset: AssetModel,
    targetSize: CGSize,
    onRequestID: @Sendable (PHImageRequestID) -> Void,
    onProgressiveUpdate: (@Sendable (UIImage) -> Void)? = nil
  ) async -> UIImage? {
    let reqID = nextRequestID
    nextRequestID += 1
    onRequestID(reqID)
    onRequestThumbnailCalled?(asset, onProgressiveUpdate)
    return mockThumbnailImage
  }

  public var mockPlayerItem: AVPlayerItem? = nil
  public var onRequestPlayerItemCalled: (@Sendable (AssetModel) -> Void)? = nil

  public func requestPlayerItem(
    for asset: AssetModel,
    onRequestID: @Sendable (PHImageRequestID) -> Void
  ) async -> AVPlayerItem? {
    let reqID = nextRequestID
    nextRequestID += 1
    onRequestID(reqID)
    onRequestPlayerItemCalled?(asset)
    return mockPlayerItem
  }

  public func cancelImageRequest(_ requestID: PHImageRequestID) {
    cancelledRequestIDs.insert(requestID)
  }

  public func startCaching(for assets: [AssetModel], targetSize: CGSize) {
    startCachingCalls.append((assets: assets, targetSize: targetSize))
  }

  public func stopCaching(for assets: [AssetModel], targetSize: CGSize) {
    stopCachingCalls.append((assets: assets, targetSize: targetSize))
  }

  public func changeStream() -> AsyncStream<AssetLibraryChange> {
    AsyncStream { continuation in
      self.continuation = continuation
      continuation.onTermination = { [weak self] _ in
        self?.continuation = nil
      }
    }
  }

  public func simulateChange(_ change: AssetLibraryChange) {
    if change.hasIncrementalChanges {
      self.mockAssets = change.snapshotAfter
    } else {
      self.mockAssets = change.snapshotAfter
    }
    continuation?.yield(change)
  }

  public static func generateSyntheticAssets(count: Int) -> [AssetModel] {
    let baseDate = Date()
    var assets: [AssetModel] = []
    assets.reserveCapacity(count)
    for i in 0..<count {
      let isVideo = (i % 5 == 0)
      let mediaType: PHAssetMediaType = isVideo ? .video : .image
      let duration: TimeInterval = isVideo ? TimeInterval((i + 1) * 10) : 0.0
      let creationDate = baseDate.addingTimeInterval(TimeInterval(-i * 60))
      let asset = AssetModel(
        id: "synthetic-asset-\(i)",
        mediaType: mediaType,
        duration: duration,
        creationDate: creationDate,
        pixelWidth: 1920,
        pixelHeight: 1080
      )
      assets.append(asset)
    }
    return assets
  }
}
