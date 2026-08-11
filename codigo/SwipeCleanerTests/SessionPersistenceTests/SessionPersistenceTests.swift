import Testing
import Foundation
@testable import SwipeCleaner

@Suite struct SessionPersistenceTests {
  @Test func testSaveAndLoadSessionState() async throws {
    let fakePersistence = FakeSessionPersistenceService()
    let asset0 = AssetModel(id: "asset-0", mediaType: .image, duration: 0, creationDate: Date(), pixelWidth: 100, pixelHeight: 100)
    let asset1 = AssetModel(id: "asset-1", mediaType: .image, duration: 0, creationDate: Date(), pixelWidth: 100, pixelHeight: 100)
    
    let classified = [
      SavedClassifiedAsset(assetID: asset0.id, decision: .keep, timestamp: Date())
    ]
    let state = SavedSessionState(lastModified: Date(), classifiedAssets: classified, remainingAssetIDs: [asset1.id])
    
    fakePersistence.saveSession(state)
    
    let loaded = fakePersistence.loadSavedSession()
    #expect(loaded != nil)
    #expect(loaded?.classifiedAssets.count == 1)
    #expect(loaded?.classifiedAssets.first?.assetID == "asset-0")
    #expect(loaded?.remainingAssetIDs == ["asset-1"])
  }

  @Test func testClearSavedSession() async throws {
    let fakePersistence = FakeSessionPersistenceService()
    let state = SavedSessionState(lastModified: Date(), classifiedAssets: [], remainingAssetIDs: ["asset-0"])
    
    fakePersistence.saveSession(state)
    #expect(fakePersistence.loadSavedSession() != nil)
    
    fakePersistence.clearSavedSession()
    #expect(fakePersistence.loadSavedSession() == nil)
  }

  @Test func testSwipeEngineRestoresFromSavedState() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5)
    let allAssets = fakeService.mockAssets
    let fakePersistence = FakeSessionPersistenceService()

    let savedClassified = [
      SavedClassifiedAsset(assetID: allAssets[0].id, decision: .keep, timestamp: Date()),
      SavedClassifiedAsset(assetID: allAssets[1].id, decision: .delete, timestamp: Date())
    ]
    let remainingIDs = [allAssets[2].id, allAssets[3].id, allAssets[4].id]
    let state = SavedSessionState(lastModified: Date(), classifiedAssets: savedClassified, remainingAssetIDs: remainingIDs)

    let viewModel = await SwipeEngineViewModel(
      restoringSavedState: state,
      allAssets: allAssets,
      photoService: fakeService,
      persistenceService: fakePersistence
    )

    #expect(await viewModel.historyStack.count == 2)
    #expect(await viewModel.pendingDeletionCount == 1)
    #expect(await viewModel.remainingAssets.count == 3)
    #expect(await viewModel.currentAsset?.id == allAssets[2].id)
  }
}
