import SwiftUI
import AVFoundation

public struct VideoPlayerView: UIViewRepresentable {
  let player: AVPlayer

  public init(player: AVPlayer) {
    self.player = player
  }

  public func makeUIView(context: Context) -> PlayerUIView {
    let view = PlayerUIView()
    view.playerLayer.player = player
    view.playerLayer.videoGravity = .resizeAspect
    return view
  }

  public func updateUIView(_ uiView: PlayerUIView, context: Context) {
    if uiView.playerLayer.player !== player {
      uiView.playerLayer.player = player
    }
  }

  public static func dismantleUIView(_ uiView: PlayerUIView, coordinator: ()) {
    uiView.playerLayer.player = nil
  }

  public final class PlayerUIView: UIView {
    override public class var layerClass: AnyClass {
      AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
      layer as! AVPlayerLayer
    }

    override public func layoutSubviews() {
      super.layoutSubviews()
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      playerLayer.frame = bounds
      CATransaction.commit()
    }
  }
}
