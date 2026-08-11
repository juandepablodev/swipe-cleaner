import SwiftUI

struct CardStackView: View {
  var viewModel: SwipeEngineViewModel

  @State private var dragOffset: CGSize = .zero
  @State private var velocityEstimator = VelocityEstimator()
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        // Next Card (Behind)
        if let nextAsset = viewModel.nextAsset {
          CardView(
            asset: nextAsset,
            image: viewModel.image(for: nextAsset),
            playerItem: viewModel.playerItem(for: nextAsset),
            isTopCard: false,
            dragOffset: .zero
          )
          .scaleEffect(0.95)
          .opacity(0.8)
        }

        // Top Card (Interactive)
        if let currentAsset = viewModel.currentAsset {
          CardView(
            asset: currentAsset,
            image: viewModel.image(for: currentAsset),
            playerItem: viewModel.playerItem(for: currentAsset),
            isTopCard: true,
            dragOffset: dragOffset
          )
          .gesture(
            DragGesture()
              .onChanged { gesture in
                guard !viewModel.swipeInFlight else { return }
                dragOffset = gesture.translation
                velocityEstimator.add(x: gesture.translation.width, at: gesture.time.timeIntervalSinceReferenceDate)
              }
              .onEnded { gesture in
                guard !viewModel.swipeInFlight else { return }
                let velocityX = velocityEstimator.horizontalVelocity
                velocityEstimator.reset()
                handleDragEnd(translation: gesture.translation, velocityX: velocityX, screenWidth: geometry.size.width)
              }
          )
          .onAppear {
            let targetSize = CGSize(width: 900, height: 1200)
            viewModel.updateDisplayTargetSize(targetSize)
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
  }

  private func handleDragEnd(translation: CGSize, velocityX: CGFloat, screenWidth: CGFloat) {
    if translation.width > 120 || velocityX > 500 {
      triggerHapticFeedback(style: .medium)
      completeSwipe(decision: .keep, directionRight: true, screenWidth: screenWidth)
    } else if translation.width < -120 || velocityX < -500 {
      triggerHapticFeedback(style: .medium)
      completeSwipe(decision: .delete, directionRight: false, screenWidth: screenWidth)
    } else {
      withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
        dragOffset = .zero
      }
    }
  }

  private func completeSwipe(decision: SwipeDecision, directionRight: Bool, screenWidth: CGFloat) {
    let targetX = directionRight ? screenWidth * 1.5 : -screenWidth * 1.5
    
    if reduceMotion {
      withAnimation(.easeInOut(duration: 0.2)) {
        dragOffset = CGSize(width: targetX, height: 0)
      } completion: {
        viewModel.processDecision(decision)
        dragOffset = .zero
        viewModel.swipeAnimationCompleted()
      }
    } else {
      withAnimation(.spring(duration: 0.35, bounce: 0.1)) {
        dragOffset = CGSize(width: targetX, height: dragOffset.height)
      } completion: {
        viewModel.processDecision(decision)
        dragOffset = .zero
        viewModel.swipeAnimationCompleted()
      }
    }
  }
}
