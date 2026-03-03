import SwiftUI

struct ReactionTimeView: View {
    @Environment(\.dismiss) private var dismiss

    enum GamePhase {
        case waiting
        case countdown
        case go
        case tooEarly
        case scored
        case gameOver
    }

    @State private var phase: GamePhase = .waiting
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var roundWinner: Int?
    @State private var gameWinner: Int?
    @State private var countdownTimer: Timer?
    @State private var goTime: Date?
    @State private var reactionTime: TimeInterval?
    @State private var tooEarlyPlayer: Int?
    @State private var flashOpacity: Double = 0
    @State private var countdownNumber: Int = 3
    @State private var showCountdownNumber = false
    @State private var phaseColorAnimation = false

    private let settings = GameSettings.shared
    private var winScore: Int { settings.reactionTimeWinScore }

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 zone (top, rotated)
                    playerZone(player: 2)
                        .rotationEffect(.degrees(180))

                    // Divider + status
                    centerStatus

                    // Player 1 zone (bottom)
                    playerZone(player: 1)
                }

                // GO flash effect
                Color.green.opacity(flashOpacity)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                GameOverlay {
                    cleanup()
                    dismiss()
                }

                if gameWinner != nil {
                    gameOverOverlay
                }
            }
            .onAppear {
                startRound()
            }
            .onDisappear {
                cleanup()
            }
        }
    }

    // MARK: - Player Zone

    private func playerZone(player: Int) -> some View {
        let score = player == 1 ? score1 : score2
        let canTap = phase == .countdown || phase == .go

        return Button {
            handleTap(player: player)
        } label: {
            ZStack {
                // Background color based on phase
                zoneColor(for: player)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.3), value: phaseColorAnimation)

                VStack(spacing: 12) {
                    Text("Player \(player)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    if phase == .scored && roundWinner == player {
                        if let rt = reactionTime {
                            VStack(spacing: 4) {
                                Text("\(Int(rt * 1000))ms")
                                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.green)

                                Text(reactionRating(rt))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.green.opacity(0.7))
                            }
                            .transition(.scale.combined(with: .opacity))
                        }
                    }

                    if phase == .tooEarly && tooEarlyPlayer == player {
                        Text("Too early!")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.red)
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Countdown number overlay
                    if showCountdownNumber && phase == .waiting {
                        Text("\(countdownNumber)")
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.15))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: phase)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    private func reactionRating(_ time: TimeInterval) -> String {
        let ms = time * 1000
        if ms < 150 { return "Inhuman!" }
        if ms < 200 { return "Lightning fast!" }
        if ms < 250 { return "Great reflexes!" }
        if ms < 350 { return "Pretty quick!" }
        if ms < 500 { return "Not bad!" }
        return "Keep practicing!"
    }

    private func zoneColor(for player: Int) -> some View {
        Group {
            switch phase {
            case .waiting:
                Color(white: 0.08)
            case .countdown:
                LinearGradient(
                    colors: [Color(red: 0.4, green: 0.08, blue: 0.08), Color(red: 0.3, green: 0.04, blue: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .go:
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.45, blue: 0.15), Color(red: 0.02, green: 0.3, blue: 0.08)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            case .tooEarly:
                if tooEarlyPlayer == player {
                    Color(red: 0.5, green: 0.1, blue: 0.1)
                } else {
                    Color(white: 0.08)
                }
            case .scored:
                if roundWinner == player {
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.3, blue: 0.1), Color(red: 0.02, green: 0.2, blue: 0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color(white: 0.08)
                }
            case .gameOver:
                Color(white: 0.08)
            }
        }
    }

    // MARK: - Center Status

    private var centerStatus: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(height: 64)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            HStack {
                // Player 1 score pill
                Text("\(score1)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.blue.opacity(0.3)))

                Spacer()

                // Phase text
                Group {
                    switch phase {
                    case .waiting:
                        Text("Get Ready...")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    case .countdown:
                        Text("WAIT...")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.red)
                    case .go:
                        Text("TAP NOW!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.green)
                    case .tooEarly:
                        Text("Too Early!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.orange)
                    case .scored:
                        if let winner = roundWinner {
                            Text("P\(winner) scores!")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.green)
                        }
                    case .gameOver:
                        EmptyView()
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: phase)

                Spacer()

                // Player 2 score pill
                Text("\(score2)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.red.opacity(0.3)))
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Game Logic

    private func startRound() {
        phase = .waiting
        roundWinner = nil
        reactionTime = nil
        tooEarlyPlayer = nil
        phaseColorAnimation.toggle()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard phase == .waiting else { return }
            withAnimation {
                phase = .countdown
                phaseColorAnimation.toggle()
            }
            SoundManager.playCountdown()
            HapticManager.impact(.light)

            // Random delay before "GO"
            let delay = Double.random(in: 1.5...4.0)
            countdownTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                DispatchQueue.main.async {
                    guard phase == .countdown else { return }
                    withAnimation(.easeInOut(duration: 0.1)) {
                        phase = .go
                        phaseColorAnimation.toggle()
                    }
                    goTime = Date()
                    SoundManager.playGo()
                    HapticManager.notification(.success)

                    // Flash effect
                    withAnimation(.easeOut(duration: 0.1)) {
                        flashOpacity = 0.3
                    }
                    withAnimation(.easeOut(duration: 0.3).delay(0.1)) {
                        flashOpacity = 0
                    }
                }
            }
        }
    }

    private func handleTap(player: Int) {
        switch phase {
        case .countdown:
            countdownTimer?.invalidate()
            countdownTimer = nil
            tooEarlyPlayer = player
            withAnimation {
                phase = .tooEarly
                phaseColorAnimation.toggle()
            }
            HapticManager.notification(.error)

            let otherPlayer = player == 1 ? 2 : 1
            withAnimation { if otherPlayer == 1 { score1 += 1 } else { score2 += 1 } }
            roundWinner = otherPlayer

            checkGameOver(afterDelay: 1.5)

        case .go:
            guard let start = goTime else { return }
            reactionTime = Date().timeIntervalSince(start)
            roundWinner = player
            withAnimation { if player == 1 { score1 += 1 } else { score2 += 1 } }
            withAnimation {
                phase = .scored
                phaseColorAnimation.toggle()
            }
            SoundManager.playScore()
            HapticManager.notification(.success)

            checkGameOver(afterDelay: 2.0)

        default:
            break
        }
    }

    private func checkGameOver(afterDelay delay: Double) {
        if score1 >= winScore {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                gameWinner = 1
                phase = .gameOver
                SoundManager.playWin()
            }
        } else if score2 >= winScore {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                gameWinner = 2
                phase = .gameOver
                SoundManager.playWin()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                startRound()
            }
        }
    }

    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func resetGame() {
        cleanup()
        score1 = 0
        score2 = 0
        gameWinner = nil
        startRound()
    }

    // MARK: - Game Over

    private var gameOverOverlay: some View {
        WinnerOverlay(winner: gameWinner ?? 1) {
            resetGame()
        } onExit: {
            cleanup()
            dismiss()
        }
    }
}

#Preview {
    ReactionTimeView()
        .preferredColorScheme(.dark)
}
