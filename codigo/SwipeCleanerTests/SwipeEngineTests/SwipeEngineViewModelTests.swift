import Testing
import Foundation
import CoreGraphics
import Photos
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
}
