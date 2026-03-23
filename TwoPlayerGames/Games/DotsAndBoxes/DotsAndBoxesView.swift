import SwiftUI

struct DotsAndBoxesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    // Grid: 5×5 dots → 4×4 boxes
    private let dotRows = 5
    private let dotCols = 5
    private let boxRows = 4
    private let boxCols = 4

    // Lines: horizontal[row][col] for row in 0..<5, col in 0..<4
    //        vertical[row][col] for row in 0..<4, col in 0..<5
    @State private var horizontalLines: [[Int]] // 0 = empty, 1 = player1, 2 = player2
    @State private var verticalLines: [[Int]]
    @State private var boxes: [[Int]] // 0 = unclaimed, 1 or 2 = player
    @State private var currentPlayer = 1
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var showResult = false
    @State private var winner: Int?
    @State private var isDraw = false
    @State private var isPaused = false
    @State private var extraTurn = false
    @State private var extraTurnOpacity: Double = 0
    @State private var lastCompletedBoxes: Set<String> = []
    @State private var boxScaleAnimations: Set<String> = []
    @State private var highlightedLine: LineID?
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial_DotsAndBoxes") private var hasSeenTutorial = false

    private let settings = GameSettings.shared

    struct LineID: Equatable, Hashable {
        let isHorizontal: Bool
        let row: Int
        let col: Int
    }

    init() {
        _horizontalLines = State(initialValue: Array(repeating: Array(repeating: 0, count: 4), count: 5))
        _verticalLines = State(initialValue: Array(repeating: Array(repeating: 0, count: 5), count: 4))
        _boxes = State(initialValue: Array(repeating: Array(repeating: 0, count: 4), count: 4))
    }

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score (top, rotated)
                    FrostedScoreBanner(player: 2, score: score2, color: .red, isTop: true)

                    Spacer()

                    // Turn indicator
                    if !showResult {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(currentPlayer == 1 ? Color.blue : Color.red)
                                .frame(width: 12, height: 12)
                                .shadow(color: (currentPlayer == 1 ? Color.blue : Color.red).opacity(0.5), radius: 4)
                            Text(extraTurn ? "Extra Turn!" : "\(PlayerProfileManager.shared.name(for: currentPlayer))'s Turn")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .padding(.bottom, 12)
                        .transition(.opacity)
                    }

                    // Board
                    boardView
                        .padding(.horizontal, 20)

                    Spacer()

                    // Player 1 score (bottom)
                    FrostedScoreBanner(player: 1, score: score1, color: .blue, isTop: false)
                }

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if !showTutorial && !isPaused && !showResult {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .dotsAndBoxes) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if showResult {
                    if let winner {
                        WinnerOverlay(winner: winner, gameType: .dotsAndBoxes, gameName: "Dots & Boxes") {
                            resetBoard()
                        } onExit: {
                            dismiss()
                        }
                    } else if isDraw {
                        DrawOverlay(gameName: "Dots & Boxes") {
                            resetBoard()
                        } onExit: {
                            dismiss()
                        }
                    }
                }

                if isPaused && !showResult {
                    PauseOverlay(
                        score1: score1,
                        score2: score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: { isPaused = false },
                        onRestart: {
                            isPaused = false
                            resetBoard()
                            score1 = 0
                            score2 = 0
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

    // MARK: - Board View

    private var boardView: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let totalHeight = totalWidth // square board
            let spacingH = totalWidth / CGFloat(dotCols - 1)
            let spacingV = totalHeight / CGFloat(dotRows - 1)
            let dotSize: CGFloat = 14
            let lineThickness: CGFloat = 6

            ZStack {
                // Boxes (filled when claimed)
                ForEach(0..<boxRows, id: \.self) { row in
                    ForEach(0..<boxCols, id: \.self) { col in
                        let boxKey = "\(row),\(col)"
                        if boxes[row][col] != 0 {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(boxes[row][col] == 1 ? Color.blue.opacity(0.3) : Color.red.opacity(0.3))
                                .frame(width: spacingH - lineThickness - 4, height: spacingV - lineThickness - 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(boxes[row][col] == 1 ? Color.blue.opacity(0.5) : Color.red.opacity(0.5), lineWidth: 1)
                                )
                                .position(
                                    x: CGFloat(col) * spacingH + spacingH / 2,
                                    y: CGFloat(row) * spacingV + spacingV / 2
                                )
                                .scaleEffect(boxScaleAnimations.contains(boxKey) ? 1.0 : 0.01)
                                .opacity(boxScaleAnimations.contains(boxKey) ? 1.0 : 0.0)
                                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: boxScaleAnimations.contains(boxKey))
                        }
                    }
                }

                // Horizontal lines
                ForEach(0..<dotRows, id: \.self) { row in
                    ForEach(0..<(dotCols - 1), id: \.self) { col in
                        let lineID = LineID(isHorizontal: true, row: row, col: col)
                        let isDrawn = horizontalLines[row][col] != 0
                        let isHighlighted = highlightedLine == lineID

                        Button {
                            placeLine(horizontal: true, row: row, col: col)
                        } label: {
                            RoundedRectangle(cornerRadius: lineThickness / 2)
                                .fill(lineColor(value: horizontalLines[row][col], highlighted: isHighlighted))
                                .frame(width: spacingH - dotSize, height: lineThickness)
                                .scaleEffect(x: isDrawn ? 1.0 : (isHighlighted ? 0.6 : 0.01), y: 1.0, anchor: .center)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDrawn)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDrawn || showResult || isPaused)
                        .position(
                            x: CGFloat(col) * spacingH + spacingH / 2,
                            y: CGFloat(row) * spacingV
                        )
                        .contentShape(Rectangle().size(width: spacingH, height: max(lineThickness, 30)))
                        .onHover { hovering in
                            if !isDrawn && !showResult && !isPaused {
                                highlightedLine = hovering ? lineID : nil
                            }
                        }
                    }
                }

                // Vertical lines
                ForEach(0..<(dotRows - 1), id: \.self) { row in
                    ForEach(0..<dotCols, id: \.self) { col in
                        let lineID = LineID(isHorizontal: false, row: row, col: col)
                        let isDrawn = verticalLines[row][col] != 0
                        let isHighlighted = highlightedLine == lineID

                        Button {
                            placeLine(horizontal: false, row: row, col: col)
                        } label: {
                            RoundedRectangle(cornerRadius: lineThickness / 2)
                                .fill(lineColor(value: verticalLines[row][col], highlighted: isHighlighted))
                                .frame(width: lineThickness, height: spacingV - dotSize)
                                .scaleEffect(x: 1.0, y: isDrawn ? 1.0 : (isHighlighted ? 0.6 : 0.01), anchor: .center)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDrawn)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDrawn || showResult || isPaused)
                        .position(
                            x: CGFloat(col) * spacingH,
                            y: CGFloat(row) * spacingV + spacingV / 2
                        )
                        .contentShape(Rectangle().size(width: max(lineThickness, 30), height: spacingV))
                        .onHover { hovering in
                            if !isDrawn && !showResult && !isPaused {
                                highlightedLine = hovering ? lineID : nil
                            }
                        }
                    }
                }

                // Dots
                ForEach(0..<dotRows, id: \.self) { row in
                    ForEach(0..<dotCols, id: \.self) { col in
                        Circle()
                            .fill(Color.white)
                            .frame(width: dotSize, height: dotSize)
                            .shadow(color: .white.opacity(0.3), radius: 3)
                            .position(
                                x: CGFloat(col) * spacingH,
                                y: CGFloat(row) * spacingV
                            )
                    }
                }
            }
            .frame(width: totalWidth, height: totalHeight)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Line Color

    private func lineColor(value: Int, highlighted: Bool) -> Color {
        switch value {
        case 1: return Color.blue
        case 2: return Color.red
        default:
            if highlighted {
                return currentPlayer == 1 ? Color.blue.opacity(0.4) : Color.red.opacity(0.4)
            }
            return Color.white.opacity(0.12)
        }
    }

    // MARK: - Place Line

    private func placeLine(horizontal: Bool, row: Int, col: Int) {
        guard !showResult, !isPaused else { return }

        if horizontal {
            guard horizontalLines[row][col] == 0 else { return }
            horizontalLines[row][col] = currentPlayer
        } else {
            guard verticalLines[row][col] == 0 else { return }
            verticalLines[row][col] = currentPlayer
        }

        highlightedLine = nil
        SoundManager.playPlace()
        HapticManager.impact(.medium)

        // Check if any boxes were completed
        let completed = checkCompletedBoxes(horizontal: horizontal, row: row, col: col)

        if !completed.isEmpty {
            // Player completed box(es) — score and extra turn
            for box in completed {
                boxes[box.row][box.col] = currentPlayer
                if currentPlayer == 1 { score1 += 1 } else { score2 += 1 }

                let boxKey = "\(box.row),\(box.col)"
                // Animate box fill
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    let _ = withAnimation {
                        boxScaleAnimations.insert(boxKey)
                    }
                }
            }

            HapticManager.notification(.success)
            SoundManager.playScore()

            // Show extra turn indicator
            withAnimation(.easeInOut(duration: 0.3)) {
                extraTurn = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    extraTurn = false
                }
            }

            // Check if game is over
            if score1 + score2 == boxRows * boxCols {
                endGame()
            }
            // Player gets another turn (don't switch)
        } else {
            // No box completed — switch player
            currentPlayer = currentPlayer == 1 ? 2 : 1
        }
    }

    // MARK: - Check Completed Boxes

    private func checkCompletedBoxes(horizontal: Bool, row: Int, col: Int) -> [(row: Int, col: Int)] {
        var completed: [(row: Int, col: Int)] = []

        if horizontal {
            // Horizontal line at (row, col) can complete box above (row-1, col) and below (row, col)
            // Box above
            if row > 0 {
                let boxRow = row - 1
                let boxCol = col
                if boxes[boxRow][boxCol] == 0 && isBoxComplete(row: boxRow, col: boxCol) {
                    completed.append((row: boxRow, col: boxCol))
                }
            }
            // Box below
            if row < boxRows {
                let boxRow = row
                let boxCol = col
                if boxes[boxRow][boxCol] == 0 && isBoxComplete(row: boxRow, col: boxCol) {
                    completed.append((row: boxRow, col: boxCol))
                }
            }
        } else {
            // Vertical line at (row, col) can complete box left (row, col-1) and right (row, col)
            // Box to the left
            if col > 0 {
                let boxRow = row
                let boxCol = col - 1
                if boxes[boxRow][boxCol] == 0 && isBoxComplete(row: boxRow, col: boxCol) {
                    completed.append((row: boxRow, col: boxCol))
                }
            }
            // Box to the right
            if col < boxCols {
                let boxRow = row
                let boxCol = col
                if boxes[boxRow][boxCol] == 0 && isBoxComplete(row: boxRow, col: boxCol) {
                    completed.append((row: boxRow, col: boxCol))
                }
            }
        }

        return completed
    }

    private func isBoxComplete(row: Int, col: Int) -> Bool {
        // A box at (row, col) needs:
        // Top: horizontalLines[row][col]
        // Bottom: horizontalLines[row+1][col]
        // Left: verticalLines[row][col]
        // Right: verticalLines[row][col+1]
        return horizontalLines[row][col] != 0
            && horizontalLines[row + 1][col] != 0
            && verticalLines[row][col] != 0
            && verticalLines[row][col + 1] != 0
    }

    // MARK: - End Game

    private func endGame() {
        if score1 > score2 {
            winner = 1
        } else if score2 > score1 {
            winner = 2
        } else {
            isDraw = true
        }

        if winner != nil {
            SoundManager.playWin()
        } else {
            SoundManager.playDraw()
        }
        HapticManager.notification(winner != nil ? .success : .warning)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showResult = true
        }
    }

    // MARK: - Reset

    private func resetBoard() {
        withAnimation {
            horizontalLines = Array(repeating: Array(repeating: 0, count: dotCols - 1), count: dotRows)
            verticalLines = Array(repeating: Array(repeating: 0, count: dotCols), count: dotRows - 1)
            boxes = Array(repeating: Array(repeating: 0, count: boxCols), count: boxRows)
            currentPlayer = 1
            winner = nil
            isDraw = false
            showResult = false
            extraTurn = false
            lastCompletedBoxes = []
            boxScaleAnimations = []
            highlightedLine = nil
        }
    }
}

#Preview {
    DotsAndBoxesView()
        .preferredColorScheme(.dark)
}
