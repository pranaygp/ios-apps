import SwiftUI

struct TugOfWarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var ropePosition: CGFloat = 0.5 // 0 = P2 wins, 1 = P1 wins, 0.5 = center
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var gameWinner: Int?
    @State private var roundActive = false
    @State private var countdown: Int = 3
    @State private var showCountdown = true
    @State private var isPaused = false
    @State private var p1TapCount = 0
    @State private var p2TapCount = 0
    @State private var ropeShake: CGFloat = 0
    @State private var p1Flash = false
    @State private var p2Flash = false
    @State private var roundWinner: Int?
    @State private var showRoundResult = false

    private let settings = GameSettings.shared
    private var winScore: Int { settings.tugOfWarWinScore }
    private let pullPerTap: CGFloat = 0.012
    private let friction: CGFloat = 0.0003
    private var displayTimer: Timer? = nil

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 tap zone (top, rotated)
                    tapZone(player: 2)
                        .rotationEffect(.degrees(180))

                    // Rope area
                    ropeView

                    // Player 1 tap zone (bottom)
                    tapZone(player: 1)
                }

                // Countdown overlay
                if showCountdown {
                    countdownOverlay
                }

                // Round result flash
                if showRoundResult, let winner = roundWinner {
                    roundResultOverlay(winner: winner)
                }

                GameOverlay(onBack: { dismiss() }, onPause: {
                    isPaused = true
                    roundActive = false
                })

                if let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameType: .tugOfWar, gameName: "Tug of War") {
                        resetGame()
                    } onExit: {
                        dismiss()
                    }
                }

                if isPaused && gameWinner == nil {
                    PauseOverlay(
                        score1: score1,
                        score2: score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: {
                            isPaused = false
                            startCountdown()
                        },
                        onRestart: {
                            isPaused = false
                            resetGame()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
            .onAppear {
                startCountdown()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && gameWinner == nil {
                isPaused = true
                roundActive = false
            }
        }
    }

    // MARK: - Tap Zone

    private func tapZone(player: Int) -> some View {
        let score = player == 1 ? score1 : score2
        let tapCount = player == 1 ? p1TapCount : p2TapCount
        let isFlashing = player == 1 ? p1Flash : p2Flash
        let color: Color = player == 1 ? .blue : .red

        return Button {
            handleTap(player: player)
        } label: {
            ZStack {
                // Background with flash effect
                color.opacity(isFlashing ? 0.25 : 0.08)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.08), value: isFlashing)

                VStack(spacing: 12) {
                    Text("Player \(player)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    if roundActive {
                        Text("TAP!")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(color)
                            .opacity(0.8)

                        // Tap counter
                        Text("\(tapCount) taps")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!roundActive || isPaused)
        .accessibilityLabel("Player \(player) zone, score \(score)")
    }

    // MARK: - Rope View

    private var ropeView: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let markerX = width * ropePosition

            ZStack {
                // Background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 12)
                    .padding(.horizontal, 20)

                // Blue side fill (P1)
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.1)],
                                startPoint: .trailing,
                                endPoint: .leading
                            )
                        )
                        .frame(width: max(0, width - markerX))
                }
                .frame(height: 12)
                .padding(.horizontal, 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Red side fill (P2)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.4), Color.red.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, markerX))
                    Spacer()
                }
                .frame(height: 12)
                .padding(.horizontal, 20)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Center mark
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 2, height: 24)

                // Win zones
                HStack {
                    // P2 win zone
                    Rectangle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 30)
                    Spacer()
                    // P1 win zone
                    Rectangle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 30)
                }
                .padding(.horizontal, 20)
                .frame(height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Rope knot / marker
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .white.opacity(0.3), radius: 6)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                    )
                    .position(x: markerX, y: geo.size.height / 2)
                    .offset(x: ropeShake)
                    .animation(.interpolatingSpring(stiffness: 300, damping: 8), value: ropePosition)
                    .animation(.easeOut(duration: 0.05), value: ropeShake)

                // Score display
                HStack {
                    Text("P2")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.red.opacity(0.6))
                        .rotationEffect(.degrees(180))
                    Spacer()
                    Text("P1")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.blue.opacity(0.6))
                }
                .padding(.horizontal, 24)
            }
        }
        .frame(height: 72)
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Text(countdown > 0 ? "\(countdown)" : "GO!")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(countdown > 0 ? .white : .green)
                .scaleEffect(countdown > 0 ? 1.0 : 1.3)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countdown)
        }
        .allowsHitTesting(true)
    }

    private func startCountdown() {
        showCountdown = true
        countdown = 3
        ropePosition = 0.5
        p1TapCount = 0
        p2TapCount = 0
        roundActive = false
        roundWinner = nil
        showRoundResult = false

        func tick() {
            guard !isPaused else { return }
            if countdown > 1 {
                SoundManager.playCountdown()
                HapticManager.impact(.medium)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    countdown -= 1
                    tick()
                }
            } else if countdown == 1 {
                SoundManager.playCountdown()
                HapticManager.impact(.medium)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    countdown = 0
                    SoundManager.playGo()
                    HapticManager.notification(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showCountdown = false
                        roundActive = true
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tick()
        }
    }

    // MARK: - Game Logic

    private func handleTap(player: Int) {
        guard roundActive, !isPaused else { return }

        HapticManager.impact(.light)
        SoundManager.playHit()

        if player == 1 {
            p1TapCount += 1
            ropePosition = min(1.0, ropePosition + pullPerTap)
            p1Flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { p1Flash = false }
        } else {
            p2TapCount += 1
            ropePosition = max(0.0, ropePosition - pullPerTap)
            p2Flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { p2Flash = false }
        }

        // Rope shake
        ropeShake = CGFloat.random(in: -2...2)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { ropeShake = 0 }

        // Check win conditions
        if ropePosition >= 0.92 {
            roundWon(player: 1)
        } else if ropePosition <= 0.08 {
            roundWon(player: 2)
        }
    }

    private func roundWon(player: Int) {
        roundActive = false
        roundWinner = player
        if player == 1 { score1 += 1 } else { score2 += 1 }
        SoundManager.playScore()
        HapticManager.notification(.success)

        showRoundResult = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showRoundResult = false

            if score1 >= winScore {
                gameWinner = 1
                SoundManager.playWin()
            } else if score2 >= winScore {
                gameWinner = 2
                SoundManager.playWin()
            } else {
                startCountdown()
            }
        }
    }

    private func roundResultOverlay(winner: Int) -> some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text("Player \(winner)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(winner == 1 ? Color.blue : Color.red)
                    .textCase(.uppercase)
                    .tracking(2)
                Text("Wins the Round!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func resetGame() {
        score1 = 0
        score2 = 0
        gameWinner = nil
        startCountdown()
    }
}

#Preview {
    TugOfWarView()
        .preferredColorScheme(.dark)
}
