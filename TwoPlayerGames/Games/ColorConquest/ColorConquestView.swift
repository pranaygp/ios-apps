import SwiftUI

struct ColorConquestView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    struct Tile: Identifiable {
        let id: Int
        let row: Int
        let col: Int
        var owner: Int = 0  // 0 = neutral, 1 = P1, 2 = P2
        var points: Int = 1
        var isShielded = false
    }

    @State private var tiles: [Tile] = []
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var timeRemaining: Double = 30
    @State private var gameWinner: Int?
    @State private var gameActive = false
    @State private var isPaused = false
    @State private var countdown: Int = 3
    @State private var showCountdown = true
    @State private var timer: Timer?
    @State private var p1Flash: Int? = nil
    @State private var p2Flash: Int? = nil
    @State private var bombAvailableP1 = true
    @State private var bombAvailableP2 = true
    @State private var bombModeP1 = false
    @State private var bombModeP2 = false
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial_ColorConquest") private var hasSeenTutorial = false

    private let gridCols = 6
    private let gridRows = 10  // 5 rows per player
    private let totalTime: Double = 30

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score + bomb
                    playerHeader(player: 2)
                        .rotationEffect(.degrees(180))

                    // Grid - P2 half (top, rotated for P2)
                    gridSection(player: 2)
                        .rotationEffect(.degrees(180))

                    // Timer bar
                    timerBar

                    // Grid - P1 half (bottom)
                    gridSection(player: 1)

                    // Player 1 score + bomb
                    playerHeader(player: 1)
                }

                // Countdown overlay
                if showCountdown {
                    countdownOverlay
                }

                GameOverlay(onBack: { cleanup(); dismiss() }, onPause: {
                    isPaused = true
                    timer?.invalidate()
                })

                if !showTutorial && !isPaused && gameWinner == nil {
                    TutorialInfoButton {
                        showTutorial = true
                        timer?.invalidate()
                    }
                }

                if showTutorial {
                    TutorialOverlayView(content: .colorConquest) {
                        showTutorial = false
                        hasSeenTutorial = true
                        if gameActive && !isPaused { startTimer() }
                    }
                }

                if let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameType: .colorConquest, gameName: "Color Conquest") {
                        resetGame()
                    } onExit: {
                        cleanup()
                        dismiss()
                    }
                }

                if isPaused && gameWinner == nil {
                    PauseOverlay(
                        score1: score1,
                        score2: score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: {
                            isPaused = false
                            startTimer()
                        },
                        onRestart: {
                            isPaused = false
                            resetGame()
                        },
                        onExit: { cleanup(); dismiss() }
                    )
                }
            }
            .onAppear {
                setupGrid()
                if !hasSeenTutorial {
                    showTutorial = true
                } else {
                    startCountdown()
                }
            }
            .onDisappear {
                cleanup()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && gameWinner == nil {
                isPaused = true
                timer?.invalidate()
            }
        }
    }

    // MARK: - Player Header

    private func playerHeader(player: Int) -> some View {
        let score = player == 1 ? score1 : score2
        let color: Color = player == 1 ? .blue : .red
        let bombAvailable = player == 1 ? bombAvailableP1 : bombAvailableP2
        let bombMode = player == 1 ? bombModeP1 : bombModeP2

        return HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .shadow(color: color.opacity(0.5), radius: 4)
                Text(PlayerProfileManager.shared.name(for: player))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            Spacer()

            // Bomb button
            if bombAvailable && gameActive {
                Button {
                    HapticManager.impact(.medium)
                    SoundManager.playButtonTap()
                    if player == 1 {
                        bombModeP1.toggle()
                    } else {
                        bombModeP2.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("\u{1F4A3}")
                            .font(.system(size: 16))
                        Text("Bomb")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(bombMode ? .orange : .white.opacity(0.5))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(bombMode ? Color.orange.opacity(0.2) : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(bombMode ? Color.orange.opacity(0.5) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Text("\(score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            ZStack {
                color.opacity(0.06)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(0.5)
            }
        )
    }

    // MARK: - Grid Section

    private func gridSection(player: Int) -> some View {
        let startRow = player == 1 ? gridRows / 2 : 0
        let endRow = player == 1 ? gridRows : gridRows / 2

        return VStack(spacing: 3) {
            ForEach(startRow..<endRow, id: \.self) { row in
                HStack(spacing: 3) {
                    ForEach(0..<gridCols, id: \.self) { col in
                        let index = row * gridCols + col
                        if index < tiles.count {
                            tileView(for: index, player: player)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func tileView(for index: Int, player: Int) -> some View {
        let tile = tiles[index]
        let flash = player == 1 ? p1Flash : p2Flash
        let isFlashing = flash == index

        return Button {
            claimTile(at: index, player: player)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(tileColor(for: tile))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(tileBorderColor(for: tile), lineWidth: tile.owner != 0 ? 1.5 : 0.5)
                    )
                    .shadow(color: isFlashing ? (player == 1 ? Color.blue : Color.red).opacity(0.5) : .clear, radius: isFlashing ? 6 : 0)

                if tile.points > 1 && tile.owner == 0 {
                    Text("\u{2B50}")
                        .font(.system(size: 10))
                        .opacity(0.7)
                }

                if tile.isShielded {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .buttonStyle(.plain)
        .disabled(!gameActive || isPaused || tile.owner == player)
        .scaleEffect(isFlashing ? 1.15 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isFlashing)
        .accessibilityLabel("Tile row \(tile.row + 1) column \(tile.col + 1), \(tile.owner == 0 ? "neutral" : "Player \(tile.owner)")")
    }

    private func tileColor(for tile: Tile) -> Color {
        switch tile.owner {
        case 1: return Color.blue.opacity(0.5)
        case 2: return Color.red.opacity(0.5)
        default:
            return tile.points > 1 ? Color(white: 0.12) : Color(white: 0.08)
        }
    }

    private func tileBorderColor(for tile: Tile) -> Color {
        switch tile.owner {
        case 1: return Color.blue.opacity(0.6)
        case 2: return Color.red.opacity(0.6)
        default: return Color.white.opacity(0.06)
        }
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(height: 44)
                .overlay(
                    Rectangle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )

            HStack(spacing: 12) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.08))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                timeRemaining > 10
                                    ? Color.green.opacity(0.6)
                                    : (timeRemaining > 5 ? Color.yellow.opacity(0.6) : Color.red.opacity(0.6))
                            )
                            .frame(width: geo.size.width * (timeRemaining / totalTime))
                            .animation(.linear(duration: 0.1), value: timeRemaining)
                    }
                }
                .frame(height: 8)

                // Time text
                Text(String(format: "%.0f", timeRemaining))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(
                        timeRemaining > 10 ? .white : (timeRemaining > 5 ? .yellow : .red)
                    )
                    .frame(width: 28)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Text(countdown > 0 ? "\(countdown)" : "CLAIM!")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(countdown > 0 ? .white : .green)
                .scaleEffect(countdown > 0 ? 1.0 : 1.2)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countdown)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Setup

    private func setupGrid() {
        var newTiles: [Tile] = []
        for row in 0..<gridRows {
            for col in 0..<gridCols {
                let id = row * gridCols + col
                let isBonus = Double.random(in: 0...1) < 0.12
                newTiles.append(Tile(
                    id: id,
                    row: row,
                    col: col,
                    points: isBonus ? 3 : 1
                ))
            }
        }
        tiles = newTiles
    }

    private func startCountdown() {
        showCountdown = true
        countdown = 3
        gameActive = false

        func tick() {
            guard !isPaused else { return }
            if countdown > 1 {
                SoundManager.playCountdown()
                HapticManager.impact(.medium)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    countdown -= 1
                    tick()
                }
            } else if countdown == 1 {
                SoundManager.playCountdown()
                HapticManager.impact(.medium)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    countdown = 0
                    SoundManager.playGo()
                    HapticManager.notification(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showCountdown = false
                        gameActive = true
                        startTimer()
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tick()
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            DispatchQueue.main.async {
                guard gameActive, !isPaused else { return }
                timeRemaining -= 0.1
                if timeRemaining <= 0 {
                    timeRemaining = 0
                    endGame()
                }
            }
        }
    }

    // MARK: - Game Logic

    private func claimTile(at index: Int, player: Int) {
        guard gameActive, !isPaused else { return }

        let tile = tiles[index]
        let bombMode = player == 1 ? bombModeP1 : bombModeP2

        // Can only claim tiles on your half, or steal from opponent on shared border
        let isPlayerHalf = player == 1 ? tile.row >= gridRows / 2 : tile.row < gridRows / 2
        let isBorderRow = tile.row == gridRows / 2 || tile.row == gridRows / 2 - 1
        let canClaim = isPlayerHalf || (isBorderRow && tile.owner != player)

        guard canClaim else { return }

        if bombMode {
            // Bomb: claim a 3x3 area
            useBomb(at: index, player: player)
            return
        }

        if tile.owner == player { return }
        if tile.isShielded && tile.owner != 0 && tile.owner != player { return }

        // Claim the tile
        if tile.owner != 0 && tile.owner != player {
            // Stealing from opponent
            let pts = tiles[index].points
            if tile.owner == 1 { score1 -= pts } else { score2 -= pts }
        }

        tiles[index].owner = player
        let pts = tiles[index].points
        if player == 1 { score1 += pts } else { score2 += pts }

        SoundManager.playPlace()
        HapticManager.impact(.light)

        if player == 1 {
            p1Flash = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { p1Flash = nil }
        } else {
            p2Flash = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { p2Flash = nil }
        }
    }

    private func useBomb(at centerIndex: Int, player: Int) {
        let centerTile = tiles[centerIndex]
        let row = centerTile.row
        let col = centerTile.col

        var claimedCount = 0
        for dr in -1...1 {
            for dc in -1...1 {
                let r = row + dr
                let c = col + dc
                guard r >= 0, r < gridRows, c >= 0, c < gridCols else { continue }
                let idx = r * gridCols + c

                // Can only bomb your half + border
                let isPlayerHalf = player == 1 ? r >= gridRows / 2 - 1 : r <= gridRows / 2
                guard isPlayerHalf else { continue }
                guard !tiles[idx].isShielded || tiles[idx].owner == 0 else { continue }

                if tiles[idx].owner != 0 && tiles[idx].owner != player {
                    let pts = tiles[idx].points
                    if tiles[idx].owner == 1 { score1 -= pts } else { score2 -= pts }
                }
                if tiles[idx].owner != player {
                    tiles[idx].owner = player
                    let pts = tiles[idx].points
                    if player == 1 { score1 += pts } else { score2 += pts }
                    claimedCount += 1
                }
            }
        }

        if player == 1 {
            bombAvailableP1 = false
            bombModeP1 = false
        } else {
            bombAvailableP2 = false
            bombModeP2 = false
        }

        SoundManager.playScore()
        HapticManager.notification(.success)
    }

    private func endGame() {
        gameActive = false
        timer?.invalidate()

        // Recalculate scores from tiles
        var s1 = 0
        var s2 = 0
        for tile in tiles {
            if tile.owner == 1 { s1 += tile.points }
            if tile.owner == 2 { s2 += tile.points }
        }
        score1 = s1
        score2 = s2

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if score1 > score2 {
                gameWinner = 1
            } else if score2 > score1 {
                gameWinner = 2
            } else {
                // Tie — nobody wins, show draw-ish (P1 wins on tiebreak)
                gameWinner = 1
            }
            SoundManager.playWin()
        }
    }

    private func cleanup() {
        timer?.invalidate()
        timer = nil
    }

    private func resetGame() {
        cleanup()
        score1 = 0
        score2 = 0
        timeRemaining = totalTime
        gameWinner = nil
        bombAvailableP1 = true
        bombAvailableP2 = true
        bombModeP1 = false
        bombModeP2 = false
        setupGrid()
        startCountdown()
    }
}

#Preview {
    ColorConquestView()
        .preferredColorScheme(.dark)
}
