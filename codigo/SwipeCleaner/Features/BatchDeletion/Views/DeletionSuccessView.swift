import SwiftUI

struct DeletionSuccessView: View {
  let deletedCount: Int
  let spaceFreedText: String
  let onDone: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Spacer()

      Image(systemName: "checkmark.seal.fill")
        .font(.system(size: 80))
        .foregroundStyle(.green)

      Text("Gallery Cleaned!")
        .font(.largeTitle.bold())

      VStack(spacing: 8) {
        Text("\(deletedCount) items moved to Recently Deleted")
          .font(.headline)

        Text("Estimated space freed: \(spaceFreedText)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      VStack(spacing: 6) {
        Label("100% Safe & Recoverable", systemImage: "shield.border.checkmark.fill")
          .font(.footnote.bold())
          .foregroundStyle(.blue)

        Text("Recoverable for 30 days in the native 'Recently Deleted' album.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding()
      .background(Color.blue.opacity(0.1))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 20)

      Spacer()

      Button(action: onDone) {
        Text("Done")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
  }
}
