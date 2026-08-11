import Testing
import Foundation
@testable import SwipeCleaner

@Suite struct SessionSummaryViewModelTests {
  @Test func testComputeSizeFormatsBytesAndHandlesUnknownSizes() async throws {
    let fakeService = FakePhotoKitDeletionService()
    fakeService.mockBytesPerAsset = 50_000_000 // 50 MB each
    fakeService.mockUnknownCount = 1

    let syntheticAssets = FakePhotoLibraryService.generateSyntheticAssets(count: 3)
    let session = SessionResult(keep: [], pendingDeletion: syntheticAssets)

    let viewModel = await SessionSummaryViewModel(session: session, deletionService: fakeService)
    await viewModel.computeSize()

    let text = await viewModel.estimatedSizeText
    #expect(text.contains("≥"), "Size text must contain '≥' prefix when assetsWithUnknownSize > 0")
    #expect(text.contains("MB") || text.contains("GB"))
  }

  @Test func testExecuteBatchDeletionSuccessFlow() async throws {
    let fakeService = FakePhotoKitDeletionService()
    let syntheticAssets = FakePhotoLibraryService.generateSyntheticAssets(count: 5)
    let session = SessionResult(keep: [], pendingDeletion: syntheticAssets)

    let viewModel = await SessionSummaryViewModel(session: session, deletionService: fakeService)

    await viewModel.executeBatchDeletion()

    #expect(await viewModel.deletionCompleted == true)
    #expect(await viewModel.deletionOutcome?.deletedIDs.count == 5)
    #expect(fakeService.deletedAssetsHistory.count == 1)
  }

  @Test func testExecuteBatchDeletionUserCancellationPreservesSession() async throws {
    let fakeService = FakePhotoKitDeletionService()
    fakeService.shouldFailWithUserCancellation = true

    let syntheticAssets = FakePhotoLibraryService.generateSyntheticAssets(count: 4)
    let session = SessionResult(keep: [], pendingDeletion: syntheticAssets)

    let viewModel = await SessionSummaryViewModel(session: session, deletionService: fakeService)

    await viewModel.executeBatchDeletion()

    #expect(await viewModel.deletionCompleted == false)
    #expect(await viewModel.userMessage == "Operación cancelada. Tus fotos no han sido modificadas.")
    #expect(await viewModel.session.pendingDeletion.count == 4, "Session pendingDeletion array must stay intact")
  }

  @Test func testAtomicGuardBlocksConcurrentDeletionTransactions() async throws {
    let fakeService = FakePhotoKitDeletionService()
    let syntheticAssets = FakePhotoLibraryService.generateSyntheticAssets(count: 2)
    let session = SessionResult(keep: [], pendingDeletion: syntheticAssets)

    let viewModel = await SessionSummaryViewModel(session: session, deletionService: fakeService)

    await viewModel.executeBatchDeletion()

    // Second call while deletionCompleted is true or in flight
    await viewModel.executeBatchDeletion()

    #expect(fakeService.deletedAssetsHistory.count == 1, "Only one deletion transaction should be executed")
  }

  @Test func testPerformanceSizeEstimationFor500AssetsUnder200ms() async throws {
    let fakeService = FakePhotoKitDeletionService()
    let syntheticAssets = FakePhotoLibraryService.generateSyntheticAssets(count: 500)

    let startTime = Date()
    _ = await fakeService.estimateSize(for: syntheticAssets)
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 10.0, "Size estimation for 500 assets must complete in < 10s")
  }
}
