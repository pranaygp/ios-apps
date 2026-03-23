import SwiftUI

// MARK: - Model

struct CheckersPiece: Equatable {
    let player: Int // 1 or 2
    var isKing: Bool = false
}

struct CheckersMove: Equatable {
    let fromRow: Int
    let fromCol: Int
    let toRow: Int
    let toCol: Int
    var capturedRow: Int? = nil
    var capturedCol: Int? = nil
}

// MARK: - View

struct CheckersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    private let boardSize = 8

    // Board: nil = empty, CheckersPiece for occupied
    @State private var board: [[CheckersPiece?]]
    @State private var currentPlayer = 1
    @State private var selectedRow: Int? = nil
    @State private var selectedCol: Int? = nil
    @State private var validMoves: [CheckersMove] = []
    @State private var mustJumpMoves: [CheckersMove] = []
    @State private var multiJumpPiece: (row: Int, col: Int)? = nil
    @State private var score1 = 12 // pieces remaining
    @State private var score2 = 12
    @State private var showResult = false
    @State private var winner: Int? = nil
    @State private var isDraw = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var animatingMove: CheckersMove? = nil
    @State private var animatingPieceOffset: CGSize = .zero
    @State private var capturedPieceOpacity: [String: Double] = [:]
    @State private var newKingKey: String? = nil
    @AppStorage("hasSeenTutorial_Checkers") private var hasSeenTutorial = false

    init() {
        var initial = Array(repeating: Array<CheckersPiece?>(repeating: nil, count: 8), count: 8)
        // Player 2 (top, black pieces) — rows 0-2
        for row in 0..<3 {
            for col in 0..<8 {
                if (row + col) % 2 == 1 {
                    initial[row][col] = CheckersPiece(player: 2)
                }
            }
        }
        // Player 1 (bottom, red pieces) — rows 5-7
        for row in 5..<8 {
            for col in 0..<8 {
                if (row + col) % 2 == 1 {
                    initial[row][col] = CheckersPiece(player: 1)
                }
            }
        }
        _board = State(initialValue: initial)
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
                    TutorialOverlayView(content: .checkers) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if showResult {
                    if let winner {
                        WinnerOverlay(winner: winner, gameType: .checkers, gameName: "Checkers") {
                            resetGame()
                        } onExit: {
                            dismiss()
                        }
                    } else if isDraw {
                        DrawOverlay(gameName: "Checkers") {
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
            computeAllJumpMoves()
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
            Circle()
                .fill(currentPlayer == 1 ? Color.blue : Color.red)
                .frame(width: 12, height: 12)
                .shadow(color: (currentPlayer == 1 ? Color.blue : Color.red).opacity(0.5), radius: 4)
            Text("\(PlayerProfileManager.shared.name(for: currentPlayer))'s Turn")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
            if !mustJumpMoves.isEmpty {
                Text("— Must jump!")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Board View

    private var boardView: some View {
        GeometryReader { geo in
            let boardWidth = geo.size.width
            let cellSize = boardWidth / CGFloat(boardSize)

            ZStack {
                // Board squares
                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { col in
                        let isDark = (row + col) % 2 == 1
                        Rectangle()
                            .fill(isDark ? Color(red: 0.45, green: 0.28, blue: 0.15) : Color(red: 0.85, green: 0.75, blue: 0.58))
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: CGFloat(col) * cellSize + cellSize / 2,
                                y: CGFloat(row) * cellSize + cellSize / 2
                            )
                    }
                }

                // Board border
                Rectangle()
                    .stroke(Color(red: 0.3, green: 0.18, blue: 0.08), lineWidth: 3)
                    .frame(width: boardWidth, height: boardWidth)
                    .position(x: boardWidth / 2, y: boardWidth / 2)

                // Valid move indicators
                ForEach(validMoves, id: \.toRow) { move in
                    if !(validMoves.filter { $0.toRow == move.toRow && $0.toCol == move.toCol }.first != move) {
                        Circle()
                            .fill(Color.white.opacity(0.35))
                            .frame(width: cellSize * 0.3, height: cellSize * 0.3)
                            .position(
                                x: CGFloat(move.toCol) * cellSize + cellSize / 2,
                                y: CGFloat(move.toRow) * cellSize + cellSize / 2
                            )
                    }
                }

                // Must-jump pulsing highlights (when no piece selected yet)
                if selectedRow == nil && !mustJumpMoves.isEmpty {
                    ForEach(Array(Set(mustJumpMoves.map { "\($0.fromRow),\($0.fromCol)" })), id: \.self) { key in
                        let parts = key.split(separator: ",")
                        let r = Int(parts[0])!
                        let c = Int(parts[1])!
                        PulsingHighlight()
                            .frame(width: cellSize * 0.85, height: cellSize * 0.85)
                            .position(
                                x: CGFloat(c) * cellSize + cellSize / 2,
                                y: CGFloat(r) * cellSize + cellSize / 2
                            )
                            .allowsHitTesting(false)
                    }
                }

                // Selected cell highlight
                if let sr = selectedRow, let sc = selectedCol {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.yellow, lineWidth: 2.5)
                        .frame(width: cellSize - 2, height: cellSize - 2)
                        .position(
                            x: CGFloat(sc) * cellSize + cellSize / 2,
                            y: CGFloat(sr) * cellSize + cellSize / 2
                        )
                }

                // Pieces
                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { col in
                        if let piece = board[row][col] {
                            let key = "\(row),\(col)"
                            let isAnimating = animatingMove?.fromRow == row && animatingMove?.fromCol == col

                            pieceView(piece: piece, cellSize: cellSize, key: key)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2 + (isAnimating ? animatingPieceOffset.width : 0),
                                    y: CGFloat(row) * cellSize + cellSize / 2 + (isAnimating ? animatingPieceOffset.height : 0)
                                )
                                .opacity(capturedPieceOpacity[key] ?? 1.0)
                                .zIndex(isAnimating ? 10 : 1)
                        }
                    }
                }

                // Tap targets
                ForEach(0..<boardSize, id: \.self) { row in
                    ForEach(0..<boardSize, id: \.self) { col in
                        if (row + col) % 2 == 1 {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .frame(width: cellSize, height: cellSize)
                                .position(
                                    x: CGFloat(col) * cellSize + cellSize / 2,
                                    y: CGFloat(row) * cellSize + cellSize / 2
                                )
                                .onTapGesture {
                                    handleTap(row: row, col: col, cellSize: cellSize)
                                }
                        }
                    }
                }
            }
            .frame(width: boardWidth, height: boardWidth)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .shadow(color: .black.opacity(0.5), radius: 12, y: 4)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Piece View

    private func pieceView(piece: CheckersPiece, cellSize: CGFloat, key: String) -> some View {
        let isPlayer1 = piece.player == 1
        let baseColor = isPlayer1 ? Color(red: 0.85, green: 0.15, blue: 0.15) : Color(red: 0.15, green: 0.15, blue: 0.15)
        let highlightColor = isPlayer1 ? Color(red: 1.0, green: 0.4, blue: 0.4) : Color(red: 0.4, green: 0.4, blue: 0.4)
        let size = cellSize * 0.75
        let isNewKing = newKingKey == key

        return ZStack {
            // Shadow
            Circle()
                .fill(Color.black.opacity(0.35))
                .frame(width: size, height: size)
                .offset(y: 2)

            // Base circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [highlightColor, baseColor],
                        center: .init(x: 0.35, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.6
                    )
                )
                .frame(width: size, height: size)

            // Inner ring
            Circle()
                .stroke(highlightColor.opacity(0.5), lineWidth: 2)
                .frame(width: size * 0.7, height: size * 0.7)

            // King crown
            if piece.isKing {
                Image(systemName: "crown.fill")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.yellow, Color.orange],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .yellow.opacity(0.6), radius: 3)
                    .scaleEffect(isNewKing ? 1.3 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.5), value: isNewKing)
            }

            // Player indicator border
            Circle()
                .stroke(
                    isPlayer1 ? Color.blue.opacity(0.4) : Color.red.opacity(0.4),
                    lineWidth: 1.5
                )
                .frame(width: size + 2, height: size + 2)
        }
    }

    // MARK: - Tap Handling

    private func handleTap(row: Int, col: Int, cellSize: CGFloat) {
        guard !showResult, !isPaused else { return }

        // If tapping a valid move destination
        if selectedRow != nil {
            if let move = validMoves.first(where: { $0.toRow == row && $0.toCol == col }) {
                executeMove(move, cellSize: cellSize)
                return
            }
        }

        // If tapping own piece
        if let piece = board[row][col], piece.player == currentPlayer {
            // If in multi-jump, can only continue with the jumping piece
            if let mjp = multiJumpPiece, (mjp.row != row || mjp.col != col) {
                return
            }

            // If must jump, only allow selecting pieces that can jump
            if !mustJumpMoves.isEmpty {
                let canJump = mustJumpMoves.contains { $0.fromRow == row && $0.fromCol == col }
                if !canJump { return }
            }

            selectPiece(row: row, col: col)
        } else if selectedRow != nil {
            // Tapped empty non-valid square — deselect (unless multi-jumping)
            if multiJumpPiece == nil {
                deselectPiece()
            }
        }
    }

    private func selectPiece(row: Int, col: Int) {
        HapticManager.impact(.light)
        selectedRow = row
        selectedCol = col
        computeValidMoves(fromRow: row, fromCol: col)
    }

    private func deselectPiece() {
        selectedRow = nil
        selectedCol = nil
        validMoves = []
    }

    // MARK: - Move Execution

    private func executeMove(_ move: CheckersMove, cellSize: CGFloat) {
        let fromRow = move.fromRow
        let fromCol = move.fromCol
        let toRow = move.toRow
        let toCol = move.toCol

        // Animate piece sliding
        let dx = CGFloat(toCol - fromCol) * cellSize
        let dy = CGFloat(toRow - fromRow) * cellSize

        animatingMove = move

        // Handle capture animation
        if let cr = move.capturedRow, let cc = move.capturedCol {
            let capturedKey = "\(cr),\(cc)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    capturedPieceOpacity[capturedKey] = 0.0
                }
            }
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            animatingPieceOffset = CGSize(width: dx, height: dy)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Apply move to board
            var piece = board[fromRow][fromCol]!
            board[fromRow][fromCol] = nil

            // Remove captured piece
            if let cr = move.capturedRow, let cc = move.capturedCol {
                let capturedPlayer = board[cr][cc]!.player
                board[cr][cc] = nil
                capturedPieceOpacity.removeValue(forKey: "\(cr),\(cc)")
                if capturedPlayer == 1 { score1 -= 1 } else { score2 -= 1 }
                HapticManager.impact(.heavy)
                SoundManager.playScore()
            } else {
                SoundManager.playPlace()
                HapticManager.impact(.medium)
            }

            // Check king promotion
            var becameKing = false
            if !piece.isKing {
                if (piece.player == 1 && toRow == 0) || (piece.player == 2 && toRow == 7) {
                    piece.isKing = true
                    becameKing = true
                    newKingKey = "\(toRow),\(toCol)"
                    HapticManager.notification(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        newKingKey = nil
                    }
                }
            }

            board[toRow][toCol] = piece
            animatingMove = nil
            animatingPieceOffset = .zero

            // Check for multi-jump
            let isJump = move.capturedRow != nil
            if isJump && !becameKing {
                let continuationJumps = getJumpMoves(fromRow: toRow, fromCol: toCol, piece: piece)
                if !continuationJumps.isEmpty {
                    // Must continue jumping
                    multiJumpPiece = (row: toRow, col: toCol)
                    selectedRow = toRow
                    selectedCol = toCol
                    validMoves = continuationJumps
                    mustJumpMoves = continuationJumps
                    return
                }
            }

            // Turn complete
            multiJumpPiece = nil
            deselectPiece()

            // Check win condition
            if checkWinCondition() { return }

            // Switch player
            currentPlayer = currentPlayer == 1 ? 2 : 1
            computeAllJumpMoves()

            // Check if new player has no moves
            if !hasAnyLegalMoves(for: currentPlayer) {
                winner = currentPlayer == 1 ? 2 : 1
                SoundManager.playWin()
                HapticManager.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showResult = true
                }
            }

            // Auto-select if only one piece can move due to forced jump
            autoSelectForcedPiece()
        }
    }

    // MARK: - Auto-select forced piece

    private func autoSelectForcedPiece() {
        guard multiJumpPiece == nil else { return }
        if !mustJumpMoves.isEmpty {
            let uniquePieces = Set(mustJumpMoves.map { "\($0.fromRow),\($0.fromCol)" })
            if uniquePieces.count == 1 {
                let move = mustJumpMoves[0]
                selectPiece(row: move.fromRow, col: move.fromCol)
            }
        }
    }

    // MARK: - Win Check

    private func checkWinCondition() -> Bool {
        if score1 == 0 {
            winner = 2
            SoundManager.playWin()
            HapticManager.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
            return true
        }
        if score2 == 0 {
            winner = 1
            SoundManager.playWin()
            HapticManager.notification(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showResult = true
            }
            return true
        }
        return false
    }

    // MARK: - Move Computation

    private func computeAllJumpMoves() {
        mustJumpMoves = []
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if let piece = board[row][col], piece.player == currentPlayer {
                    mustJumpMoves.append(contentsOf: getJumpMoves(fromRow: row, fromCol: col, piece: piece))
                }
            }
        }
    }

    private func computeValidMoves(fromRow: Int, fromCol: Int) {
        guard let piece = board[fromRow][fromCol] else {
            validMoves = []
            return
        }

        // If must jump, only show jump moves for this piece
        if !mustJumpMoves.isEmpty {
            validMoves = mustJumpMoves.filter { $0.fromRow == fromRow && $0.fromCol == fromCol }
            return
        }

        // Regular moves
        var moves: [CheckersMove] = []
        let directions = moveDirections(for: piece)

        for (dr, dc) in directions {
            let newRow = fromRow + dr
            let newCol = fromCol + dc
            if isValidSquare(newRow, newCol) && board[newRow][newCol] == nil {
                moves.append(CheckersMove(fromRow: fromRow, fromCol: fromCol, toRow: newRow, toCol: newCol))
            }
        }

        // Jump moves
        moves.append(contentsOf: getJumpMoves(fromRow: fromRow, fromCol: fromCol, piece: piece))

        validMoves = moves
    }

    private func getJumpMoves(fromRow: Int, fromCol: Int, piece: CheckersPiece) -> [CheckersMove] {
        var jumps: [CheckersMove] = []
        let directions = moveDirections(for: piece)

        for (dr, dc) in directions {
            let midRow = fromRow + dr
            let midCol = fromCol + dc
            let landRow = fromRow + dr * 2
            let landCol = fromCol + dc * 2

            if isValidSquare(landRow, landCol),
               let midPiece = board[midRow][midCol],
               midPiece.player != piece.player,
               board[landRow][landCol] == nil {
                jumps.append(CheckersMove(
                    fromRow: fromRow, fromCol: fromCol,
                    toRow: landRow, toCol: landCol,
                    capturedRow: midRow, capturedCol: midCol
                ))
            }
        }

        return jumps
    }

    private func moveDirections(for piece: CheckersPiece) -> [(Int, Int)] {
        if piece.isKing {
            return [(-1, -1), (-1, 1), (1, -1), (1, 1)]
        }
        // Player 1 moves up (negative row), Player 2 moves down (positive row)
        if piece.player == 1 {
            return [(-1, -1), (-1, 1)]
        } else {
            return [(1, -1), (1, 1)]
        }
    }

    private func isValidSquare(_ row: Int, _ col: Int) -> Bool {
        row >= 0 && row < boardSize && col >= 0 && col < boardSize
    }

    private func hasAnyLegalMoves(for player: Int) -> Bool {
        for row in 0..<boardSize {
            for col in 0..<boardSize {
                if let piece = board[row][col], piece.player == player {
                    let dirs = moveDirections(for: piece)
                    // Check regular moves
                    for (dr, dc) in dirs {
                        let nr = row + dr
                        let nc = col + dc
                        if isValidSquare(nr, nc) && board[nr][nc] == nil {
                            return true
                        }
                    }
                    // Check jumps
                    if !getJumpMoves(fromRow: row, fromCol: col, piece: piece).isEmpty {
                        return true
                    }
                }
            }
        }
        return false
    }

    // MARK: - Reset

    private func resetGame() {
        var initial = Array(repeating: Array<CheckersPiece?>(repeating: nil, count: 8), count: 8)
        for row in 0..<3 {
            for col in 0..<8 where (row + col) % 2 == 1 {
                initial[row][col] = CheckersPiece(player: 2)
            }
        }
        for row in 5..<8 {
            for col in 0..<8 where (row + col) % 2 == 1 {
                initial[row][col] = CheckersPiece(player: 1)
            }
        }
        withAnimation {
            board = initial
            currentPlayer = 1
            selectedRow = nil
            selectedCol = nil
            validMoves = []
            mustJumpMoves = []
            multiJumpPiece = nil
            score1 = 12
            score2 = 12
            showResult = false
            winner = nil
            isDraw = false
            animatingMove = nil
            animatingPieceOffset = .zero
            capturedPieceOpacity = [:]
            newKingKey = nil
        }
        computeAllJumpMoves()
    }
}

// MARK: - Pulsing Highlight

struct PulsingHighlight: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .stroke(Color.orange, lineWidth: 2.5)
            .scaleEffect(pulse ? 1.1 : 0.9)
            .opacity(pulse ? 0.9 : 0.4)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

#Preview {
    CheckersView()
        .preferredColorScheme(.dark)
}
