import SwiftUI

struct TicTacToeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board: [String] = Array(repeating: "", count: 9)
    @State private var isXTurn = true
    @State private var winner: String?
    @State private var isDraw = false
    @State private var winningLine: [Int]?
    @State private var scoreX = 0
    @State private var scoreO = 0
    @State private var showResult = false

    private let winPatterns: [[Int]] = [
        [0, 1, 2], [3, 4, 5], [6, 7, 8],
        [0, 3, 6], [1, 4, 7], [2, 5, 8],
        [0, 4, 8], [2, 4, 6],
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Player O score (top, rotated 180)
                ScoreBanner(player: "O", score: scoreO, color: .red, isTop: true)

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
                    Text("\(isXTurn ? "X" : "O")'s Turn")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isXTurn ? Color.blue : Color.red)
                        .padding(.bottom, 8)
                }

                Spacer()

                // Player X score (bottom)
                ScoreBanner(player: "X", score: scoreX, color: .blue, isTop: false)
            }

            // Back button
            GameOverlay {
                dismiss()
            }

            if showResult {
                resultOverlay
            }
        }
    }

    private var resultOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {}

            VStack(spacing: 20) {
                if let winner {
                    Text("🏆")
                        .font(.system(size: 48))
                    Text("Player \(winner) Wins!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("🤝")
                        .font(.system(size: 48))
                    Text("It's a Draw!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 16) {
                    Button {
                        HapticManager.impact(.light)
                        resetBoard()
                    } label: {
                        Text("Play Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.blue))
                    }

                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Text("Exit")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.15)))
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.12))
            )
        }
    }

    private func placeMark(at index: Int) {
        guard board[index].isEmpty, winner == nil, !isDraw else { return }

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

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isWinning ? Color.yellow.opacity(0.2) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isWinning ? Color.yellow.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                    )

                Text(value)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(value == "X" ? Color.blue : Color.red)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .buttonStyle(.plain)
    }
}

struct ScoreBanner: View {
    let player: String
    let score: Int
    let color: Color
    let isTop: Bool

    var body: some View {
        HStack {
            Text("Player \(player)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Spacer()
            Text("\(score)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .rotationEffect(isTop ? .degrees(180) : .zero)
    }
}

#Preview {
    TicTacToeView()
        .preferredColorScheme(.dark)
}
