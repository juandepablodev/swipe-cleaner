import SwiftUI
import AVFoundation

struct CardStackView: View {
  var viewModel: SwipeEngineViewModel

  @State private var dragOffset: CGSize = .zero
  @State private var velocityEstimator = VelocityEstimator()
  @State private var activePlayer: AVPlayer?
  @State private var activePlayerAssetID: String?
  @State private var isMuted: Bool = true
  @State private var loopObserver: (any NSObjectProtocol)?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.displayScale) private var displayScale
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { geometry in
      let currentAsset = viewModel.currentAsset
      let currentItem = currentAsset != nil ? viewModel.playerItem(for: currentAsset!) : nil

      ZStack {
        // Next Card (Behind) - Displays thumbnail only, never attaches an AVPlayer
        if let nextAsset = viewModel.nextAsset {
          CardView(
            asset: nextAsset,
            image: viewModel.image(for: nextAsset),
            player: nil,
            isTopCard: false,
            dragOffset: .zero
          )
          .id(nextAsset.id)
          .scaleEffect(0.95)
          .opacity(0.8)
        }

        // Top Card (Interactive) - Plays video natively if asset is video
        if let currentAsset {
          CardView(
            asset: currentAsset,
            image: viewModel.image(for: currentAsset),
            player: activePlayer,
            isTopCard: true,
            dragOffset: dragOffset,
            isMuted: isMuted,
            onToggleMute: {
              toggleMute()
            }
          )
          .id(currentAsset.id)
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
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        updateTargetSize(for: geometry.size)
        syncActivePlayer(for: currentAsset, item: currentItem)
      }
      .onDisappear {
        cleanupActivePlayer()
      }
      .onChange(of: geometry.size) { _, newSize in
        updateTargetSize(for: newSize)
      }
      .onChange(of: scenePhase) { _, newPhase in
        switch newPhase {
        case .active:
          if let player = activePlayer, player.timeControlStatus != .playing {
            player.play()
          }
        case .inactive, .background:
          activePlayer?.pause()
        @unknown default:
          break
        }
      }
      .onChange(of: currentAsset?.id) { _, _ in
        let newCurrent = viewModel.currentAsset
        let newItem = newCurrent != nil ? viewModel.playerItem(for: newCurrent!) : nil
        syncActivePlayer(for: newCurrent, item: newItem)
      }
      .onChange(of: currentItem) { _, newItem in
        syncActivePlayer(for: viewModel.currentAsset, item: newItem)
      }
    }
  }

  private func syncActivePlayer(for asset: AssetModel?, item: AVPlayerItem?) {
    guard let asset, asset.isVideo else {
      cleanupActivePlayer()
      return
    }

    guard let item else {
      if activePlayerAssetID != asset.id {
        cleanupActivePlayer()
      }
      return
    }

    if activePlayerAssetID == asset.id, let player = activePlayer, player.currentItem === item {
      if player.timeControlStatus != .playing {
        player.play()
      }
      return
    }

    cleanupActivePlayer()

    let player = AVPlayer(playerItem: item)
    player.isMuted = isMuted
    player.actionAtItemEnd = .none

    loopObserver = NotificationCenter.default.addObserver(
      forName: .AVPlayerItemDidPlayToEndTime,
      object: item,
      queue: .main
    ) { [weak player] _ in
      player?.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
        if finished {
          player?.play()
        }
      }
    }

    self.activePlayer = player
    self.activePlayerAssetID = asset.id
    player.play()
  }

  private func cleanupActivePlayer() {
    if let observer = loopObserver {
      NotificationCenter.default.removeObserver(observer)
      loopObserver = nil
    }
    if let player = activePlayer {
      player.pause()
      player.replaceCurrentItem(with: nil)
      activePlayer = nil
    }
    activePlayerAssetID = nil
    if !isMuted {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  private func toggleMute() {
    isMuted.toggle()
    activePlayer?.isMuted = isMuted
    if !isMuted {
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
      try? AVAudioSession.sharedInstance().setActive(true)
    } else {
      try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
  }

  private func updateTargetSize(for size: CGSize) {
    guard size.width > 0, size.height > 0 else { return }
    let scale = displayScale > 0 ? displayScale : 3.0
    let targetSize = CGSize(
      width: max(size.width * scale, 1170),
      height: max(size.height * scale, 1950)
    )
    viewModel.updateDisplayTargetSize(targetSize)
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
