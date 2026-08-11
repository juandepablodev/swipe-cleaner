import Foundation
import SwiftUI

@Observable
@MainActor
public final class SessionSummaryViewModel {
  public private(set) var session: SessionResult
  public private(set) var estimatedSizeText: String = "Calculating..."
  public private(set) var isDeleting: Bool = false
  public private(set) var deletionInFlight: Bool = false
  public private(set) var deletionCompleted: Bool = false
  public private(set) var deletionOutcome: DeletionOutcome? = nil
  public var userMessage: String? = nil

  private let deletionService: PhotoKitDeletionServiceProtocol
  private let persistenceService: SessionPersistenceServiceProtocol

  public init(
    session: SessionResult,
    deletionService: PhotoKitDeletionServiceProtocol,
    persistenceService: SessionPersistenceServiceProtocol = SessionPersistenceService()
  ) {
    self.session = session
    self.deletionService = deletionService
    self.persistenceService = persistenceService
    Task {
      await computeSize()
    }
  }

  public func computeSize() async {
    guard !session.pendingDeletion.isEmpty else {
      self.estimatedSizeText = "0 MB"
      return
    }

    let estimate = await deletionService.estimateSize(for: session.pendingDeletion)
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    let baseString = formatter.string(fromByteCount: estimate.totalBytes)

    if estimate.assetsWithUnknownSize > 0 {
      self.estimatedSizeText = "≥ \(baseString)"
    } else {
      self.estimatedSizeText = baseString
    }
  }

  public func executeBatchDeletion() async {
    guard !deletionInFlight, !deletionCompleted, !session.pendingDeletion.isEmpty else { return }
    deletionInFlight = true
    isDeleting = true
    userMessage = nil
    defer {
      isDeleting = false
      deletionInFlight = false
    }

    do {
      let outcome = try await deletionService.deleteAssets(session.pendingDeletion)
      self.deletionOutcome = outcome
      self.deletionCompleted = true
      persistenceService.clearSavedSession()
    } catch DeletionError.userCancelled {
      self.userMessage = "Operación cancelada. Tus fotos no han sido modificadas."
    } catch DeletionError.deletionFailed(let detail) {
      self.userMessage = "No se pudo completar la eliminación. Puedes reintentarlo. (\(detail))"
    } catch {
      self.userMessage = "Error inesperado al eliminar."
    }
  }
}
