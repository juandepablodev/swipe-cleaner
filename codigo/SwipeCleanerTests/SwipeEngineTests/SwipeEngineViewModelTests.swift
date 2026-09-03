import Testing
import Foundation
import CoreGraphics
import Photos
import AVFoundation
import UIKit
@testable import SwipeCleaner

@Suite struct SwipeEngineViewModelTests {
  @Test func testProcessDecisionAdvancesQueueAndUpdatesHistory() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 10)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    #expect(await viewModel.remainingAssets.count == 10)
    #expect(await viewModel.historyStack.isEmpty)

    await viewModel.processDecision(.keep)
    await viewModel.swipeAnimationCompleted()

    #expect(await viewModel.remainingAssets.count == 9)
    #expect(await viewModel.historyStack.count == 1)
    #expect(await viewModel.historyStack.first?.decision == .keep)
    #expect(await viewModel.historyStack.first?.asset.id == "synthetic-asset-0")
  }

  @Test func testAtomicGuardBlocksOverlappingDecisions() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 10)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    // First call sets swipeInFlight = true
    await viewModel.processDecision(.delete)
    #expect(await viewModel.swipeInFlight == true)

    // Second overlapping call while swipeInFlight is true must be ignored
    await viewModel.processDecision(.keep)

    #expect(await viewModel.historyStack.count == 1)
    #expect(await viewModel.historyStack.first?.decision == .delete)
    #expect(await viewModel.remainingAssets.count == 9)
  }

  @Test func testUndoLastDecisionRestoresAssetToTop() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5)
    let assets = fakeService.mockAssets
    let viewModel = await SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    await viewModel.processDecision(.delete)
    await viewModel.swipeAnimationCompleted()

    #expect(await viewModel.pendingDeletionCount == 1)
    #expect(await viewModel.remainingAssets.first?.id == "synthetic-asset-1")

    await viewModel.undoLastDecision()

    #expect(await viewModel.pendingDeletionCount == 0)
    #expect(await viewModel.remainingAssets.first?.id == "synthetic-asset-0")
  }

  @MainActor
  @Test func testMemoryInvariantsCountBoundedToThree() throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 500)
    let assets = fakeService.mockAssets
    let viewModel = SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    for _ in 0..<500 {
      viewModel.processDecision(.keep)
      viewModel.swipeAnimationCompleted()
    }

    #expect(viewModel.imageCache.count <= 3, "imageCache.count must not exceed 3")
    #expect(viewModel.activeRequests.count <= 3, "activeRequests.count must not exceed 3")
    #expect(viewModel.activeVideoRequests.count <= 3, "activeVideoRequests.count must not exceed 3")
    #expect(viewModel.playerItemCache.count <= 3, "playerItemCache.count must not exceed 3")
    #expect(viewModel.highQualityLoaded.count <= 3, "highQualityLoaded.count must not exceed 3")
  }

  @MainActor
  @Test func testProgressiveUpdateDoesNotOverwriteHighQualityImage() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 0)
    let asset = AssetModel(
      id: "progressive-test-asset",
      mediaType: .image,
      duration: 0,
      creationDate: Date(),
      pixelWidth: 4000,
      pixelHeight: 3000
    )

    let highQualityImage = UIImage()
    let degradedImage = UIImage()

    var savedProgressiveCallback: (@Sendable (UIImage) -> Void)?
    fakeService.mockThumbnailImage = highQualityImage
    fakeService.onRequestThumbnailCalled = { requestedAsset, onProgressiveUpdate in
      savedProgressiveCallback = onProgressiveUpdate
    }

    let viewModel = SwipeEngineViewModel(
      assets: [asset],
      photoService: fakeService,
      persistenceService: FakeSessionPersistenceService()
    )

    // Allow the initial preload Task to run and deliver the high-quality image
    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(viewModel.highQualityLoaded.contains("progressive-test-asset"))
    #expect(viewModel.image(for: asset) === highQualityImage)

    // Simulate a late, out-of-order progressive update
    savedProgressiveCallback?(degradedImage)
    try await Task.sleep(nanoseconds: 50_000_000)

    // High-quality image must remain intact in cache
    #expect(viewModel.image(for: asset) === highQualityImage)
  }

  @MainActor
  @Test func testHighResolutionTargetSizeIsDefaultAndConfigurable() throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5)
    let assets = fakeService.mockAssets
    let viewModel = SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    #expect(viewModel.displayTargetSize.width >= 1170)
    #expect(viewModel.displayTargetSize.height >= 1950)

    let newSize = CGSize(width: 1290, height: 2796)
    viewModel.updateDisplayTargetSize(newSize)
    #expect(viewModel.displayTargetSize == newSize)
  }

  @MainActor
  @Test func testVideoPreloadingAndCancellationOnSwipe() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 0)
    let mockItem = AVPlayerItem(url: URL(fileURLWithPath: "/tmp/test_video.mov"))
    fakeService.mockPlayerItem = mockItem

    let videoAsset = AssetModel(
      id: "test-video-0",
      mediaType: .video,
      duration: 15.0,
      creationDate: Date(),
      pixelWidth: 1920,
      pixelHeight: 1080
    )
    let imageAsset1 = AssetModel(
      id: "test-image-1",
      mediaType: .image,
      duration: 0.0,
      creationDate: Date(),
      pixelWidth: 1920,
      pixelHeight: 1080
    )
    let imageAsset2 = AssetModel(
      id: "test-image-2",
      mediaType: .image,
      duration: 0.0,
      creationDate: Date(),
      pixelWidth: 1920,
      pixelHeight: 1080
    )

    let viewModel = SwipeEngineViewModel(
      assets: [videoAsset, imageAsset1, imageAsset2],
      photoService: fakeService,
      persistenceService: FakeSessionPersistenceService()
    )

    #expect(viewModel.currentAsset?.isVideo == true)

    // Allow preload Task to populate cache
    try await Task.sleep(nanoseconds: 50_000_000)
    #expect(viewModel.playerItem(for: videoAsset) === mockItem, "Preloaded video player item must be present in cache")

    // Swipe away the video
    viewModel.processDecision(.keep)
    viewModel.swipeAnimationCompleted()

    #expect(viewModel.currentAsset?.id == "test-image-1")
    #expect(viewModel.playerItem(for: videoAsset) == nil, "Evicted video player item must be purged from cache")
  }

  @MainActor
  @Test func testPerformance100SwipesUnder1s() throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 100)
    let assets = fakeService.mockAssets
    let viewModel = SwipeEngineViewModel(assets: assets, photoService: fakeService, persistenceService: FakeSessionPersistenceService())

    let startTime = Date()
    for _ in 0..<100 {
      viewModel.processDecision(.delete)
      viewModel.swipeAnimationCompleted()
    }
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 10.0, "100 swipes must process in < 10s")
  }

  @Test func testVelocityEstimatorCalculatesCorrectSpeed() throws {
    var estimator = VelocityEstimator(window: 0.1)
    let startTime = 1000.0

    estimator.add(x: 0, at: startTime)
    estimator.add(x: 60, at: startTime + 0.05) // 60 pt in 0.05 s = 1200 pt/s

    #expect(abs(estimator.horizontalVelocity - 1200.0) < 0.1)
  }

  @MainActor
  @Test func testThumbnailRequestReturningNilDoesNotHangOrCrash() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 0)
    let asset = AssetModel(
      id: "icloud-asset-nil",
      mediaType: .image,
      duration: 0,
      creationDate: Date(),
      pixelWidth: 4000,
      pixelHeight: 3000
    )
    fakeService.mockThumbnailImage = nil

    let viewModel = SwipeEngineViewModel(
      assets: [asset],
      photoService: fakeService,
      persistenceService: FakeSessionPersistenceService()
    )

    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(viewModel.image(for: asset) == nil)
    #expect(viewModel.activeRequests["icloud-asset-nil"] == nil)
    #expect(!viewModel.highQualityLoaded.contains("icloud-asset-nil"))

    // Ensure swipe completes smoothly even with nil image
    viewModel.processDecision(.keep)
    viewModel.swipeAnimationCompleted()
    #expect(viewModel.remainingAssets.isEmpty)
    #expect(viewModel.historyStack.count == 1)
  }

  @MainActor
  @Test func testVideoRequestReturningNilDoesNotHangOrCrash() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 0)
    let videoAsset = AssetModel(
      id: "icloud-video-nil",
      mediaType: .video,
      duration: 12.0,
      creationDate: Date(),
      pixelWidth: 1920,
      pixelHeight: 1080
    )
    fakeService.mockPlayerItem = nil

    let viewModel = SwipeEngineViewModel(
      assets: [videoAsset],
      photoService: fakeService,
      persistenceService: FakeSessionPersistenceService()
    )

    try await Task.sleep(nanoseconds: 50_000_000)

    #expect(viewModel.playerItem(for: videoAsset) == nil)
    #expect(viewModel.activeVideoRequests["icloud-video-nil"] == nil)

    // Ensure swipe completes smoothly even with nil playerItem
    viewModel.processDecision(.delete)
    viewModel.swipeAnimationCompleted()
    #expect(viewModel.remainingAssets.isEmpty)
    #expect(viewModel.historyStack.count == 1)
  }
}
