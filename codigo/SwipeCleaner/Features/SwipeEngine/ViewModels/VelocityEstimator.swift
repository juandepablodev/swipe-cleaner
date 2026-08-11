import Foundation
import CoreGraphics

/// Velocity estimator for DragGesture in iOS 17.
/// Maintains translation samples over a 100 ms sliding window to calculate horizontal velocity (Δx/Δt).
public struct VelocityEstimator: Sendable {
  private var samples: [(x: CGFloat, t: TimeInterval)] = []
  private let window: TimeInterval

  public init(window: TimeInterval = 0.1) {
    self.window = window
  }

  public mutating func add(x: CGFloat, at t: TimeInterval) {
    samples.append((x, t))
    samples.removeAll { t - $0.t > window }
  }

  public mutating func reset() {
    samples.removeAll()
  }

  public var horizontalVelocity: CGFloat {
    guard let first = samples.first, let last = samples.last, last.t > first.t else { return 0 }
    let deltaX = last.x - first.x
    let deltaT = last.t - first.t
    guard deltaT > 0 else { return 0 }
    return deltaX / CGFloat(deltaT)
  }
}
