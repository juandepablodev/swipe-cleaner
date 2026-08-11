import Foundation
import Photos

/// Asset model for the presentation layer.
/// Guaranteed 100% Sendable compliant without wrapping non-Sendable PHAsset objects.
public struct AssetModel: Identifiable, Sendable, Equatable {
  public let id: String
  public let mediaType: PHAssetMediaType
  public let duration: TimeInterval
  public let creationDate: Date?
  public let pixelWidth: Int
  public let pixelHeight: Int

  public init(
    id: String,
    mediaType: PHAssetMediaType,
    duration: TimeInterval = 0,
    creationDate: Date? = nil,
    pixelWidth: Int = 0,
    pixelHeight: Int = 0
  ) {
    self.id = id
    self.mediaType = mediaType
    self.duration = duration
    self.creationDate = creationDate
    self.pixelWidth = pixelWidth
    self.pixelHeight = pixelHeight
  }

  public var isVideo: Bool {
    mediaType == .video
  }

  public var formattedDuration: String {
    guard isVideo, duration > 0 else { return "" }
    let totalSeconds = Int(duration.rounded())
    let minutes = totalSeconds / 60
    let seconds = totalSeconds % 60
    return String(format: "%d:%02d", minutes, seconds)
  }

  public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }
}
