import SwiftUI

// MARK: - Direction

private enum SnakeDirection: CaseIterable {
    case up, down, left, right

    var delta: (dx: Int, dy: Int) {
        switch self {
        case .up: return (0, -1)
        case .down: return (0, 1)
        case .left: return (-1, 0)
        case .right: return (1, 0)
        }
    }

    var opposite: SnakeDirection {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: - GridPoint

private struct GridPoint: Equatable, Hashable {
    var x: Int
    var y: Int
}

// MARK: - Snake

private struct Snake {
    var segments: [GridPoint]
    var direction: SnakeDirection
    var nextDirection: SnakeDirection
    var alive: Bool = true

    var head: GridPoint { segments.first! }
    var length: Int { segments.count }
}

// MARK: - Game Engine

@Observable
private final class SnakeGameEngine {
    var cols: Int = 20
    var rows: Int = 30
    var snake1: Snake
    var snake2: Snake
    var food: GridPoint
    var totalFoodEaten: Int = 0
    var gameOver: Bool = false
    var winner: Int? = nil // 1, 2, or nil for draw
    var isDraw: Bool = false
    var tickInterval: TimeInterval = 0.15
    var deathSegments1: [(CGPoint, CGVector)] = []
    var deathSegments2: [(CGPoint, CGVector)] = []
    var deathAnimationProgress: Double = 0

    private var cellSize: CGSize = .zero
    private var lastTick: Date = .now

    init() {
        snake1 = Snake(segments: [GridPoint(x: 3, y: 3)], direction: .right, nextDirection: .right)
        snake2 = Snake(segments: [GridPoint(x: 16, y: 26)], direction: .left, nextDirection: .left)
        food = GridPoint(x: 10, y: 15)
    }

    func setup(cols: Int, rows: Int, cellSize: CGSize) {
        self.cols = cols
        self.rows = rows
        self.cellSize = cellSize
        reset()
    }

    func reset() {
        let startLen = 3
        // Player 1 starts top-left going right
        var s1Segs: [GridPoint] = []
        for i in 0..<startLen {
            s1Segs.append(GridPoint(x: 3 - i, y: 3))
        }
        snake1 = Snake(segments: s1Segs, direction: .right, nextDirection: .right)

        // Player 2 starts bottom-right going left
        var s2Segs: [GridPoint] = []
        for i in 0..<startLen {
            s2Segs.append(GridPoint(x: cols - 4 + i, y: rows - 4))
        }
        snake2 = Snake(segments: s2Segs, direction: .left, nextDirection: .left)

        totalFoodEaten = 0
        gameOver = false
        winner = nil
        isDraw = false
        tickInterval = 0.15
        lastTick = .now
        deathSegments1 = []
        deathSegments2 = []
        deathAnimationProgress = 0
        spawnFood()
    }

    func setDirection(player: Int, direction: SnakeDirection) {
        if player == 1 && snake1.alive {
            if direction != snake1.direction.opposite {
                snake1.nextDirection = direction
            }
        } else if player == 2 && snake2.alive {
            if direction != snake2.direction.opposite {
                snake2.nextDirection = direction
            }
        }
    }

    func tick() -> TickResult {
        guard !gameOver else { return .none }

        snake1.direction = snake1.nextDirection
        snake2.direction = snake2.nextDirection

        // Calculate new heads
        let newHead1 = GridPoint(
            x: snake1.head.x + snake1.direction.delta.dx,
            y: snake1.head.y + snake1.direction.delta.dy
        )
        let newHead2 = GridPoint(
            x: snake2.head.x + snake2.direction.delta.dx,
            y: snake2.head.y + snake2.direction.delta.dy
        )

        // Check collisions
        let dead1 = checkCollision(head: newHead1, ownBody: snake1.segments, otherBody: snake2.segments, otherNewHead: newHead2)
        let dead2 = checkCollision(head: newHead2, ownBody: snake2.segments, otherBody: snake1.segments, otherNewHead: newHead1)

        // Head-on collision
        let headOn = newHead1 == newHead2

        let actualDead1 = dead1 || headOn
        let actualDead2 = dead2 || headOn

        if actualDead1 || actualDead2 {
            if actualDead1 { createDeathParticles(snake: &snake1, storage: &deathSegments1) }
            if actualDead2 { createDeathParticles(snake: &snake2, storage: &deathSegments2) }
            snake1.alive = !actualDead1
            snake2.alive = !actualDead2
            gameOver = true
            if actualDead1 && actualDead2 {
                isDraw = true
                winner = nil
            } else {
                winner = actualDead1 ? 2 : 1
            }
            return .death
        }

        // Move snakes
        snake1.segments.insert(newHead1, at: 0)
        snake2.segments.insert(newHead2, at: 0)

        var ate = false
        // Check food
        if newHead1 == food {
            totalFoodEaten += 1
            ate = true
            spawnFood()
        } else {
            snake1.segments.removeLast()
        }

        if newHead2 == food {
            totalFoodEaten += 1
            ate = true
            spawnFood()
        } else {
            snake2.segments.removeLast()
        }

        // Speed up every 5 food
        if ate && totalFoodEaten % 5 == 0 {
            tickInterval = max(0.06, tickInterval - 0.01)
            return .speedUp
        }

        return ate ? .ate : .none
    }

    private func checkCollision(head: GridPoint, ownBody: [GridPoint], otherBody: [GridPoint], otherNewHead: GridPoint) -> Bool {
        // Wall collision
        if head.x < 0 || head.x >= cols || head.y < 0 || head.y >= rows {
            return true
        }
        // Self collision (skip head at index 0 since it moved)
        if ownBody.dropLast().contains(head) {
            return true
        }
        // Other snake collision (check full body since other hasn't moved tail yet)
        if otherBody.contains(head) {
            return true
        }
        return false
    }

    private func spawnFood() {
        let allOccupied = Set(snake1.segments + snake2.segments)
        var candidates: [GridPoint] = []
        for x in 0..<cols {
            for y in 0..<rows {
                let p = GridPoint(x: x, y: y)
                if !allOccupied.contains(p) {
                    candidates.append(p)
                }
            }
        }
        if let spot = candidates.randomElement() {
            food = spot
        }
    }

    private func createDeathParticles(snake: inout Snake, storage: inout [(CGPoint, CGVector)]) {
        storage = snake.segments.map { seg in
            let center = CGPoint(
                x: CGFloat(seg.x) * cellSize.width + cellSize.width / 2,
                y: CGFloat(seg.y) * cellSize.height + cellSize.height / 2
            )
            let velocity = CGVector(
                dx: CGFloat.random(in: -3...3),
                dy: CGFloat.random(in: -3...3)
            )
            return (center, velocity)
        }
    }

    enum TickResult {
        case none, ate, death, speedUp
    }
}

// MARK: - SnakeVsSnakeView

struct SnakeVsSnakeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var engine = SnakeGameEngine()
    @State private var isPaused = false
    @State private var showResult = false
    @State private var lastTickTime: Date = .now
    @State private var foodPulse: Double = 0
    @State private var deathTime: Date? = nil
    @State private var isSetup = false

    private let backgroundColor = Color(red: 0.1, green: 0.1, blue: 0.18)
    private let player1Color1 = Color(red: 0.0, green: 0.7, blue: 1.0)
    private let player1Color2 = Color(red: 0.0, green: 0.4, blue: 0.9)
    private let player2Color1 = Color(red: 1.0, green: 0.5, blue: 0.1)
    private let player2Color2 = Color(red: 0.9, green: 0.2, blue: 0.1)
    private let foodColor = Color(red: 0.2, green: 0.9, blue: 0.4)

    var body: some View {
        GameTransitionView {
            ZStack {
                backgroundColor.ignoresSafeArea()

                GeometryReader { geo in
                    let gridInfo = gridInfo(for: geo.size)

                    ZStack {
                        // Game canvas
                        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                            Canvas { context, size in
                                drawGame(context: &context, size: size, gridInfo: gridInfo, date: timeline.date)
                            }
                            .onChange(of: timeline.date) { _, newDate in
                                guard isSetup, !isPaused, !engine.gameOver else { return }
                                if newDate.timeIntervalSince(lastTickTime) >= engine.tickInterval {
                                    lastTickTime = newDate
                                    let result = engine.tick()
                                    handleTickResult(result)
                                }
                                foodPulse = sin(newDate.timeIntervalSinceReferenceDate * 3) * 0.3 + 0.7
                            }
                        }

                        // Death animation timeline
                        if let deathTime {
                            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                                Color.clear
                                    .onChange(of: timeline.date) { _, newDate in
                                        let elapsed = newDate.timeIntervalSince(deathTime)
                                        engine.deathAnimationProgress = min(elapsed / 1.0, 1.0)
                                        if elapsed > 1.0 && !showResult {
                                            showResult = true
                                        }
                                    }
                            }
                        }

                        // Swipe zones
                        HStack(spacing: 0) {
                            swipeZone(player: 1)
                            Rectangle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 1)
                            swipeZone(player: 2)
                        }

                        // Score display
                        VStack {
                            HStack {
                                scoreLabel(player: 1, score: engine.snake1.length, color: player1Color1)
                                Spacer()
                                scoreLabel(player: 2, score: engine.snake2.length, color: player2Color1)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            Spacer()
                        }
                    }
                    .onAppear {
                        engine.setup(cols: gridInfo.cols, rows: gridInfo.rows, cellSize: gridInfo.cellSize)
                        isSetup = true
                    }
                }
                .ignoresSafeArea()

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if showResult {
                    if engine.isDraw {
                        DrawOverlay {
                            restartGame()
                        } onExit: {
                            dismiss()
                        }
                    } else if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameName: "Snake vs Snake") {
                            restartGame()
                        } onExit: {
                            dismiss()
                        }
                    }
                }

                if isPaused && !showResult && !engine.gameOver {
                    PauseOverlay(
                        score1: engine.snake1.length,
                        score2: engine.snake2.length,
                        player1Color: player1Color1,
                        player2Color: player2Color1,
                        onResume: { isPaused = false },
                        onRestart: { restartGame() },
                        onExit: { dismiss() }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !showResult && !engine.gameOver {
                isPaused = true
            }
        }
    }

    // MARK: - Grid Layout

    private struct GridInfo {
        let cols: Int
        let rows: Int
        let cellSize: CGSize
        let origin: CGPoint
    }

    private func gridInfo(for size: CGSize) -> GridInfo {
        let targetCols = 20
        let cellW = size.width / CGFloat(targetCols)
        let rows = Int(size.height / cellW)
        let cellH = size.height / CGFloat(rows)
        return GridInfo(
            cols: targetCols,
            rows: rows,
            cellSize: CGSize(width: cellW, height: cellH),
            origin: .zero
        )
    }

    // MARK: - Drawing

    private func drawGame(context: inout GraphicsContext, size: CGSize, gridInfo: GridInfo, date: Date) {
        let cw = gridInfo.cellSize.width
        let ch = gridInfo.cellSize.height

        // Draw grid lines
        context.opacity = 0.1
        for x in 0...gridInfo.cols {
            let xPos = CGFloat(x) * cw
            var path = Path()
            path.move(to: CGPoint(x: xPos, y: 0))
            path.addLine(to: CGPoint(x: xPos, y: size.height))
            context.stroke(path, with: .color(.white), lineWidth: 0.5)
        }
        for y in 0...gridInfo.rows {
            let yPos = CGFloat(y) * ch
            var path = Path()
            path.move(to: CGPoint(x: 0, y: yPos))
            path.addLine(to: CGPoint(x: size.width, y: yPos))
            context.stroke(path, with: .color(.white), lineWidth: 0.5)
        }
        context.opacity = 1.0

        // Draw food
        if !engine.gameOver {
            let fx = CGFloat(engine.food.x) * cw + cw / 2
            let fy = CGFloat(engine.food.y) * ch + ch / 2
            let pulse = CGFloat(foodPulse)
            let radius = min(cw, ch) * 0.4 * pulse
            let foodRect = CGRect(x: fx - radius, y: fy - radius, width: radius * 2, height: radius * 2)
            context.fill(
                Path(ellipseIn: foodRect),
                with: .color(foodColor)
            )
            // Glow
            context.opacity = 0.3
            let glowRadius = radius * 1.8
            let glowRect = CGRect(x: fx - glowRadius, y: fy - glowRadius, width: glowRadius * 2, height: glowRadius * 2)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(foodColor)
            )
            context.opacity = 1.0
        }

        // Draw snakes
        if engine.snake1.alive || engine.deathAnimationProgress < 1.0 {
            drawSnake(context: &context, snake: engine.snake1, color1: player1Color1, color2: player1Color2, deathParticles: engine.deathSegments1, deathProgress: engine.snake1.alive ? 0 : engine.deathAnimationProgress, cw: cw, ch: ch)
        }
        if engine.snake2.alive || engine.deathAnimationProgress < 1.0 {
            drawSnake(context: &context, snake: engine.snake2, color1: player2Color1, color2: player2Color2, deathParticles: engine.deathSegments2, deathProgress: engine.snake2.alive ? 0 : engine.deathAnimationProgress, cw: cw, ch: ch)
        }
    }

    private func drawSnake(context: inout GraphicsContext, snake: Snake, color1: Color, color2: Color, deathParticles: [(CGPoint, CGVector)], deathProgress: Double, cw: CGFloat, ch: CGFloat) {
        if deathProgress > 0 && !deathParticles.isEmpty {
            // Death animation — scatter particles
            let opacity = 1.0 - deathProgress
            context.opacity = opacity
            for (center, velocity) in deathParticles {
                let x = center.x + velocity.dx * CGFloat(deathProgress) * 40
                let y = center.y + velocity.dy * CGFloat(deathProgress) * 40
                let size = (1.0 - deathProgress) * Double(min(cw, ch)) * 0.8
                let rect = CGRect(x: x - CGFloat(size / 2), y: y - CGFloat(size / 2), width: CGFloat(size), height: CGFloat(size))
                context.fill(
                    Path(roundedRect: rect, cornerRadius: CGFloat(size) * 0.2),
                    with: .color(color1)
                )
            }
            context.opacity = 1.0
            return
        }

        guard snake.alive else { return }

        let count = snake.segments.count
        for (i, seg) in snake.segments.enumerated() {
            let t = count > 1 ? CGFloat(i) / CGFloat(count - 1) : 0
            let rect = CGRect(
                x: CGFloat(seg.x) * cw + 1,
                y: CGFloat(seg.y) * ch + 1,
                width: cw - 2,
                height: ch - 2
            )

            let segColor = blendColor(color1, color2, t: t)

            context.fill(
                Path(roundedRect: rect, cornerRadius: min(cw, ch) * 0.25),
                with: .color(segColor)
            )

            // Glow on head
            if i == 0 {
                context.opacity = 0.4
                let glowRect = rect.insetBy(dx: -2, dy: -2)
                context.fill(
                    Path(roundedRect: glowRect, cornerRadius: min(cw, ch) * 0.3),
                    with: .color(color1)
                )
                context.opacity = 1.0
            }
        }
    }

    private func blendColor(_ c1: Color, _ c2: Color, t: CGFloat) -> Color {
        // Simple blend using resolved colors
        let uic1 = UIColor(c1)
        let uic2 = UIColor(c2)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uic1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uic2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(
            red: Double(r1 + (r2 - r1) * t),
            green: Double(g1 + (g2 - g1) * t),
            blue: Double(b1 + (b2 - b1) * t)
        )
    }

    // MARK: - Swipe Zones

    private func swipeZone(player: Int) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onEnded { value in
                        guard !isPaused, !engine.gameOver else { return }
                        let dx = value.translation.width
                        let dy = value.translation.height
                        let direction: SnakeDirection
                        if abs(dx) > abs(dy) {
                            direction = dx > 0 ? .right : .left
                        } else {
                            direction = dy > 0 ? .down : .up
                        }
                        engine.setDirection(player: player, direction: direction)
                    }
            )
    }

    // MARK: - Score Label

    private func scoreLabel(player: Int, score: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text("P\(player): \(score)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial, in: Capsule())
    }

    // MARK: - Game Actions

    private func handleTickResult(_ result: SnakeGameEngine.TickResult) {
        switch result {
        case .ate:
            SoundManager.playHit()
            HapticManager.impact(.light)
        case .death:
            SoundManager.playLose()
            HapticManager.impact(.heavy)
            deathTime = .now
        case .speedUp:
            SoundManager.playHit()
            HapticManager.impact(.light)
            HapticManager.notification(.warning)
        case .none:
            break
        }
    }

    private func restartGame() {
        engine.reset()
        showResult = false
        isPaused = false
        deathTime = nil
        lastTickTime = .now
    }
}
