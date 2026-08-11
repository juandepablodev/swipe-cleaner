import SwiftUI
import Photos

public struct SummaryItemThumbnailView: View {
  let asset: AssetModel
  let photoService: PhotoLibraryServiceProtocol

  @State private var image: UIImage? = nil

  public init(asset: AssetModel, photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
    self.asset = asset
    self.photoService = photoService
  }

  public var body: some View {
    ZStack(alignment: .topTrailing) {
      ZStack(alignment: .bottomLeading) {
        Rectangle()
          .fill(Color(uiColor: .tertiarySystemFill))
          .frame(width: 80, height: 80)
          .overlay {
            if let image {
              Image(uiImage: image)
                .resizable()
                .scaledToFill()
            } else {
              ProgressView()
                .scaleEffect(0.7)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 10))

        if asset.isVideo {
          HStack(spacing: 2) {
            Image(systemName: "play.fill")
              .font(.system(size: 8, weight: .bold))
            Text(asset.formattedDuration)
              .font(.system(size: 8, weight: .bold))
          }
          .foregroundStyle(.white)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(Color.black.opacity(0.7))
          .clipShape(Capsule())
          .padding(4)
        }
      }

      Image(systemName: "xmark.circle.fill")
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.white, .red)
        .padding(4)
        .shadow(color: .black.opacity(0.3), radius: 2)
    }
    .task(id: asset.id) {
      let loaded = await photoService.requestThumbnail(
        for: asset,
        targetSize: CGSize(width: 160, height: 160),
        onRequestID: { _ in }
      )
      if let loaded {
        self.image = loaded
      }
    }
  }
}
