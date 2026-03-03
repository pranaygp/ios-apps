import SwiftUI

struct ReactionTimeView: View {
    @Environment(\.dismiss) private var dismiss

    enum GamePhase {
        case waiting     // Shows "Get Ready..."
        case countdown   // Red screen, waiting for green
        case go          // Green! Tap now!
        case tooEarly    // Someone tapped during countdown
        case scored      // Someone scored a point
        case gameOver    // Game finished
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

    private let settings = GameSettings.shared
    private var winScore: Int { settings.reactionTimeWinScore }

    var body: some View {
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

                VStack(spacing: 12) {
                    Text("Player \(player)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(score)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    if phase == .scored && roundWinner == player {
                        if let rt = reactionTime {
                            Text("\(Int(rt * 1000))ms")
                                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.green)
                        }
                    }

                    if phase == .tooEarly && tooEarlyPlayer == player {
                        Text("Too early!")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!canTap)
    }

    private func zoneColor(for player: Int) -> some View {
        Group {
            switch phase {
            case .waiting:
                Color(white: 0.08)
            case .countdown:
                Color(red: 0.4, green: 0.08, blue: 0.08)
            case .go:
                Color(red: 0.05, green: 0.4, blue: 0.12)
            case .tooEarly:
                if tooEarlyPlayer == player {
                    Color(red: 0.5, green: 0.1, blue: 0.1)
                } else {
                    Color(white: 0.08)
                }
            case .scored:
                if roundWinner == player {
                    Color(red: 0.05, green: 0.25, blue: 0.08)
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
                .fill(Color.white.opacity(0.08))
                .frame(height: 60)

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
                    Text("Player \(winner) scores!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.green)
                }
            case .gameOver:
                EmptyView()
            }
        }
    }

    // MARK: - Game Logic

    private func startRound() {
        phase = .waiting
        roundWinner = nil
        reactionTime = nil
        tooEarlyPlayer = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard phase == .waiting else { return }
            phase = .countdown
            SoundManager.playCountdown()
            HapticManager.impact(.light)

            // Random delay before "GO"
            let delay = Double.random(in: 1.5...4.0)
            countdownTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
                DispatchQueue.main.async {
                    guard phase == .countdown else { return }
                    phase = .go
                    goTime = Date()
                    SoundManager.playGo()
                    HapticManager.notification(.success)
                }
            }
        }
    }

    private func handleTap(player: Int) {
        switch phase {
        case .countdown:
            // Tapped too early
            countdownTimer?.invalidate()
            countdownTimer = nil
            tooEarlyPlayer = player
            phase = .tooEarly
            HapticManager.notification(.error)

            // Other player gets the point
            let otherPlayer = player == 1 ? 2 : 1
            if otherPlayer == 1 { score1 += 1 } else { score2 += 1 }
            roundWinner = otherPlayer

            checkGameOver(afterDelay: 1.5)

        case .go:
            // Valid tap!
            guard let start = goTime else { return }
            reactionTime = Date().timeIntervalSince(start)
            roundWinner = player
            if player == 1 { score1 += 1 } else { score2 += 1 }
            phase = .scored
            SoundManager.playScore()
            HapticManager.notification(.success)

            checkGameOver(afterDelay: 1.5)

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
            HapticManager.impact(.medium)
            resetGame()
        } onExit: {
            HapticManager.impact(.light)
            cleanup()
            dismiss()
        }
    }
}

#Preview {
    ReactionTimeView()
        .preferredColorScheme(.dark)
}
