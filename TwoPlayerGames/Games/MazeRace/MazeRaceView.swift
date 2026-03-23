import SwiftUI

// MARK: - Maze Cell

struct MazeCell {
    var topWall = true
    var bottomWall = true
    var leftWall = true
    var rightWall = true
    var visited = false
}

// MARK: - Maze Generator (Recursive Backtracking / DFS)

struct MazeGenerator {
    static func generate(rows: Int, cols: Int) -> [[MazeCell]] {
        var grid = Array(repeating: Array(repeating: MazeCell(), count: cols), count: rows)

        func neighbors(r: Int, c: Int) -> [(Int, Int)] {
            var result: [(Int, Int)] = []
            if r > 0 { result.append((r - 1, c)) }
            if r < rows - 1 { result.append((r + 1, c)) }
            if c > 0 { result.append((r, c - 1)) }
            if c < cols - 1 { result.append((r, c + 1)) }
            return result
        }

        func removeWall(from: (Int, Int), to: (Int, Int)) {
            let (r1, c1) = from
            let (r2, c2) = to
            if r2 == r1 - 1 { grid[r1][c1].topWall = false; grid[r2][c2].bottomWall = false }
            if r2 == r1 + 1 { grid[r1][c1].bottomWall = false; grid[r2][c2].topWall = false }
            if c2 == c1 - 1 { grid[r1][c1].leftWall = false; grid[r2][c2].rightWall = false }
            if c2 == c1 + 1 { grid[r1][c1].rightWall = false; grid[r2][c2].leftWall = false }
        }

        // Iterative DFS to avoid stack overflow
        var stack: [(Int, Int)] = [(0, 0)]
        grid[0][0].visited = true

        while !stack.isEmpty {
            let current = stack.last!
            let unvisited = neighbors(r: current.0, c: current.1).filter { !grid[$0.0][$0.1].visited }

            if unvisited.isEmpty {
                stack.removeLast()
            } else {
                let next = unvisited.randomElement()!
                removeWall(from: current, to: next)
                grid[next.0][next.1].visited = true
                stack.append(next)
            }
        }

        return grid
    }
}

// MARK: - Direction

enum MoveDirection {
    case up, down, left, right
}

// MARK: - Maze Race Engine

@Observable
final class MazeRaceEngine {
    let rows = 8
    let cols = 8

    var maze: [[MazeCell]] = []
    var p1Position: (row: Int, col: Int) = (0, 0)
    var p2Position: (row: Int, col: Int) = (0, 0)
    var score1 = 0
    var score2 = 0
    var currentRound = 1
    var winner: Int? = nil
    var showResult = false
    var gameStarted = false
    var roundWinner: Int? = nil
    var showRoundBanner = false
    var elapsedTime: TimeInterval = 0

    // Animated positions for smooth movement
    var p1AnimatedRow: CGFloat = 0
    var p1AnimatedCol: CGFloat = 0
    var p2AnimatedRow: CGFloat = 0
    var p2AnimatedCol: CGFloat = 0

    // Fog of war
    let fogRadius = 2

    private var timer: Timer?

    var exitPosition: (row: Int, col: Int) {
        (rows - 1, cols - 1)
    }

    func startGame() {
        score1 = 0
        score2 = 0
        currentRound = 1
        winner = nil
        showResult = false
        gameStarted = true
        startRound()
    }

    func startRound() {
        maze = MazeGenerator.generate(rows: rows, cols: cols)
        p1Position = (0, 0)
        p2Position = (0, 0)
        p1AnimatedRow = 0
        p1AnimatedCol = 0
        p2AnimatedRow = 0
        p2AnimatedCol = 0
        roundWinner = nil
        showRoundBanner = false
        elapsedTime = 0
        startTimer()
    }

    func move(player: Int, direction: MoveDirection) {
        guard gameStarted, !showResult, !showRoundBanner else { return }

        let pos = player == 1 ? p1Position : p2Position
        let cell = maze[pos.row][pos.col]

        var newRow = pos.row
        var newCol = pos.col

        switch direction {
        case .up:
            guard !cell.topWall else {
                HapticManager.notification(.warning)
                return
            }
            newRow -= 1
        case .down:
            guard !cell.bottomWall else {
                HapticManager.notification(.warning)
                return
            }
            newRow += 1
        case .left:
            guard !cell.leftWall else {
                HapticManager.notification(.warning)
                return
            }
            newCol -= 1
        case .right:
            guard !cell.rightWall else {
                HapticManager.notification(.warning)
                return
            }
            newCol += 1
        }

        guard newRow >= 0, newRow < rows, newCol >= 0, newCol < cols else { return }

        HapticManager.impact(.light)

        if player == 1 {
            p1Position = (newRow, newCol)
            withAnimation(.easeOut(duration: 0.12)) {
                p1AnimatedRow = CGFloat(newRow)
                p1AnimatedCol = CGFloat(newCol)
            }
        } else {
            p2Position = (newRow, newCol)
            withAnimation(.easeOut(duration: 0.12)) {
                p2AnimatedRow = CGFloat(newRow)
                p2AnimatedCol = CGFloat(newCol)
            }
        }

        // Check if player reached exit
        if newRow == exitPosition.row && newCol == exitPosition.col {
            playerReachedExit(player: player)
        }
    }

    func moveToAdjacentCell(player: Int, targetRow: Int, targetCol: Int) {
        let pos = player == 1 ? p1Position : p2Position
        let dr = targetRow - pos.row
        let dc = targetCol - pos.col

        // Only allow moving to directly adjacent cells
        guard abs(dr) + abs(dc) == 1 else { return }

        if dr == -1 { move(player: player, direction: .up) }
        else if dr == 1 { move(player: player, direction: .down) }
        else if dc == -1 { move(player: player, direction: .left) }
        else if dc == 1 { move(player: player, direction: .right) }
    }

    private func playerReachedExit(player: Int) {
        timer?.invalidate()
        roundWinner = player
        SoundManager.playScore()
        HapticManager.impact(.medium)

        if player == 1 {
            score1 += 1
        } else {
            score2 += 1
        }

        // Check match winner (best of 3 = first to 2)
        if score1 >= 2 || score2 >= 2 {
            winner = score1 >= 2 ? 1 : 2
            SoundManager.playWin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                gameStarted = false
                showResult = true
            }
        } else {
            showRoundBanner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
                showRoundBanner = false
                currentRound += 1
                startRound()
            }
        }
    }

    func isVisible(for player: Int, row: Int, col: Int) -> Bool {
        let pos = player == 1 ? p1Position : p2Position
        let dist = abs(pos.row - row) + abs(pos.col - col)
        return dist <= fogRadius
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.gameStarted, !self.showResult, !self.showRoundBanner else { return }
                self.elapsedTime += 0.1
            }
        }
    }

    func pause() {
        timer?.invalidate()
    }

    func resume() {
        guard gameStarted, !showResult else { return }
        startTimer()
    }

    func cleanup() {
        timer?.invalidate()
        timer = nil
    }

    var formattedTime: String {
        let seconds = Int(elapsedTime) % 60
        let millis = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d.%d", seconds, millis)
    }
}

// MARK: - Maze Race View

struct MazeRaceView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = MazeRaceEngine()
    @State private var isPaused = false
    @State private var showTutorial = false
    @AppStorage("hasSeenMazeRaceTutorial") private var hasSeenTutorial = false

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score banner (top, rotated for face-to-face)
                    FrostedScoreBanner(player: 2, score: engine.score2, color: .red, isTop: true)
                        .rotationEffect(.degrees(180))

                    // Player 1 half (top, rotated 180 for face-to-face play)
                    playerMazeView(player: 1)
                        .rotationEffect(.degrees(180))

                    // Center divider with round info
                    centerDivider

                    // Player 2 half (bottom, normal orientation)
                    playerMazeView(player: 2)

                    // Player 1 score banner (bottom)
                    FrostedScoreBanner(player: 1, score: engine.score1, color: .blue, isTop: false)
                }

                // Round winner banner
                if engine.showRoundBanner, let roundWinner = engine.roundWinner {
                    roundBannerOverlay(winner: roundWinner)
                }

                GameOverlay(onBack: {
                    engine.cleanup()
                    dismiss()
                }, onPause: {
                    engine.pause()
                    isPaused = true
                })

                if !showTutorial && !isPaused && !engine.showResult {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .mazeRace) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if engine.showResult {
                    if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameType: .mazeRace, gameName: "Maze Race") {
                            engine.startGame()
                        } onExit: {
                            engine.cleanup()
                            dismiss()
                        }
                    }
                }

                if isPaused && !engine.showResult {
                    PauseOverlay(
                        score1: engine.score1,
                        score2: engine.score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: {
                            isPaused = false
                            engine.resume()
                        },
                        onRestart: {
                            isPaused = false
                            engine.startGame()
                        },
                        onExit: {
                            engine.cleanup()
                            dismiss()
                        }
                    )
                }
            }
        }
        .onAppear {
            engine.startGame()
            if !hasSeenTutorial {
                showTutorial = true
                engine.pause()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !engine.showResult {
                engine.pause()
                isPaused = true
            }
        }
        .onChange(of: showTutorial) { _, showing in
            if !showing {
                engine.resume()
            }
        }
    }

    // MARK: - Player Maze View

    private func playerMazeView(player: Int) -> some View {
        GeometryReader { geo in
            let size = min(geo.size.width - 32, geo.size.height - 16)
            let cellSize = size / CGFloat(engine.cols)

            ZStack {
                // Maze grid
                mazeGrid(player: player, cellSize: cellSize)

                // Exit marker
                exitMarker(cellSize: cellSize, player: player)

                // Player marker
                playerMarker(player: player, cellSize: cellSize)
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(swipeGesture(player: player))
            .simultaneousGesture(tapGesture(player: player, cellSize: cellSize, mazeSize: size, geoSize: geo.size))
        }
    }

    // MARK: - Maze Grid Drawing

    private func mazeGrid(player: Int, cellSize: CGFloat) -> some View {
        Canvas { context, size in
            let wallColor = player == 1 ?
                Color(red: 0.3, green: 0.6, blue: 1.0) :
                Color(red: 1.0, green: 0.4, blue: 0.4)
            let wallWidth: CGFloat = 2.0

            for row in 0..<engine.rows {
                for col in 0..<engine.cols {
                    let visible = engine.isVisible(for: player, row: row, col: col)
                    guard visible else { continue }

                    let cell = engine.maze[row][col]
                    let x = CGFloat(col) * cellSize
                    let y = CGFloat(row) * cellSize

                    let alpha = alphaForDistance(player: player, row: row, col: col)
                    let resolvedColor = wallColor.opacity(alpha)

                    if cell.topWall {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y))
                        context.stroke(path, with: .color(resolvedColor), lineWidth: wallWidth)
                    }
                    if cell.bottomWall {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y + cellSize))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize))
                        context.stroke(path, with: .color(resolvedColor), lineWidth: wallWidth)
                    }
                    if cell.leftWall {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + cellSize))
                        context.stroke(path, with: .color(resolvedColor), lineWidth: wallWidth)
                    }
                    if cell.rightWall {
                        var path = Path()
                        path.move(to: CGPoint(x: x + cellSize, y: y))
                        path.addLine(to: CGPoint(x: x + cellSize, y: y + cellSize))
                        context.stroke(path, with: .color(resolvedColor), lineWidth: wallWidth)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func alphaForDistance(player: Int, row: Int, col: Int) -> Double {
        let pos = player == 1 ? engine.p1Position : engine.p2Position
        let dist = abs(pos.row - row) + abs(pos.col - col)
        if dist == 0 { return 1.0 }
        if dist == 1 { return 0.85 }
        return 0.5
    }

    // MARK: - Exit Marker

    private func exitMarker(cellSize: CGFloat, player: Int) -> some View {
        let visible = engine.isVisible(for: player, row: engine.exitPosition.row, col: engine.exitPosition.col)
        return Group {
            if visible {
                Text("\u{1F3C1}")
                    .font(.system(size: cellSize * 0.6))
                    .position(
                        x: CGFloat(engine.exitPosition.col) * cellSize + cellSize / 2,
                        y: CGFloat(engine.exitPosition.row) * cellSize + cellSize / 2
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Player Marker

    private func playerMarker(player: Int, cellSize: CGFloat) -> some View {
        let color: Color = player == 1 ? .blue : .red
        let animRow = player == 1 ? engine.p1AnimatedRow : engine.p2AnimatedRow
        let animCol = player == 1 ? engine.p1AnimatedCol : engine.p2AnimatedCol
        let markerSize = cellSize * 0.55

        return ZStack {
            // Glow
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: markerSize * 1.8, height: markerSize * 1.8)
                .blur(radius: 6)

            // Marker
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color, color.opacity(0.7)],
                        center: .center,
                        startRadius: 0,
                        endRadius: markerSize / 2
                    )
                )
                .frame(width: markerSize, height: markerSize)
                .shadow(color: color.opacity(0.6), radius: 8)
        }
        .position(
            x: animCol * cellSize + cellSize / 2,
            y: animRow * cellSize + cellSize / 2
        )
        .allowsHitTesting(false)
    }

    // MARK: - Swipe Gesture

    private func swipeGesture(player: Int) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height

                let direction: MoveDirection
                if abs(dx) > abs(dy) {
                    direction = dx > 0 ? .right : .left
                } else {
                    direction = dy > 0 ? .down : .up
                }

                engine.move(player: player, direction: direction)
            }
    }

    // MARK: - Tap Gesture

    private func tapGesture(player: Int, cellSize: CGFloat, mazeSize: CGFloat, geoSize: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                // Convert tap location to maze coordinates
                let offsetX = (geoSize.width - mazeSize) / 2
                let offsetY = (geoSize.height - mazeSize) / 2
                let localX = value.location.x - offsetX
                let localY = value.location.y - offsetY

                guard localX >= 0, localY >= 0 else { return }

                let col = Int(localX / cellSize)
                let row = Int(localY / cellSize)

                guard row >= 0, row < engine.rows, col >= 0, col < engine.cols else { return }

                engine.moveToAdjacentCell(player: player, targetRow: row, targetCol: col)
            }
    }

    // MARK: - Center Divider

    private var centerDivider: some View {
        HStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text("R\(engine.currentRound)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)

            Text(engine.formattedTime + "s")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
    }

    // MARK: - Round Banner

    private func roundBannerOverlay(winner: Int) -> some View {
        let color: Color = winner == 1 ? .blue : .red
        return VStack(spacing: 6) {
            Text(PlayerProfileManager.shared.name(for: winner))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(1.5)
            Text("Round \(engine.currentRound) Complete!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: color.opacity(0.2), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.showRoundBanner)
    }
}

#Preview {
    MazeRaceView()
        .preferredColorScheme(.dark)
}
