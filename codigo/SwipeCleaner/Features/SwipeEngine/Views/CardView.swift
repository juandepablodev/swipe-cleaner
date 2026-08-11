import SwiftUI
import AVFoundation

struct CardView: View {
  let asset: AssetModel
  let image: UIImage?
  let playerItem: AVPlayerItem?
  let isTopCard: Bool
  let dragOffset: CGSize

  @State private var player: AVPlayer?
  @State private var isMuted: Bool = true
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    asset: AssetModel,
    image: UIImage?,
    playerItem: AVPlayerItem? = nil,
    isTopCard: Bool,
    dragOffset: CGSize
  ) {
    self.asset = asset
    self.image = image
    self.playerItem = playerItem
    self.isTopCard = isTopCard
    self.dragOffset = dragOffset
  }

  var body: some View {
    ZStack(alignment: .top) {
      // Main Card Background & Media Content
      RoundedRectangle(cornerRadius: 24)
        .fill(Color(uiColor: .black))
        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        .overlay {
          ZStack(alignment: .center) {
            // Media Content (Video or Image)
            if asset.isVideo && isTopCard, let player {
              VideoPlayerView(player: player)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(8)
                .overlay(alignment: .bottomLeading) {
                  Button {
                    isMuted.toggle()
                    player.isMuted = isMuted
                  } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                      .font(.body.bold())
                      .foregroundStyle(.white)
                      .padding(10)
                      .background(.ultraThinMaterial)
                      .clipShape(Circle())
                  }
                  .padding(20)
                }
            } else if let image {
              Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(8)
                .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
            } else {
              ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            }

            // Video Duration & Type Badge
            if asset.isVideo {
              VStack {
                Spacer()
                HStack {
                  Spacer()
                  HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                      .font(.caption.bold())
                    Text(asset.formattedDuration)
                      .font(.caption.bold())
                  }
                  .foregroundStyle(.white)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(Color.black.opacity(0.75))
                  .clipShape(Capsule())
                  .padding(20)
                }
              }
            }
          }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))

      // Intention Badges ("CONSERVAR" / "ELIMINAR")
      if isTopCard {
        HStack {
          if dragOffset.width > 20 {
            Text("CONSERVAR")
              .font(.title2.bold())
              .foregroundStyle(.green)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(Color.green.opacity(0.15))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.green, lineWidth: 3)
              )
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .rotationEffect(.degrees(-15))
              .padding(.leading, 24)
              .padding(.top, 28)
              .opacity(min(Double(dragOffset.width) / 100.0, 1.0))
            Spacer()
          } else if dragOffset.width < -20 {
            Spacer()
            Text("ELIMINAR")
              .font(.title2.bold())
              .foregroundStyle(.red)
              .padding(.horizontal, 14)
              .padding(.vertical, 8)
              .background(Color.red.opacity(0.15))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.red, lineWidth: 3)
              )
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .rotationEffect(.degrees(15))
              .padding(.trailing, 24)
              .padding(.top, 28)
              .opacity(min(Double(-dragOffset.width) / 100.0, 1.0))
          }
        }
      }
    }
    .rotationEffect(reduceMotion ? .zero : .degrees(Double(dragOffset.width / 20.0)))
    .offset(x: dragOffset.width, y: dragOffset.height)
    .onChange(of: playerItem) { _, newItem in
      setupPlayer(with: newItem)
    }
    .onChange(of: isTopCard) { _, newIsTopCard in
      if newIsTopCard {
        player?.play()
      } else {
        player?.pause()
      }
    }
    .onAppear {
      if let playerItem {
        setupPlayer(with: playerItem)
      }
    }
    .onDisappear {
      player?.pause()
      player = nil
    }
  }

  private func setupPlayer(with item: AVPlayerItem?) {
    guard let item else {
      player?.pause()
      player = nil
      return
    }
    let newPlayer = AVPlayer(playerItem: item)
    newPlayer.isMuted = isMuted
    newPlayer.actionAtItemEnd = .none
    
    NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { _ in
      newPlayer.seek(to: .zero)
      newPlayer.play()
    }
    
    self.player = newPlayer
    if isTopCard {
      newPlayer.play()
    }
  }
}
