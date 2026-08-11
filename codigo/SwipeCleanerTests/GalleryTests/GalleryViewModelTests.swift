import Testing
import Foundation
import Photos
@testable import SwipeCleaner

@Suite struct GalleryViewModelTests {
  @Test func testGalleryLoadsSyntheticAssetsInReverseChronologicalOrder() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5000)
    let viewModel = await GalleryViewModel(photoService: fakeService)

    let startTime = Date()
    await viewModel.checkAndRequestPermission()
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 10.0, "Gallery loading for 5,000 synthetic assets must complete in < 10s")
    let assets = await viewModel.assets
    #expect(assets.count == 5000)
    #expect(assets.first?.id == "synthetic-asset-0")
    #expect(assets.last?.id == "synthetic-asset-4999")
  }

  @Test func testPrefetchWindowCachingRange() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 100)
    let viewModel = await GalleryViewModel(photoService: fakeService)
    await viewModel.loadGallery()

    let visibleIndices = IndexSet(integersIn: 10...20)
    let targetSize = CGSize(width: 200, height: 200)

    await viewModel.updatePrefetchWindow(visibleIndices: visibleIndices, targetSize: targetSize)

    #expect(fakeService.startCachingCalls.count == 1)
    let firstCall = fakeService.startCachingCalls.first
    #expect(firstCall?.targetSize == targetSize)
    #expect(firstCall?.assets.count == 43) // range 0..<43 (10 - 2*11 = 0, 20 + 2*11 + 1 = 43)
  }

  @Test func testIncrementalDiffApplication() async throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5)
    let viewModel = await GalleryViewModel(photoService: fakeService)
    await viewModel.loadGallery()

    let initialCount = await viewModel.assets.count
    #expect(initialCount == 5)

    var updatedAssets = fakeService.mockAssets
    updatedAssets.remove(at: 2)

    let change = AssetLibraryChange(
      inserted: [],
      removed: IndexSet(integer: 2),
      changed: [],
      snapshotAfter: updatedAssets,
      hasIncrementalChanges: true
    )

    await viewModel.apply(change)

    let newAssets = await viewModel.assets
    #expect(newAssets.count == 4)
    #expect(!newAssets.contains(where: { $0.id == "synthetic-asset-2" }))
  }
}
