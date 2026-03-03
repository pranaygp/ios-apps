import SwiftUI

struct ConnectFourView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var board: [[Int]] = Array(repeating: Array(repeating: 0, count: 7), count: 6)
    @State private var currentPlayer = 1  // 1 = red, 2 = yellow
    @State private var winner: Int?
    @State private var isDraw = false
    @State private var winningCells: Set<String> = []
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var showResult = false
    @State private var lastDropColumn: Int?
    @State private var lastDropRow: Int?
    @State private var dropAnimating = false

    private let columns = 7
    private let rows = 6
    private let settings = GameSettings.shared

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                // Player 2 score (top, rotated)
                ConnectFourScoreBanner(player: 2, score: score2, isTop: true)

                Spacer()

                // Turn indicator
                if !showResult {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(currentPlayer == 1 ? Color.red : Color.yellow)
                            .frame(width: 12, height: 12)
                        Text("Player \(currentPlayer)'s Turn")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.bottom, 12)
                }

                // Board
                boardView
                    .padding(.horizontal, 12)

                Spacer()

                // Player 1 score (bottom)
                ConnectFourScoreBanner(player: 1, score: score1, isTop: false)
            }

            GameOverlay {
                dismiss()
            }

            if showResult {
                resultOverlay
            }
        }
    }

    private var boardView: some View {
        VStack(spacing: 3) {
            // Column tap targets at top
            HStack(spacing: 3) {
                ForEach(0..<columns, id: \.self) { col in
                    Button {
                        dropDisc(in: col)
                    } label: {
                        VStack(spacing: 3) {
                            // Drop indicator arrow
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(
                                    canDrop(in: col) && !showResult
                                        ? (currentPlayer == 1 ? Color.red : Color.yellow).opacity(0.5)
                                        : Color.clear
                                )
                                .frame(height: 14)

                            // Column cells
                            ForEach(0..<rows, id: \.self) { row in
                                cellView(row: row, col: col)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDrop(in: col) || showResult)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.05, green: 0.12, blue: 0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    private func cellView(row: Int, col: Int) -> some View {
        let value = board[row][col]
        let isWinning = winningCells.contains("\(row),\(col)")
        let isLastDrop = lastDropRow == row && lastDropColumn == col

        return ZStack {
            Circle()
                .fill(Color(white: 0.04))
                .overlay(
                    Circle()
                        .stroke(isWinning ? Color.white.opacity(0.6) : Color.white.opacity(0.06), lineWidth: isWinning ? 2 : 1)
                )

            if value == 1 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.red.opacity(0.9), Color(red: 0.7, green: 0.1, blue: 0.1)],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .padding(4)
                    .scaleEffect(isLastDrop && dropAnimating ? 1.0 : (isLastDrop ? 0.3 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dropAnimating)
            } else if value == 2 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.yellow, Color(red: 0.85, green: 0.65, blue: 0.0)],
                            center: .init(x: 0.35, y: 0.35),
                            startRadius: 0,
                            endRadius: 20
                        )
                    )
                    .padding(4)
                    .scaleEffect(isLastDrop && dropAnimating ? 1.0 : (isLastDrop ? 0.3 : 1.0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dropAnimating)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func canDrop(in col: Int) -> Bool {
        board[0][col] == 0
    }

    private func dropDisc(in col: Int) {
        guard winner == nil, !isDraw, canDrop(in: col) else { return }

        // Find lowest empty row
        var targetRow = -1
        for row in stride(from: rows - 1, through: 0, by: -1) {
            if board[row][col] == 0 {
                targetRow = row
                break
            }
        }
        guard targetRow >= 0 else { return }

        lastDropColumn = col
        lastDropRow = targetRow
        dropAnimating = false

        board[targetRow][col] = currentPlayer
        SoundManager.playDrop()
        HapticManager.impact(.light)

        // Trigger animation
        DispatchQueue.main.async {
            dropAnimating = true
        }

        // Check win
        if let cells = checkWin(row: targetRow, col: col) {
            winningCells = cells
            winner = currentPlayer
            if currentPlayer == 1 { score1 += 1 } else { score2 += 1 }
            SoundManager.playWin()
            HapticManager.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
        } else if board[0].allSatisfy({ $0 != 0 }) {
            isDraw = true
            SoundManager.playDraw()
            HapticManager.notification(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
        } else {
            currentPlayer = currentPlayer == 1 ? 2 : 1
        }
    }

    private func checkWin(row: Int, col: Int) -> Set<String>? {
        let player = board[row][col]
        let directions: [(Int, Int)] = [(0, 1), (1, 0), (1, 1), (1, -1)]

        for (dr, dc) in directions {
            var cells: [String] = ["\(row),\(col)"]

            // Check forward
            for i in 1...3 {
                let r = row + dr * i
                let c = col + dc * i
                guard r >= 0, r < rows, c >= 0, c < columns, board[r][c] == player else { break }
                cells.append("\(r),\(c)")
            }

            // Check backward
            for i in 1...3 {
                let r = row - dr * i
                let c = col - dc * i
                guard r >= 0, r < rows, c >= 0, c < columns, board[r][c] == player else { break }
                cells.append("\(r),\(c)")
            }

            if cells.count >= 4 {
                return Set(cells)
            }
        }
        return nil
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
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                } else {
                    Text("🤝")
                        .font(.system(size: 48))
                    Text("It's a Draw!")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                HStack(spacing: 14) {
                    Button {
                        HapticManager.impact(.medium)
                        resetBoard()
                    } label: {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.blue))
                    }

                    Button {
                        HapticManager.impact(.light)
                        dismiss()
                    } label: {
                        Text("Exit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.1)))
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    private func resetBoard() {
        withAnimation {
            board = Array(repeating: Array(repeating: 0, count: columns), count: rows)
            currentPlayer = 1
            winner = nil
            isDraw = false
            winningCells = []
            showResult = false
            lastDropColumn = nil
            lastDropRow = nil
        }
    }
}

struct ConnectFourScoreBanner: View {
    let player: Int
    let score: Int
    let isTop: Bool

    var color: Color { player == 1 ? .red : .yellow }

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                Text("Player \(player)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
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
    ConnectFourView()
        .preferredColorScheme(.dark)
}
