import SwiftUI
import UIKit

struct NotDeterminedPermissionView: View {
  let onRequestPermission: () -> Void

  var body: some View {
    ContentUnavailableView {
      Label("Photo Library Access Needed", systemImage: "photo.stack")
    } description: {
      Text("SwipeCleaner requires access to your photo library to help you clean up space quickly and privately.")
    } actions: {
      Button(action: onRequestPermission) {
        Text("Grant Photo Library Access")
          .font(.headline)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

struct PermissionDeniedView: View {
  @Environment(\.openURL) private var openURL

  var body: some View {
    ContentUnavailableView {
      Label("Access Denied", systemImage: "lock.shield")
    } description: {
      Text("Photo library access has been denied or restricted. Please enable it in Settings to use SwipeCleaner.")
    } actions: {
      Button("Open Settings") {
        if let url = URL(string: UIApplication.openSettingsURLString) {
          openURL(url)
        }
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

struct LimitedLibraryPickerButton: View {
  var body: some View {
    Button("Manage Photo Access") {
      if let url = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(url)
      }
    }
    .buttonStyle(.borderedProminent)
  }
}
