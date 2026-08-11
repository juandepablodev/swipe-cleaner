import SwiftUI

struct ActionBarView: View {
  var viewModel: SwipeEngineViewModel
  let onKeep: () -> Void
  let onDelete: () -> Void
  let onUndo: () -> Void

  var body: some View {
    HStack(spacing: 32) {
      // Undo Button
      Button(action: onUndo) {
        Image(systemName: "arrow.uturn.backward")
          .font(.title2.bold())
          .foregroundStyle(.orange)
          .frame(width: 54, height: 54)
          .background(Color.orange.opacity(0.15))
          .clipShape(Circle())
      }
      .disabled(viewModel.historyStack.isEmpty || viewModel.swipeInFlight)
      .opacity(viewModel.historyStack.isEmpty || viewModel.swipeInFlight ? 0.4 : 1.0)

      // Delete Button (Trash)
      Button(action: onDelete) {
        Image(systemName: "trash.fill")
          .font(.title.bold())
          .foregroundStyle(.red)
          .frame(width: 68, height: 68)
          .background(Color.red.opacity(0.15))
          .clipShape(Circle())
      }
      .disabled(viewModel.remainingAssets.isEmpty || viewModel.swipeInFlight)
      .opacity(viewModel.remainingAssets.isEmpty || viewModel.swipeInFlight ? 0.4 : 1.0)

      // Keep Button (Checkmark)
      Button(action: onKeep) {
        Image(systemName: "checkmark")
          .font(.title.bold())
          .foregroundStyle(.green)
          .frame(width: 68, height: 68)
          .background(Color.green.opacity(0.15))
          .clipShape(Circle())
      }
      .disabled(viewModel.remainingAssets.isEmpty || viewModel.swipeInFlight)
      .opacity(viewModel.remainingAssets.isEmpty || viewModel.swipeInFlight ? 0.4 : 1.0)
    }
    .padding(.vertical, 16)
  }
}
