import SwiftUI
import AVFoundation

struct CardView: View {
  let asset: AssetModel
  let image: UIImage?
  let player: AVPlayer?
  let isTopCard: Bool
  let dragOffset: CGSize
  let isMuted: Bool
  let onToggleMute: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    asset: AssetModel,
    image: UIImage?,
    player: AVPlayer? = nil,
    isTopCard: Bool,
    dragOffset: CGSize,
    isMuted: Bool = true,
    onToggleMute: @escaping () -> Void = {}
  ) {
    self.asset = asset
    self.image = image
    self.player = player
    self.isTopCard = isTopCard
    self.dragOffset = dragOffset
    self.isMuted = isMuted
    self.onToggleMute = onToggleMute
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
              ZStack {
                if let image {
                  Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                VideoPlayerView(player: player)
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              }
              .clipShape(RoundedRectangle(cornerRadius: 20))
              .padding(8)
              .overlay(alignment: .bottomLeading) {
                Button(action: onToggleMute) {
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
  }
}
