import Foundation
import Photos
import UIKit
@preconcurrency import AVFoundation

/// Production implementation of PhotoLibraryServiceProtocol interfacing with PhotoKit.
public final class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol, @unchecked Sendable {
  private let imageManager: PHCachingImageManager
  private let photoLibrary: PHPhotoLibrary
  private var fetchResult: PHFetchResult<PHAsset>?
  private var assetIndex: [String: PHAsset] = [:]
  private var continuation: AsyncStream<AssetLibraryChange>.Continuation?

  public init(
    imageManager: PHCachingImageManager = PHCachingImageManager(),
    photoLibrary: PHPhotoLibrary = .shared()
  ) {
    self.imageManager = imageManager
    self.photoLibrary = photoLibrary
    super.init()
    self.photoLibrary.register(self)
  }

  deinit {
    photoLibrary.unregisterChangeObserver(self)
  }

  public var authorizationStatus: PHAuthorizationStatus {
    PHPhotoLibrary.authorizationStatus(for: .readWrite)
  }

  public func requestAuthorization() async -> PHAuthorizationStatus {
    await PHPhotoLibrary.requestAuthorization(for: .readWrite)
  }

  public func fetchAssetCount() async -> Int {
    let result = getOrFetchResult()
    return result.count
  }

  public func fetchAssets(in range: Range<Int>) async -> [AssetModel] {
    let result = getOrFetchResult()
    guard !range.isEmpty, range.lowerBound >= 0, range.upperBound <= result.count else {
      return []
    }
    
    var assets: [AssetModel] = []
    assets.reserveCapacity(range.count)
    
    for index in range {
      let phAsset = result.object(at: index)
      assets.append(phAsset.toAssetModel())
    }
    
    return assets
  }

  public func requestThumbnail(
    for asset: AssetModel,
    targetSize: CGSize,
    onRequestID: @Sendable (PHImageRequestID) -> Void,
    onProgressiveUpdate: (@Sendable (UIImage) -> Void)? = nil
  ) async -> UIImage? {
    let result = getOrFetchResult()
    guard let phAsset = fetchPHAsset(with: asset.id, in: result) else {
      return nil
    }

    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false // Privacy invariant: local-only access
    options.deliveryMode = .opportunistic
    options.resizeMode = .exact
    options.isSynchronous = false

    let state = RequestState<UIImage>()

    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        state.setContinuation(continuation)
        let reqID = imageManager.requestImage(
          for: phAsset,
          targetSize: targetSize,
          contentMode: .aspectFill,
          options: options
        ) { image, info in
          let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

          if let image {
            if isDegraded {
              if !state.hasAlreadyResumed {
                onProgressiveUpdate?(image)
              }
            } else {
              state.resumeOnce(with: image)
            }
          } else {
            state.resumeOnce(with: nil)
          }
        }
        if state.setRequestID(reqID) {
          imageManager.cancelImageRequest(reqID)
        }
        onRequestID(reqID)
      }
    } onCancel: {
      if let reqID = state.cancel() {
        imageManager.cancelImageRequest(reqID)
      }
    }
  }

  public func requestPlayerItem(
    for asset: AssetModel,
    onRequestID: @Sendable (PHImageRequestID) -> Void
  ) async -> AVPlayerItem? {
    let result = getOrFetchResult()
    guard let phAsset = fetchPHAsset(with: asset.id, in: result) else {
      return nil
    }

    let options = PHVideoRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .automatic
    options.version = .current

    let state = RequestState<AVPlayerItem>()

    return await withTaskCancellationHandler {
      await withCheckedContinuation { continuation in
        state.setContinuation(continuation)
        let reqID = imageManager.requestPlayerItem(forVideo: phAsset, options: options) { playerItem, info in
          let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
          let isError = info?[PHImageErrorKey] != nil

          if let playerItem, !isCancelled && !isError {
            state.resumeOnce(with: playerItem)
          } else {
            state.resumeOnce(with: nil)
          }
        }
        if state.setRequestID(reqID) {
          imageManager.cancelImageRequest(reqID)
        }
        onRequestID(reqID)
      }
    } onCancel: {
      if let reqID = state.cancel() {
        imageManager.cancelImageRequest(reqID)
      }
    }
  }

  public func cancelImageRequest(_ requestID: PHImageRequestID) {
    imageManager.cancelImageRequest(requestID)
  }

  public func startCaching(for assets: [AssetModel], targetSize: CGSize) {
    let phAssets = resolvePHAssets(for: assets)
    guard !phAssets.isEmpty else { return }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .opportunistic
    options.resizeMode = .exact
    imageManager.startCachingImages(for: phAssets, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  public func stopCaching(for assets: [AssetModel], targetSize: CGSize) {
    let phAssets = resolvePHAssets(for: assets)
    guard !phAssets.isEmpty else { return }
    let options = PHImageRequestOptions()
    options.isNetworkAccessAllowed = false
    options.deliveryMode = .opportunistic
    options.resizeMode = .exact
    imageManager.stopCachingImages(for: phAssets, targetSize: targetSize, contentMode: .aspectFill, options: options)
  }

  public func changeStream() -> AsyncStream<AssetLibraryChange> {
    AsyncStream { continuation in
      self.continuation = continuation
      continuation.onTermination = { [weak self] _ in
        self?.continuation = nil
      }
    }
  }

  // MARK: - Private Helpers

  private func getOrFetchResult() -> PHFetchResult<PHAsset> {
    if let result = fetchResult {
      return result
    }
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    let result = PHAsset.fetchAssets(with: fetchOptions)
    self.fetchResult = result
    
    var index: [String: PHAsset] = [:]
    index.reserveCapacity(result.count)
    result.enumerateObjects { asset, _, _ in
      index[asset.localIdentifier] = asset
    }
    self.assetIndex = index
    
    return result
  }

  private func fetchPHAsset(with id: String, in result: PHFetchResult<PHAsset>) -> PHAsset? {
    if let phAsset = assetIndex[id] {
      return phAsset
    }
    let options = PHFetchOptions()
    return PHAsset.fetchAssets(withLocalIdentifiers: [id], options: options).firstObject
  }

  private func resolvePHAssets(for assets: [AssetModel]) -> [PHAsset] {
    let identifiers = assets.map(\.id)
    guard !identifiers.isEmpty else { return [] }
    var phAssets: [PHAsset] = []
    phAssets.reserveCapacity(identifiers.count)
    for id in identifiers {
      if let phAsset = fetchPHAsset(with: id, in: getOrFetchResult()) {
        phAssets.append(phAsset)
      }
    }
    return phAssets
  }
}

extension PhotoLibraryService: PHPhotoLibraryChangeObserver {
  public func photoLibraryDidChange(_ changeInstance: PHChange) {
    guard let currentResult = fetchResult,
          let details = changeInstance.changeDetails(for: currentResult) else {
      return
    }

    let newResult = details.fetchResultAfterChanges
    self.fetchResult = newResult
    
    var index: [String: PHAsset] = [:]
    index.reserveCapacity(newResult.count)
    var snapshot: [AssetModel] = []
    snapshot.reserveCapacity(newResult.count)
    
    newResult.enumerateObjects { asset, _, _ in
      index[asset.localIdentifier] = asset
      snapshot.append(asset.toAssetModel())
    }
    self.assetIndex = index

    let change = AssetLibraryChange(
      inserted: details.insertedIndexes ?? IndexSet(),
      removed: details.removedIndexes ?? IndexSet(),
      changed: details.changedIndexes ?? IndexSet(),
      snapshotAfter: snapshot,
      hasIncrementalChanges: details.hasIncrementalChanges
    )

    continuation?.yield(change)
  }
}

private extension PHAsset {
  func toAssetModel() -> AssetModel {
    AssetModel(
      id: localIdentifier,
      mediaType: mediaType,
      duration: duration,
      creationDate: creationDate,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight
    )
  }
}

private final class RequestState<T>: @unchecked Sendable {
  private let lock = NSLock()
  private var requestID: PHImageRequestID?
  private var continuation: CheckedContinuation<T?, Never>?
  private var hasResumed = false
  private var isCancelled = false

  var hasAlreadyResumed: Bool {
    lock.lock()
    defer { lock.unlock() }
    return hasResumed
  }

  func setContinuation(_ continuation: CheckedContinuation<T?, Never>) {
    lock.lock()
    if isCancelled || hasResumed {
      hasResumed = true
      lock.unlock()
      continuation.resume(returning: nil)
      return
    }
    self.continuation = continuation
    lock.unlock()
  }

  /// Sets the requestID. Returns true if the request was already cancelled and should be aborted immediately.
  @discardableResult
  func setRequestID(_ id: PHImageRequestID) -> Bool {
    lock.lock()
    requestID = id
    let cancelled = isCancelled
    lock.unlock()
    return cancelled
  }

  func getRequestID() -> PHImageRequestID? {
    lock.lock()
    defer { lock.unlock() }
    return requestID
  }

  func resumeOnce(with value: T?) {
    lock.lock()
    guard !hasResumed else {
      lock.unlock()
      return
    }
    hasResumed = true
    let cont = continuation
    continuation = nil
    lock.unlock()

    cont?.resume(returning: value)
  }

  /// Marks request cancelled, resumes any pending continuation with nil, and returns the requestID if set.
  @discardableResult
  func cancel() -> PHImageRequestID? {
    lock.lock()
    isCancelled = true
    let reqID = requestID
    guard !hasResumed, let cont = continuation else {
      lock.unlock()
      return reqID
    }
    hasResumed = true
    continuation = nil
    lock.unlock()

    cont.resume(returning: nil)
    return reqID
  }
}


