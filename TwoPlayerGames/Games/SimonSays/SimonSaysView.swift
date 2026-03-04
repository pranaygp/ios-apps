import SwiftUI

struct SimonSaysView: View {
    @Environment(\.dismiss) private var dismiss

    enum Phase: Equatable {
        case creating
        case showingPattern
        case repeating
        case roundResult
        case gameOver
    }

    @State private var phase: Phase = .creating
    @State private var setter = 1
    @State private var pattern: [Int] = []
    @State private var playerInput: [Int] = []
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var sequenceLength = 3
    @State private var flashingButton: Int? = nil
    @State private var showingPatternIndex = 0
    @State private var roundResultText = ""
    @State private var roundResultColor: Color = .green
    @State private var gameWinner: Int?
    @State private var showGameOver = false

    private let settings = GameSettings.shared
    private var winScore: Int { settings.simonSaysWinScore }
    private var repeater: Int { setter == 1 ? 2 : 1 }

    private let buttonColors: [(Color, Color)] = [
        (Color(red: 1.0, green: 0.22, blue: 0.22), Color(red: 0.75, green: 0.08, blue: 0.08)),
        (Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.08, green: 0.28, blue: 0.78)),
        (Color(red: 0.15, green: 0.85, blue: 0.35), Color(red: 0.05, green: 0.6, blue: 0.18)),
        (Color(red: 1.0, green: 0.82, blue: 0.0), Color(red: 0.82, green: 0.6, blue: 0.0)),
    ]

    private let buttonIcons = ["circle.fill", "diamond.fill", "triangle.fill", "square.fill"]

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    FrostedScoreBanner(player: 2, score: score2, color: .red, isTop: true)

                    Spacer()

                    playerSection(for: 2)
                        .rotationEffect(.degrees(180))

                    Spacer()

                    centerStatus

                    Spacer()

                    playerSection(for: 1)

                    Spacer()

                    FrostedScoreBanner(player: 1, score: score1, color: .blue, isTop: false)
                }

                GameOverlay {
                    dismiss()
                }

                if showGameOver, let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameType: .simonSays) {
                        resetGame()
                    } onExit: {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Player Section

    private func playerSection(for player: Int) -> some View {
        let isActive = activePlayer == player
        let isShowTarget = (phase == .showingPattern && player == repeater)

        return VStack(spacing: 10) {
            Text(playerLabel(for: player))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.5)
                .animation(.easeInOut(duration: 0.2), value: phase)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    simonButton(index: 0, isActive: isActive, isShowTarget: isShowTarget)
                    simonButton(index: 1, isActive: isActive, isShowTarget: isShowTarget)
                }
                HStack(spacing: 10) {
                    simonButton(index: 2, isActive: isActive, isShowTarget: isShowTarget)
                    simonButton(index: 3, isActive: isActive, isShowTarget: isShowTarget)
                }
            }

            if isActive && phase == .creating {
                HStack(spacing: 4) {
                    ForEach(0..<sequenceLength, id: \.self) { i in
                        Circle()
                            .fill(i < pattern.count ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }

            if isActive && phase == .repeating {
                HStack(spacing: 4) {
                    ForEach(0..<pattern.count, id: \.self) { i in
                        Circle()
                            .fill(i < playerInput.count ? Color.green : Color.white.opacity(0.2))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 30)
        .opacity(isActive || isShowTarget ? 1.0 : 0.3)
        .animation(.easeInOut(duration: 0.3), value: phase)
    }

    private func playerLabel(for player: Int) -> String {
        if phase == .creating && setter == player {
            return "Create Pattern"
        } else if phase == .showingPattern && repeater == player {
            return "Watch Carefully"
        } else if phase == .repeating && repeater == player {
            return "Your Turn — Repeat!"
        } else if phase == .roundResult {
            return roundResultText.isEmpty ? "" : " "
        }
        return "Waiting..."
    }

    private func simonButton(index: Int, isActive: Bool, isShowTarget: Bool) -> some View {
        let isLit = flashingButton == index
        let (baseColor, darkColor) = buttonColors[index]

        return Button {
            if isActive {
                handleTap(index: index)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                isLit ? baseColor : baseColor.opacity(0.35),
                                isLit ? darkColor : darkColor.opacity(0.25),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: isLit ? baseColor.opacity(0.7) : .clear,
                        radius: isLit ? 16 : 0
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isLit ? baseColor.opacity(0.8) : Color.white.opacity(0.06),
                                lineWidth: isLit ? 2 : 1
                            )
                    )

                Image(systemName: buttonIcons[index])
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white.opacity(isLit ? 0.95 : 0.25))
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1.4, contentMode: .fit)
        .buttonStyle(.plain)
        .disabled(!isActive)
        .accessibilityLabel("Simon button \(index + 1)")
        .scaleEffect(isLit ? 1.08 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isLit)
    }

    private var activePlayer: Int? {
        switch phase {
        case .creating: return setter
        case .repeating: return repeater
        default: return nil
        }
    }

    // MARK: - Center Status

    private var centerStatus: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(height: 56)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            Group {
                switch phase {
                case .creating:
                    HStack(spacing: 6) {
                        Circle()
                            .fill(setter == 1 ? Color.blue : Color.red)
                            .frame(width: 10, height: 10)
                        Text("P\(setter): Create a pattern")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                case .showingPattern:
                    HStack(spacing: 6) {
                        Image(systemName: "eye.fill")
                            .foregroundStyle(.yellow)
                        Text("Watch the pattern...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.yellow)
                    }
                case .repeating:
                    HStack(spacing: 6) {
                        Circle()
                            .fill(repeater == 1 ? Color.blue : Color.red)
                            .frame(width: 10, height: 10)
                        Text("P\(repeater): Repeat! (\(playerInput.count)/\(pattern.count))")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                case .roundResult:
                    Text(roundResultText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(roundResultColor)
                case .gameOver:
                    EmptyView()
                }
            }
            .animation(.easeInOut(duration: 0.2), value: phase)
        }
    }

    // MARK: - Game Logic

    private func handleTap(index: Int) {
        switch phase {
        case .creating:
            pattern.append(index)
            flashButton(index)
            SoundManager.playSimonTone(index: index)
            HapticManager.impact(.light)

            if pattern.count >= sequenceLength {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showPattern()
                }
            }

        case .repeating:
            playerInput.append(index)
            flashButton(index)
            SoundManager.playSimonTone(index: index)
            HapticManager.impact(.light)

            let currentIndex = playerInput.count - 1
            if pattern[currentIndex] != index {
                roundFailed()
            } else if playerInput.count == pattern.count {
                roundSucceeded()
            }

        default:
            break
        }
    }

    private func flashButton(_ index: Int) {
        flashingButton = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if flashingButton == index {
                flashingButton = nil
            }
        }
    }

    private func showPattern() {
        withAnimation { phase = .showingPattern }
        showingPatternIndex = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            playNextInPattern()
        }
    }

    private func playNextInPattern() {
        guard showingPatternIndex < pattern.count else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation { phase = .repeating }
                playerInput = []
            }
            return
        }

        let idx = pattern[showingPatternIndex]
        flashingButton = idx
        SoundManager.playSimonTone(index: idx)
        HapticManager.impact(.light)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            flashingButton = nil
            showingPatternIndex += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                playNextInPattern()
            }
        }
    }

    private func roundSucceeded() {
        let scorer = repeater
        withAnimation {
            if scorer == 1 { score1 += 1 } else { score2 += 1 }
            roundResultText = "P\(scorer) got it! \u{1F389}"
            roundResultColor = .green
            phase = .roundResult
        }
        SoundManager.playScore()
        HapticManager.notification(.success)

        checkGameOver {
            sequenceLength += 1
            swapAndReset()
        }
    }

    private func roundFailed() {
        let scorer = setter
        withAnimation {
            if scorer == 1 { score1 += 1 } else { score2 += 1 }
            roundResultText = "Wrong! P\(scorer) scores"
            roundResultColor = .red
            phase = .roundResult
        }
        SoundManager.playLose()
        HapticManager.notification(.error)

        checkGameOver {
            sequenceLength = 3
            swapAndReset()
        }
    }

    private func checkGameOver(onContinue: @escaping () -> Void) {
        if score1 >= winScore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                gameWinner = 1
                phase = .gameOver
                showGameOver = true
                SoundManager.playWin()
            }
        } else if score2 >= winScore {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                gameWinner = 2
                phase = .gameOver
                showGameOver = true
                SoundManager.playWin()
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                onContinue()
            }
        }
    }

    private func swapAndReset() {
        withAnimation {
            setter = setter == 1 ? 2 : 1
            pattern = []
            playerInput = []
            phase = .creating
            flashingButton = nil
        }
    }

    private func resetGame() {
        withAnimation {
            score1 = 0
            score2 = 0
            sequenceLength = 3
            setter = 1
            pattern = []
            playerInput = []
            gameWinner = nil
            showGameOver = false
            phase = .creating
            flashingButton = nil
        }
    }
}

#Preview {
    SimonSaysView()
        .preferredColorScheme(.dark)
}
