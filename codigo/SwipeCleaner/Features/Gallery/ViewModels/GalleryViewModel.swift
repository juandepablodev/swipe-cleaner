import Foundation
import Photos
import SwiftUI

@Observable
@MainActor
public final class GalleryViewModel {
  public private(set) var authorizationStatus: PHAuthorizationStatus = .notDetermined
  public private(set) var assets: [AssetModel] = []
  public private(set) var isLoading: Bool = false
  public var errorMessage: String? = nil

  private let photoService: PhotoLibraryServiceProtocol
  nonisolated private var changeTask: Task<Void, Never>?

  public init(photoService: PhotoLibraryServiceProtocol) {
    self.photoService = photoService
    self.authorizationStatus = photoService.authorizationStatus
  }

  deinit {
    changeTask?.cancel()
  }

  public func checkAndRequestPermission() async {
    let current = photoService.authorizationStatus
    if current == .notDetermined {
      let requested = await photoService.requestAuthorization()
      self.authorizationStatus = requested
    } else {
      self.authorizationStatus = current
    }

    if authorizationStatus == .authorized || authorizationStatus == .limited {
      await loadGallery()
    }
  }

  public func loadGallery() async {
    isLoading = true
    defer { isLoading = false }
    
    let count = await photoService.fetchAssetCount()
    if count > 0 {
      self.assets = await photoService.fetchAssets(in: 0..<count)
    } else {
      self.assets = []
    }
    
    startObservingChanges()
  }

  public func apply(_ change: AssetLibraryChange) {
    guard change.hasIncrementalChanges else {
      self.assets = change.snapshotAfter
      return
    }

    var currentAssets = self.assets
    
    for i in change.removed.sorted().reversed() {
      if i >= 0 && i < currentAssets.count {
        currentAssets.remove(at: i)
      }
    }
    
    for i in change.inserted.sorted() {
      if i >= 0 && i <= currentAssets.count && i < change.snapshotAfter.count {
        currentAssets.insert(change.snapshotAfter[i], at: i)
      }
    }
    
    for i in change.changed {
      if i >= 0 && i < currentAssets.count && i < change.snapshotAfter.count {
        currentAssets[i] = change.snapshotAfter[i]
      }
    }

    // Safety fallback: if diff count mismatch occurs, force snapshotAfter
    if currentAssets.count == change.snapshotAfter.count {
      self.assets = currentAssets
    } else {
      self.assets = change.snapshotAfter
    }
  }

  public func updatePrefetchWindow(visibleIndices: IndexSet, targetSize: CGSize) {
    guard let lo = visibleIndices.min(), let hi = visibleIndices.max() else { return }
    let page = max(hi - lo + 1, 1)
    let lowerBound = max(lo - 2 * page, 0)
    let upperBound = min(hi + 2 * page + 1, assets.count)
    
    guard lowerBound < upperBound else { return }
    let prefetchAssets = Array(assets[lowerBound..<upperBound])
    photoService.startCaching(for: prefetchAssets, targetSize: targetSize)
  }

  public func requestThumbnail(
    for asset: AssetModel,
    targetSize: CGSize,
    onRequestID: @Sendable (PHImageRequestID) -> Void
  ) async -> UIImage? {
    await photoService.requestThumbnail(for: asset, targetSize: targetSize, onRequestID: onRequestID)
  }

  public func cancelThumbnailRequest(_ requestID: PHImageRequestID) {
    photoService.cancelImageRequest(requestID)
  }

  private func startObservingChanges() {
    changeTask?.cancel()
    let stream = photoService.changeStream()
    changeTask = Task { [weak self] in
      for await change in stream {
        guard let self else { break }
        self.apply(change)
      }
    }
  }
}
