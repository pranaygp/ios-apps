import SwiftUI

// MARK: - Model

enum ReversiDisc: Equatable {
    case black // Player 1
    case white // Player 2

    var opposite: ReversiDisc {
        self == .black ? .white : .black
    }

    var player: Int {
        self == .black ? 1 : 2
    }
}

// MARK: - View

struct ReversiView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let boardSize = 8
    private let directions: [(Int, Int)] = [
        (-1, -1), (-1, 0), (-1, 1),
        (0, -1),           (0, 1),
        (1, -1),  (1, 0),  (1, 1)
    ]

    @State private var board: [[ReversiDisc?]]
    @State private var currentDisc: ReversiDisc = .black
    @State private var score1 = 2
    @State private var score2 = 2
    @State private var validMovePositions: Set<String> = []
    @State private var showResult = false
    @State private var winner: Int? = nil
    @State private var isDraw = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var lastPlacedRow: Int? = nil
    @State private var lastPlacedCol: Int? = nil
    @State private var flippingDiscs: [String: Bool] = [:] // key -> isFlipping
    @State private var flippingToColor: [String: ReversiDisc] = [:] // key -> target color
    @State private var showPassMessage = false
    @State private var passMessageText = ""
    @State private var consecutivePasses = 0
    @AppStorage("hasSeenTutorial_Reversi") private var hasSeenTutorial = false

    init() {
        var initial = Array(repeating: Array<ReversiDisc?>(repeating: nil, count: 8), count: 8)
        // Standard starting position
        initial[3][3] = .white
        initial[3][4] = .black
        initial[4][3] = .black
        initial[4][4] = .white
        _board = State(initialValue: initial)
    }

    var body: some View {
        GameTransitionView {
            ZStack {
                // Green felt background
                Color(red: 0.05, green: 0.22, blue: 0.08).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score (top, rotated)
                    FrostedScoreBanner(player: 2, score: score2, color: .red, isTop: true)

                    Spacer()

                    // Turn indicator
                    if !showResult {
                        turnIndicator
                            .padding(.bottom, 8)
                    }

                    // Board
                    boardView
                        .padding(.horizontal, 12)

                    Spacer()

                    // Player 1 score (bottom)
                    FrostedScoreBanner(player: 1, score: score1, color: .blue, isTop: false)
                }

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if !showTutorial && !isPaused && !showResult {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .reversi) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                // Pass message toast
                if showPassMessage {
                    passToast
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(50)
                }

                if showResult {
                    if let winner {
                        WinnerOverlay(winner: winner, gameType: .reversi, gameName: "Reversi") {
                            resetGame()
                        } onExit: {
                            dismiss()
                        }
                    } else if isDraw {
                        DrawOverlay {
                            resetGame()
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
                            resetGame()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
        }
        .onAppear {
            if !hasSeenTutorial { showTutorial = true }
            computeValidMoves()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !showResult {
                isPaused = true
            }
        }
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        HStack(spacing: 8) {
            // Mini disc indicator
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 14, height: 14)
                    .offset(y: 1)
                Circle()
                    .fill(currentDisc == .black ? Color(white: 0.1) : Color(white: 0.92))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(currentDisc == .black ? Color.white.opacity(0.2) : Color.black.opacity(0.15), lineWidth: 1)
                    )
            }
            Text("Player \(currentDisc.player)'s Turn")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .transition(.opacity)
    }

    // MARK: - Pass Toast

    private var passToast: some View {
        VStack {
            Spacer()
            Text(passMessageText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                        .overlay(
                            Capsule()
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
            Spacer()
        }
    }

    // MARK: - Board View

    private var boardView: some View {
        GeometryReader { geo in
            let boardWidth = geo.size.width
            let cellSize = boardWidth / CGFloat(boardSize)

            ZStack {
                // Green felt board background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.0, green: 0.42, blue: 0.15))

                // Grid lines
                ForEach(1..<boardSize, id: \.self) { i in
                    // Vertical lines
                    Rectangle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 1, height: boardWidth)
                        .position(x: CGFloat(i) * cellSize, y: boardWidth / 2)

                    // Horizontal lines
                    Rectangle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: boardWidth, height: 1)
                        .position(x: boardWidth / 2, y: CGFloat(i) * cellSize)
                }

                // Center dots (star points)
                ForEach([(2, 2), (2, 6), (6, 2), (6, 6)], id: \.0) { r, c in
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 6, height: 6)
                        .position(
                            x: CGFloat(c) * cellSize,
                            y: CGFloat(r) * cellSize
                        )
                }

                // Valid move indicators
                ForEach(Array(validMovePositions), id: \.self) { key in
                    let parts = key.split(separator: ",")
                    let row = Int(parts[0])!
                    let col = Int(parts[1])!
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: cellSize * 0.25, height: cellSize * 0.25)
                        .position(
                            x: CGFloat(col) * cellSize + cellSize / 2,
                            y: CGFloat(row) * cellSize + cellSize / 2
                        )
                        .allowsHitTesting(false)
                }

                // Last placed highlight
                if let lr = lastPlacedRow, let lc = lastPlacedCol {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                        .frame(width: cellSize - 4, height: cellSize - 4)
                        .position(
                            x: CGFloat(lc) * cellSize + cellSize / 2,
                            y: CGFloat(lr) * cellSize + cellSize / 2
                        )
                        .allowsHitTesting(false)
                }

                // Discs
                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { col in
                        let key = "\(row),\(col)"
                        if let disc = board[row][col] {
                            let isFlipping = flippingDiscs[key] == true
                            let flipTarget = flippingToColor[key]

                            discView(disc: disc, isFlipping: isFlipping, flipTarget: flipTarget, cellSize: cellSize)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                // Tap targets
                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { col in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                            .onTapGesture {
                                handleTap(row: row, col: col)
                            }
                    }
                }
            }
            .frame(width: boardWidth, height: boardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.0, green: 0.25, blue: 0.08), lineWidth: 3)
            )
            .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Disc View

    private func discView(disc: ReversiDisc, isFlipping: Bool, flipTarget: ReversiDisc?, cellSize: CGFloat) -> some View {
        let size = cellSize * 0.8
        let showDisc = isFlipping ? (flipTarget ?? disc) : disc
        let isBlack = isFlipping ? (showDisc == .black) : (disc == .black)

        return ZStack {
            // Shadow
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: size, height: size * 0.25)
                .offset(y: size * 0.4)

            // Disc body
            Circle()
                .fill(
                    RadialGradient(
                        colors: isBlack
                            ? [Color(white: 0.35), Color(white: 0.08)]
                            : [Color(white: 1.0), Color(white: 0.78)],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            isBlack ? Color.white.opacity(0.12) : Color.black.opacity(0.1),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        }
        .scaleEffect(x: isFlipping ? 0.15 : 1.0, y: 1.0)
        .animation(.easeInOut(duration: 0.15), value: isFlipping)
    }

    // MARK: - Tap Handling

    private func handleTap(row: Int, col: Int) {
        guard !showResult, !isPaused, !showPassMessage else { return }
        guard board[row][col] == nil else { return }
        guard validMovePositions.contains("\(row),\(col)") else { return }

        // Find all discs to flip
        let toFlip = discsToFlip(row: row, col: col, disc: currentDisc)
        guard !toFlip.isEmpty else { return }

        // Place the disc
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            board[row][col] = currentDisc
        }

        lastPlacedRow = row
        lastPlacedCol = col
        consecutivePasses = 0
        HapticManager.impact(.light)

        // Animate flips with staggered timing
        let flipped = toFlip
        let flipCount = flipped.count

        // Medium haptic for multi-flip
        if flipCount >= 3 {
            HapticManager.impact(.heavy)
        } else if flipCount >= 2 {
            HapticManager.impact(.medium)
        }

        for (index, pos) in flipped.enumerated() {
            let key = "\(pos.0),\(pos.1)"
            let delay = Double(index) * 0.08

            // Phase 1: Squeeze to thin (hide current color)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeIn(duration: 0.15)) {
                    flippingDiscs[key] = true
                }
            }

            // Phase 2: Swap color and expand back
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.15) {
                board[pos.0][pos.1] = currentDisc
                flippingToColor[key] = currentDisc
                withAnimation(.easeOut(duration: 0.15)) {
                    flippingDiscs[key] = false
                }
            }

            // Clean up flip state
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 0.3) {
                flippingDiscs.removeValue(forKey: key)
                flippingToColor.removeValue(forKey: key)
            }
        }

        // After all flips complete, update scores and switch turn
        let totalDelay = Double(flipCount) * 0.08 + 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            updateScores()

            // Switch player
            let nextDisc = currentDisc.opposite
            let nextMoves = getValidMovePositions(for: nextDisc)

            if !nextMoves.isEmpty {
                currentDisc = nextDisc
                validMovePositions = nextMoves
            } else {
                // Next player has no moves — check if current player can still go
                let currentMoves = getValidMovePositions(for: currentDisc)
                if !currentMoves.isEmpty {
                    // Pass the turn
                    showPassToast(player: nextDisc.player)
                    validMovePositions = currentMoves
                    // Don't switch currentDisc — same player goes again
                } else {
                    // Neither player can move — game over
                    endGame()
                }
            }
        }
    }

    // MARK: - Pass Toast

    private func showPassToast(player: Int) {
        passMessageText = "No valid moves — Player \(player) passes"
        HapticManager.impact(.medium)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showPassMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                showPassMessage = false
            }
        }
    }

    // MARK: - Game End

    private func endGame() {
        HapticManager.notification(.success)
        SoundManager.playWin()
        if score1 > score2 {
            winner = 1
        } else if score2 > score1 {
            winner = 2
        } else {
            isDraw = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showResult = true
        }
    }

    // MARK: - Score

    private func updateScores() {
        var black = 0
        var white = 0
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if board[row][col] == .black { black += 1 }
                else if board[row][col] == .white { white += 1 }
            }
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            score1 = black
            score2 = white
        }
    }

    // MARK: - Valid Moves

    private func computeValidMoves() {
        validMovePositions = getValidMovePositions(for: currentDisc)
    }

    private func getValidMovePositions(for disc: ReversiDisc) -> Set<String> {
        var positions: Set<String> = []
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if board[row][col] == nil && !discsToFlip(row: row, col: col, disc: disc).isEmpty {
                    positions.insert("\(row),\(col)")
                }
            }
        }
        return positions
    }

    private func discsToFlip(row: Int, col: Int, disc: ReversiDisc) -> [(Int, Int)] {
        var allFlips: [(Int, Int)] = []

        for (dr, dc) in directions {
            var flips: [(Int, Int)] = []
            var r = row + dr
            var c = col + dc

            // Walk in direction, collecting opponent discs
            while r >= 0 && r < boardSize && c >= 0 && c < boardSize {
                if board[r][c] == disc.opposite {
                    flips.append((r, c))
                } else if board[r][c] == disc {
                    // Found our own disc — these flips are valid
                    allFlips.append(contentsOf: flips)
                    break
                } else {
                    // Empty square — no flips in this direction
                    break
                }
                r += dr
                c += dc
            }
        }

        return allFlips
    }

    // MARK: - Reset

    private func resetGame() {
        var initial = Array(repeating: Array<ReversiDisc?>(repeating: nil, count: 8), count: 8)
        initial[3][3] = .white
        initial[3][4] = .black
        initial[4][3] = .black
        initial[4][4] = .white

        withAnimation {
            board = initial
            currentDisc = .black
            score1 = 2
            score2 = 2
            validMovePositions = []
            showResult = false
            winner = nil
            isDraw = false
            lastPlacedRow = nil
            lastPlacedCol = nil
            flippingDiscs = [:]
            flippingToColor = [:]
            showPassMessage = false
            consecutivePasses = 0
        }
        computeValidMoves()
    }
}

#Preview {
    ReversiView()
        .preferredColorScheme(.dark)
}
