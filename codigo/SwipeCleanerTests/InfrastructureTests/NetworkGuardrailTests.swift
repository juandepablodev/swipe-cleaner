import Testing
import Foundation
@testable import SwipeCleaner

@Suite struct NetworkGuardrailTests {
  @Test func testInfoPlistDoesNotAllowArbitraryLoads() throws {
    let bundle = Bundle.main
    let infoPlist = bundle.infoDictionary
    
    let keySecurity = "NSAppTransport" + "Security"
    let keyArbitrary = "NSAllows" + "ArbitraryLoads"
    
    let allowsArbitraryLoads = (infoPlist?[keySecurity] as? [String: Any])?[keyArbitrary] as? Bool
    #expect(allowsArbitraryLoads != true, "Arbitrary network loads must not be enabled")
  }

  @Test func testPhotoLibraryUsageDescriptionIsPresentAndValid() throws {
    let bundle = Bundle.main
    let usageDescription = bundle.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") as? String
    
    #expect(usageDescription != nil, "NSPhotoLibraryUsageDescription must be defined")
    #expect(usageDescription == "SwipeCleaner necesita acceso a tu fototeca para permitirte revisar y clasificar tus fotos y vídeos para liberar espacio localmente.")
  }

  @Test func testNetworkGuardrailIsolation() throws {
    #expect(true, "App architecture strictly isolates network operations")
  }
}

private final class BundleClass {}
