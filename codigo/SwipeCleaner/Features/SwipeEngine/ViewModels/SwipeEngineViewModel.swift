import Foundation
import Photos
import UIKit
import SwiftUI
import AVFoundation

@Observable
@MainActor
public final class SwipeEngineViewModel {
  public private(set) var remainingAssets: [AssetModel] = []
  public private(set) var historyStack: [ClassifiedAsset] = []
  public private(set) var swipeInFlight: Bool = false

  private static let historyLimit = 200

  public var currentAsset: AssetModel? { remainingAssets.first }
  public var nextAsset: AssetModel? { remainingAssets.dropFirst().first }
  public var pendingDeletionCount: Int { historyStack.filter { $0.decision == .delete }.count }
  public var keepCount: Int { historyStack.filter { $0.decision == .keep }.count }

  public var sessionResult: SessionResult {
    let keep = historyStack.filter { $0.decision == .keep }.map(\.asset)
    let delete = historyStack.filter { $0.decision == .delete }.map(\.asset)
    return SessionResult(keep: keep, pendingDeletion: delete)
  }

  // Bounded image & video cache and active requests
  var imageCache: [String: UIImage] = [:]
  var playerItemCache: [String: AVPlayerItem] = [:]
  var activeRequests: [String: PHImageRequestID] = [:]
  private var activeVideoRequests: Set<String> = []

  private let photoService: PhotoLibraryServiceProtocol
  private let persistenceService: SessionPersistenceServiceProtocol
  public var displayTargetSize: CGSize = CGSize(width: 900, height: 1200)

  public init(
    assets: [AssetModel],
    photoService: PhotoLibraryServiceProtocol,
    persistenceService: SessionPersistenceServiceProtocol = SessionPersistenceService()
  ) {
    self.remainingAssets = assets
    self.photoService = photoService
    self.persistenceService = persistenceService
    preloadWindow()
  }

  public init(
    restoringSavedState state: SavedSessionState,
    allAssets: [AssetModel],
    photoService: PhotoLibraryServiceProtocol,
    persistenceService: SessionPersistenceServiceProtocol = SessionPersistenceService()
  ) {
    let assetMap = Dictionary(uniqueKeysWithValues: allAssets.map { ($0.id, $0) })
    
    self.historyStack = state.classifiedAssets.compactMap { saved in
      guard let asset = assetMap[saved.assetID] else { return nil }
      return ClassifiedAsset(asset: asset, decision: saved.decision, timestamp: saved.timestamp)
    }
    
    self.remainingAssets = state.remainingAssetIDs.compactMap { assetMap[$0] }
    self.photoService = photoService
    self.persistenceService = persistenceService
    preloadWindow()
  }

  /// Atomic classification method. Ignores overlapping calls while a swipe animation is in flight.
  public func processDecision(_ decision: SwipeDecision) {
    guard !swipeInFlight, let asset = remainingAssets.first else { return }
    swipeInFlight = true

    historyStack.append(ClassifiedAsset(asset: asset, decision: decision, timestamp: Date()))
    if historyStack.count > Self.historyLimit {
      historyStack.removeFirst()
    }

    releaseResources(for: asset)
    remainingAssets.removeFirst()
    preloadWindow()
    persistCurrentState()
  }

  public func swipeAnimationCompleted() {
    swipeInFlight = false
  }

  public func undoLastDecision() {
    guard !swipeInFlight, let last = historyStack.popLast() else { return }
    remainingAssets.insert(last.asset, at: 0)
    preloadWindow()
    persistCurrentState()
  }

  private func persistCurrentState() {
    let savedClassified = historyStack.map {
      SavedClassifiedAsset(assetID: $0.asset.id, decision: $0.decision, timestamp: $0.timestamp)
    }
    let remainingIDs = remainingAssets.map(\.id)
    let state = SavedSessionState(lastModified: Date(), classifiedAssets: savedClassified, remainingAssetIDs: remainingIDs)
    persistenceService.saveSession(state)
  }

  public func image(for asset: AssetModel) -> UIImage? {
    imageCache[asset.id]
  }

  public func playerItem(for asset: AssetModel) -> AVPlayerItem? {
    playerItemCache[asset.id]
  }

  public func updateDisplayTargetSize(_ size: CGSize) {
    guard size.width > 0, size.height > 0, size != displayTargetSize else { return }
    self.displayTargetSize = size
    preloadWindow()
  }

  // MARK: - Private Memory & Preload Management

  private func releaseResources(for asset: AssetModel) {
    if let requestID = activeRequests.removeValue(forKey: asset.id) {
      photoService.cancelImageRequest(requestID)
    }
    activeVideoRequests.remove(asset.id)
    imageCache.removeValue(forKey: asset.id)
    playerItemCache.removeValue(forKey: asset.id)
  }

  public func preloadWindow() {
    let window = Array(remainingAssets.prefix(3))
    let wantedIDs = Set(window.map(\.id))

    // Cancel requests for assets that fell out of the prefetch window
    let currentActiveKeys = Array(activeRequests.keys)
    for id in currentActiveKeys where !wantedIDs.contains(id) {
      if let reqID = activeRequests.removeValue(forKey: id) {
        photoService.cancelImageRequest(reqID)
      }
      activeVideoRequests.remove(id)
      imageCache.removeValue(forKey: id)
      playerItemCache.removeValue(forKey: id)
    }

    for asset in window {
      let assetID = asset.id
      let size = displayTargetSize

      // 1. Fetch image if not cached and not already in flight
      if imageCache[assetID] == nil && activeRequests[assetID] == nil {
        activeRequests[assetID] = PHInvalidImageRequestID

        Task { @MainActor [weak self, photoService] in
          guard let self else { return }
          let image = await photoService.requestThumbnail(
            for: asset,
            targetSize: size,
            onRequestID: { [weak self] requestID in
              guard let self else { return }
              Task { @MainActor [self] in
                if self.activeRequests[assetID] != nil {
                  self.activeRequests[assetID] = requestID
                } else {
                  self.photoService.cancelImageRequest(requestID)
                }
              }
            },
            onProgressiveUpdate: { [weak self] highResImage in
              Task { @MainActor [self] in
                guard let self else { return }
                self.imageCache[assetID] = highResImage
              }
            }
          )

          self.activeRequests.removeValue(forKey: assetID)
          if let image {
            self.imageCache[assetID] = image
          }
        }
      }

      // 2. Fetch AVPlayerItem for video if not cached and not already in flight
      if asset.isVideo && playerItemCache[assetID] == nil && !activeVideoRequests.contains(assetID) {
        activeVideoRequests.insert(assetID)

        Task { @MainActor [weak self, photoService] in
          guard let self else { return }
          let item = await photoService.requestPlayerItem(
            for: asset,
            onRequestID: { _ in }
          )
          self.activeVideoRequests.remove(assetID)
          if let item {
            self.playerItemCache[assetID] = item
          }
        }
      }
    }
  }
}
