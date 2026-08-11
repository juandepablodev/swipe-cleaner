import SwiftUI

struct GalleryGridView: View {
  var viewModel: GalleryViewModel

  private let columns = [
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2),
    GridItem(.flexible(), spacing: 2)
  ]

  var body: some View {
    GeometryReader { geometry in
      let itemWidth = (geometry.size.width - 4) / 3
      let targetSize = CGSize(width: itemWidth * 2, height: itemWidth * 2)

      ScrollView {
        if viewModel.assets.isEmpty && !viewModel.isLoading {
          ContentUnavailableView(
            "No Photos Available",
            systemImage: "photo.on.rectangle.angled",
            description: Text("Your library has no photos or videos.")
          )
          .padding(.top, 60)
        } else {
          LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(viewModel.assets.enumerated()), id: \.element.id) { index, asset in
              ThumbnailCellView(
                asset: asset,
                viewModel: viewModel,
                targetSize: targetSize
              )
              .onAppear {
                viewModel.updatePrefetchWindow(visibleIndices: IndexSet(integer: index), targetSize: targetSize)
              }
            }
          }
        }
      }
    }
  }
}
