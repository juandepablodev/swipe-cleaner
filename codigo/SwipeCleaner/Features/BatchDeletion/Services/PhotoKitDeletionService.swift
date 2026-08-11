import Foundation
import Photos

/// Production PhotoKit deletion service handling resource size calculation and native deletion transactions.
public final class PhotoKitDeletionService: PhotoKitDeletionServiceProtocol, @unchecked Sendable {
  private static let userCancelledCode = 3072
  private let photoLibrary: PHPhotoLibrary

  public init(photoLibrary: PHPhotoLibrary = .shared()) {
    self.photoLibrary = photoLibrary
  }

  public func estimateSize(for assets: [AssetModel]) async -> SizeEstimate {
    await Task.detached(priority: .userInitiated) {
      let (found, _) = self.resolvePHAssets(from: assets)
      var total: Int64 = 0
      var unknown = 0

      for phAsset in found {
        let resources = PHAssetResource.assetResources(for: phAsset)
        var assetBytes: Int64 = 0
        var hasUnknown = false

        for resource in resources {
          if let size = resource.value(forKey: "fileSize") as? Int64 {
            assetBytes += size
          } else {
            hasUnknown = true
          }
        }
        
        total += assetBytes
        if hasUnknown {
          unknown += 1
        }
      }

      return SizeEstimate(totalBytes: total, assetsWithUnknownSize: unknown)
    }.value
  }

  public func deleteAssets(_ assets: [AssetModel]) async throws -> DeletionOutcome {
    let (found, missing) = await Task.detached(priority: .userInitiated) {
      self.resolvePHAssets(from: assets)
    }.value

    guard !found.isEmpty else {
      return DeletionOutcome(deletedIDs: [], inaccessibleIDs: missing)
    }

    let deletedIDs = found.map(\.localIdentifier)
    let nsArray = found as NSArray

    do {
      try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        photoLibrary.performChanges({
          PHAssetChangeRequest.deleteAssets(nsArray)
        }, completionHandler: { success, error in
          if let error {
            cont.resume(throwing: error)
          } else if success {
            cont.resume()
          } else {
            cont.resume(throwing: DeletionError.deletionFailed("Unknown system error"))
          }
        })
      }
      return DeletionOutcome(deletedIDs: deletedIDs, inaccessibleIDs: missing)
    } catch let nsError as NSError where nsError.domain == "PHPhotosErrorDomain" && nsError.code == Self.userCancelledCode {
      throw DeletionError.userCancelled
    } catch {
      throw DeletionError.deletionFailed(error.localizedDescription)
    }
  }

  private func resolvePHAssets(from models: [AssetModel]) -> (found: [PHAsset], missing: [String]) {
    let ids = models.map(\.id)
    guard !ids.isEmpty else { return ([], []) }

    let options = PHFetchOptions()
    let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: options)
    
    var found: [PHAsset] = []
    var foundIDs = Set<String>()
    
    result.enumerateObjects { asset, _, _ in
      found.append(asset)
      foundIDs.insert(asset.localIdentifier)
    }
    
    let missing = ids.filter { !foundIDs.contains($0) }
    return (found, missing)
  }
}
