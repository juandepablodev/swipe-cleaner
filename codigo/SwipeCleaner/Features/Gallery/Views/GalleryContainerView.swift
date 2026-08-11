import SwiftUI

public struct GalleryContainerView: View {
  @State private var viewModel: GalleryViewModel
  @State private var showLimitedPicker: Bool = false

  public init(photoService: PhotoLibraryServiceProtocol = PhotoLibraryService()) {
    _viewModel = State(initialValue: GalleryViewModel(photoService: photoService))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.authorizationStatus {
        case .notDetermined:
          NotDeterminedPermissionView {
            Task {
              await viewModel.checkAndRequestPermission()
            }
          }

        case .authorized:
          GalleryGridView(viewModel: viewModel)
            .safeAreaInset(edge: .bottom) {
              if !viewModel.assets.isEmpty {
                VStack(spacing: 8) {
                  let persistence = SessionPersistenceService()
                  if let savedState = persistence.loadSavedSession(), !savedState.classifiedAssets.isEmpty {
                    NavigationLink(destination: SwipeEngineContainerView(assets: viewModel.assets, savedState: savedState)) {
                      HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Continuar Sesión (\(savedState.classifiedAssets.count) revisadas)")
                          .font(.headline)
                      }
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                  }

                  NavigationLink(destination: SwipeEngineContainerView(assets: viewModel.assets)) {
                    Text("Nueva Sesión")
                      .font(.headline)
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 12)
                  }
                  .buttonStyle(.bordered)
                  .tint(.blue)
                }
                .padding()
                .background(.ultraThinMaterial)
              }
            }

        case .limited:
          VStack(spacing: 0) {
            HStack {
              Label("Limited Access", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.bold())
                .foregroundStyle(.orange)
              Spacer()
              Button("Manage") {
                showLimitedPicker = true
              }
              .font(.footnote.bold())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))

            GalleryGridView(viewModel: viewModel)
              .safeAreaInset(edge: .bottom) {
                if !viewModel.assets.isEmpty {
                  VStack(spacing: 8) {
                    let persistence = SessionPersistenceService()
                    if let savedState = persistence.loadSavedSession(), !savedState.classifiedAssets.isEmpty {
                      NavigationLink(destination: SwipeEngineContainerView(assets: viewModel.assets, savedState: savedState)) {
                        HStack {
                          Image(systemName: "clock.arrow.circlepath")
                          Text("Continuar Sesión (\(savedState.classifiedAssets.count) revisadas)")
                            .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                      }
                      .buttonStyle(.borderedProminent)
                      .tint(.orange)
                    }

                    NavigationLink(destination: SwipeEngineContainerView(assets: viewModel.assets)) {
                      Text("Nueva Sesión")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                  }
                  .padding()
                  .background(.ultraThinMaterial)
                }
              }
          }
          .sheet(isPresented: $showLimitedPicker) {
            NavigationStack {
              VStack(spacing: 16) {
                Text("To manage which photos SwipeCleaner can access, go to Settings.")
                  .multilineTextAlignment(.center)
                  .padding()
                LimitedLibraryPickerButton()
              }
              .navigationTitle("Manage Access")
              .navigationBarTitleDisplayMode(.inline)
            }
          }

        case .denied, .restricted:
          PermissionDeniedView()

        @unknown default:
          PermissionDeniedView()
        }
      }
      .navigationTitle("Gallery")
      .task {
        await viewModel.checkAndRequestPermission()
      }
    }
  }
}
