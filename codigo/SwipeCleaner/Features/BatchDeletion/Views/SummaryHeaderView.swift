import SwiftUI

struct SummaryHeaderView: View {
  let pendingCount: Int
  let keepCount: Int
  let estimatedSizeText: String

  var body: some View {
    VStack(spacing: 16) {
      Text("Session Summary")
        .font(.title2.bold())

      HStack(spacing: 24) {
        VStack(spacing: 4) {
          Text("\(keepCount)")
            .font(.title.bold())
            .foregroundStyle(.green)
          Text("Kept")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)

        Divider()
          .frame(height: 40)

        VStack(spacing: 4) {
          Text("\(pendingCount)")
            .font(.title.bold())
            .foregroundStyle(.red)
          Text("To Delete")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)

        Divider()
          .frame(height: 40)

        VStack(spacing: 4) {
          Text(estimatedSizeText)
            .font(.title3.bold())
            .foregroundStyle(.primary)
          Text("Est. Freed Space")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
      }
      .padding()
      .background(Color(uiColor: .secondarySystemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
  }
}
