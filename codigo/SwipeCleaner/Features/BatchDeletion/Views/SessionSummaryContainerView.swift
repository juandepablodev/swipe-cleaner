import SwiftUI

public struct SessionSummaryContainerView: View {
  @State private var viewModel: SessionSummaryViewModel
  @Environment(\.dismiss) private var dismiss

  public init(session: SessionResult, deletionService: PhotoKitDeletionServiceProtocol = PhotoKitDeletionService()) {
    _viewModel = State(initialValue: SessionSummaryViewModel(session: session, deletionService: deletionService))
  }

  public var body: some View {
    Group {
      if viewModel.deletionCompleted {
        DeletionSuccessView(
          deletedCount: viewModel.deletionOutcome?.deletedIDs.count ?? viewModel.session.pendingDeletion.count,
          spaceFreedText: viewModel.estimatedSizeText,
          onDone: {
            dismiss()
          }
        )
      } else {
        VStack(spacing: 20) {
          SummaryHeaderView(
            pendingCount: viewModel.session.pendingDeletion.count,
            keepCount: viewModel.session.keep.count,
            estimatedSizeText: viewModel.estimatedSizeText
          )
          .padding(.horizontal, 20)
          .padding(.top, 16)

          if let message = viewModel.userMessage {
            HStack {
              Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
              Text(message)
                .font(.footnote)
                .foregroundStyle(.primary)
            }
            .padding()
            .background(Color.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 20)
          }

          if !viewModel.session.pendingDeletion.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Items to Delete (\(viewModel.session.pendingDeletion.count))")
                .font(.subheadline.bold())
                .padding(.horizontal, 20)

              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(viewModel.session.pendingDeletion) { asset in
                    SummaryItemThumbnailView(asset: asset)
                  }
                }
                .padding(.horizontal, 20)
              }
            }
          }

          Spacer()

          // Action Buttons
          VStack(spacing: 12) {
            Button {
              Task {
                await viewModel.executeBatchDeletion()
              }
            } label: {
              HStack {
                if viewModel.isDeleting {
                  ProgressView()
                    .tint(.white)
                    .padding(.trailing, 8)
                }
                Text(viewModel.isDeleting ? "Deleting..." : "Confirm & Clean Gallery")
                  .font(.headline)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(viewModel.deletionInFlight || viewModel.session.pendingDeletion.isEmpty)

            Button("Keep Reviewing") {
              dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .disabled(viewModel.deletionInFlight)
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
        }
        .navigationTitle("Session Summary")
        .navigationBarTitleDisplayMode(.inline)
      }
    }
  }
}
