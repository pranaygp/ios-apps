import SwiftUI

struct TicTacToeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var isXTurn = true
    @State private var winner: String?
    @State private var isDraw = false
    @State private var winningLine: [Int]?
    @State private var scoreX = 0
    @State private var scoreO = 0
    @State private var showResult = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial_TicTacToe") private var hasSeenTutorial = false

    private let winPatterns: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var body: some View {
        GameTransitionView {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player O score (top, rotated 180)
                    FrostedScoreBanner(player: 2, score: scoreO, color: .red, isTop: true)

                    Spacer()

                    // Board
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { col in
                                    let index = row * 3 + col
                                    CellView(
                                        value: board[index],
                                        isWinning: winningLine?.contains(index) == true
                                    ) {
                                        placeMark(at: index)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)

                    // Turn indicator
                    if !showResult {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isXTurn ? Color.blue : Color.red)
                                .frame(width: 10, height: 10)
                                .shadow(color: (isXTurn ? Color.blue : Color.red).opacity(0.5), radius: 4)
                            Text("\(PlayerProfileManager.shared.name(for: isXTurn ? 1 : 2))'s Turn")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isXTurn ? Color.blue : Color.red)
                        }
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }

                    Spacer()

                    // Player X score (bottom)
                    FrostedScoreBanner(player: 1, score: scoreX, color: .blue, isTop: false)
                }

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if !showTutorial && !isPaused && !showResult {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .ticTacToe) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if showResult {
                    if let winner {
                        WinnerOverlay(winner: winner == "X" ? 1 : 2, gameType: .ticTacToe, gameName: "Tic Tac Toe") {
                            resetBoard()
                        } onExit: {
                            dismiss()
                        }
                    } else if isDraw {
                        DrawOverlay(gameName: "Tic Tac Toe") {
                            resetBoard()
                        } onExit: {
                            dismiss()
                        }
                    }
                }

                if isPaused && !showResult {
                    PauseOverlay(
                        score1: scoreX,
                        score2: scoreO,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: { isPaused = false },
                        onRestart: {
                            isPaused = false
                            resetBoard()
                            scoreX = 0
                            scoreO = 0
                        },
                        onExit: { dismiss() }
                    )
                }
            }
        }
        .onAppear {
            if !hasSeenTutorial { showTutorial = true }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !showResult {
                isPaused = true
            }
        }
    }

    private func placeMark(at index: Int) {
        guard board[index].isEmpty, winner == nil, !isDraw, !isPaused else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            board[index] = isXTurn ? "X" : "O"
        }
        SoundManager.playPlace()
        HapticManager.impact(.light)

        if let line = checkWin() {
            winningLine = line
            winner = board[line[0]]
            if winner == "X" { scoreX += 1 } else { scoreO += 1 }
            SoundManager.playWin()
            HapticManager.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
        } else if board.allSatisfy({ !$0.isEmpty }) {
            isDraw = true
            SoundManager.playDraw()
            HapticManager.notification(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
        } else {
            isXTurn.toggle()
        }
    }

    private func checkWin() -> [Int]? {
        for pattern in winPatterns {
            let a = board[pattern[0]]
            if !a.isEmpty && a == board[pattern[1]] && a == board[pattern[2]] {
                return pattern
            }
        }
        return nil
    }

    private func resetBoard() {
        withAnimation {
            board = Array(repeating: "", count: 9)
            isXTurn = true
            winner = nil
            isDraw = false
            winningLine = nil
            showResult = false
        }
    }
}

struct CellView: View {
    let value: String
    let isWinning: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isWinning ? Color.yellow.opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isWinning ? Color.yellow.opacity(pulse ? 0.7 : 0.3) : Color.white.opacity(0.1),
                                lineWidth: isWinning ? 2 : 1
                            )
                            .animation(isWinning ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: pulse)
                    )

                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(value == "X" ? Color.blue : Color.red)
                    .shadow(color: (value == "X" ? Color.blue : Color.red).opacity(isWinning ? 0.5 : 0), radius: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .buttonStyle(.plain)
        .accessibilityLabel(value.isEmpty ? "Empty cell" : value)
        .accessibilityHint(value.isEmpty ? "Tap to place your mark" : "")
        .onChange(of: isWinning) { _, newVal in
            if newVal { pulse = true }
        }
    }
}

#Preview {
    TicTacToeView()
        .preferredColorScheme(.dark)
}
