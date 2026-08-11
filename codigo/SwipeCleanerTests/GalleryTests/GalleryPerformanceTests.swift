import XCTest
@testable import SwipeCleaner

@MainActor
final class GalleryPerformanceTests: XCTestCase {
  func testPrefetchAndDiffPerformanceOn5000Assets() throws {
    let fakeService = FakePhotoLibraryService(authorizationStatus: .authorized, assetCount: 5000)
    let viewModel = GalleryViewModel(photoService: fakeService)
    
    measure(metrics: [XCTClockMetric()]) {
      viewModel.updatePrefetchWindow(
        visibleIndices: IndexSet(integersIn: 50...80),
        targetSize: CGSize(width: 300, height: 300)
      )
    }
  }
}
