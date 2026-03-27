import SwiftUI

// MARK: - Model

struct MancalaBoard {
    // Pits indexed 0-5 for Player 1 (bottom), 6 is P1 store,
    // 7-12 for Player 2 (top), 13 is P2 store
    var pits: [Int]

    static let pitCount = 6
    static let stonesPerPit = 4
    static let p1Store = 6
    static let p2Store = 13
    static let totalPits = 14

    init() {
        pits = Array(repeating: MancalaBoard.stonesPerPit, count: MancalaBoard.totalPits)
        pits[MancalaBoard.p1Store] = 0
        pits[MancalaBoard.p2Store] = 0
    }

    var p1Score: Int { pits[MancalaBoard.p1Store] }
    var p2Score: Int { pits[MancalaBoard.p2Store] }

    func isPlayerPit(_ index: Int, player: Int) -> Bool {
        if player == 1 { return index >= 0 && index <= 5 }
        return index >= 7 && index <= 12
    }

    func playerStore(_ player: Int) -> Int {
        player == 1 ? MancalaBoard.p1Store : MancalaBoard.p2Store
    }

    func opponentStore(_ player: Int) -> Int {
        player == 1 ? MancalaBoard.p2Store : MancalaBoard.p1Store
    }

    func oppositePit(_ index: Int) -> Int {
        12 - index
    }

    func playerSideEmpty(_ player: Int) -> Bool {
        let range = player == 1 ? 0...5 : 7...12
        return range.allSatisfy { pits[$0] == 0 }
    }

    mutating func collectRemaining() {
        for i in 0...5 {
            pits[MancalaBoard.p1Store] += pits[i]
            pits[i] = 0
        }
        for i in 7...12 {
            pits[MancalaBoard.p2Store] += pits[i]
            pits[i] = 0
        }
    }

    /// Sow stones from the given pit. Returns the index of the last pit sown into.
    mutating func sow(from pitIndex: Int, player: Int) -> Int {
        let stones = pits[pitIndex]
        pits[pitIndex] = 0
        let skipStore = opponentStore(player)

        var current = pitIndex
        var remaining = stones
        while remaining > 0 {
            current = (current + 1) % MancalaBoard.totalPits
            if current == skipStore { continue }
            pits[current] += 1
            remaining -= 1
        }
        return current
    }
}

// MARK: - View

struct MancalaView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var board = MancalaBoard()
    @State private var currentPlayer = 1
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var showResult = false
    @State private var winner: Int? = nil
    @State private var isDraw = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var lastLandedPit: Int? = nil
    @State private var animatingPit: Int? = nil
    @State private var extraTurnMessage = false
    @AppStorage("hasSeenTutorial_Mancala") private var hasSeenTutorial = false

    // Stone colors for visual variety
    private let stoneColors: [Color] = [
        Color(red: 0.85, green: 0.45, blue: 0.35),
        Color(red: 0.45, green: 0.65, blue: 0.85),
        Color(red: 0.65, green: 0.85, blue: 0.45),
        Color(red: 0.85, green: 0.75, blue: 0.35),
        Color(red: 0.75, green: 0.45, blue: 0.75),
        Color(red: 0.45, green: 0.8, blue: 0.7),
    ]

    var body: some View {
        GameTransitionView {
            ZStack {
                // Warm wooden background
                Color(red: 0.25, green: 0.15, blue: 0.08).ignoresSafeArea()

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
                    TutorialOverlayView(content: .mancala) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                // Extra turn toast
                if extraTurnMessage {
                    extraTurnToast
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(50)
                }

                if showResult {
                    if let winner {
                        WinnerOverlay(winner: winner, gameName: "Mancala") {
                            resetGame()
                        } onExit: {
                            dismiss()
                        }
                    } else if isDraw {
                        DrawOverlay(gameName: "Mancala") {
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
            updateScores()
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
                .fill(currentPlayer == 1 ? Color.blue.opacity(0.7) : Color.red.opacity(0.7))
                .frame(width: 14, height: 14)
            Text("\(PlayerProfileManager.shared.name(for: currentPlayer))'s Turn")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .transition(.opacity)
    }

    // MARK: - Extra Turn Toast

    private var extraTurnToast: some View {
        VStack {
            Spacer()
            Text("Extra turn! Go again!")
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
                                .stroke(Color.yellow.opacity(0.4), lineWidth: 1)
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
            let boardHeight = boardWidth * 0.48
            let storeWidth = boardWidth * 0.12
            let pitAreaWidth = boardWidth - storeWidth * 2
            let pitWidth = pitAreaWidth / 6
            let pitHeight = boardHeight / 2

            ZStack {
                // Board background (wooden)
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.35, blue: 0.18),
                                Color(red: 0.45, green: 0.28, blue: 0.12),
                                Color(red: 0.50, green: 0.32, blue: 0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color(red: 0.35, green: 0.22, blue: 0.1), lineWidth: 3)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 12, y: 4)

                HStack(spacing: 0) {
                    // P2 Store (left side)
                    storeView(stoneCount: board.pits[MancalaBoard.p2Store], player: 2, width: storeWidth, height: boardHeight - 16)
                        .padding(.leading, 8)

                    // Pits area
                    VStack(spacing: 4) {
                        // Player 2 pits (top row, right to left: 12, 11, 10, 9, 8, 7)
                        HStack(spacing: 2) {
                            ForEach((7...12).reversed(), id: \.self) { i in
                                pitView(index: i, width: pitWidth - 4, height: pitHeight - 10, player: 2)
                            }
                        }

                        // Player 1 pits (bottom row, left to right: 0, 1, 2, 3, 4, 5)
                        HStack(spacing: 2) {
                            ForEach(0...5, id: \.self) { i in
                                pitView(index: i, width: pitWidth - 4, height: pitHeight - 10, player: 1)
                            }
                        }
                    }
                    .frame(width: pitAreaWidth)

                    // P1 Store (right side)
                    storeView(stoneCount: board.pits[MancalaBoard.p1Store], player: 1, width: storeWidth, height: boardHeight - 16)
                        .padding(.trailing, 8)
                }
            }
            .frame(width: boardWidth, height: boardHeight)
        }
        .aspectRatio(1 / 0.48, contentMode: .fit)
    }

    // MARK: - Pit View

    private func pitView(index: Int, width: CGFloat, height: CGFloat, player: Int) -> some View {
        let stones = board.pits[index]
        let isValid = canTap(index)
        let isLastLanded = lastLandedPit == index

        return Button {
            handleTap(index)
        } label: {
            ZStack {
                // Pit oval
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.35, green: 0.22, blue: 0.1),
                                Color(red: 0.25, green: 0.15, blue: 0.07),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: width * 0.5
                        )
                    )
                    .frame(width: width, height: height)
                    .overlay(
                        Ellipse()
                            .stroke(
                                isLastLanded ? Color.yellow.opacity(0.6) :
                                isValid ? Color.white.opacity(0.3) :
                                Color(red: 0.3, green: 0.18, blue: 0.08),
                                lineWidth: isLastLanded ? 2.5 : 1.5
                            )
                    )

                // Stones visualization
                if stones > 0 {
                    stonesCluster(count: stones, width: width * 0.7, height: height * 0.6)
                }

                // Stone count
                Text("\(stones)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(y: height * 0.35)
            }
            .opacity(isValid ? 1.0 : (stones > 0 ? 0.6 : 0.4))
            .scaleEffect(animatingPit == index ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: animatingPit)
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
    }

    // MARK: - Store View

    private func storeView(stoneCount: Int, player: Int, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            // Store shape (tall oval)
            Capsule()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.32, green: 0.2, blue: 0.1),
                            Color(red: 0.22, green: 0.13, blue: 0.06),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: height * 0.3
                    )
                )
                .frame(width: width, height: height)
                .overlay(
                    Capsule()
                        .stroke(Color(red: 0.3, green: 0.18, blue: 0.08), lineWidth: 2)
                )

            VStack(spacing: 2) {
                if stoneCount > 0 {
                    stonesCluster(count: min(stoneCount, 20), width: width * 0.65, height: height * 0.5)
                }
                Text("\(stoneCount)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
    }

    // MARK: - Stones Cluster

    private func stonesCluster(count: Int, width: CGFloat, height: CGFloat) -> some View {
        let displayCount = min(count, 12)
        return ZStack {
            ForEach(0..<displayCount, id: \.self) { i in
                let angle = Double(i) * (2 * .pi / Double(max(displayCount, 1)))
                let radius = min(width, height) * 0.25 * (displayCount > 1 ? 1 : 0)
                let xOff = cos(angle) * radius * (displayCount <= 3 ? 0.6 : 1.0)
                let yOff = sin(angle) * radius * (displayCount <= 3 ? 0.6 : 1.0)
                let stoneSize = min(width, height) * (displayCount > 6 ? 0.18 : 0.22)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                stoneColors[i % stoneColors.count].opacity(0.9),
                                stoneColors[i % stoneColors.count].opacity(0.6),
                            ],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: stoneSize * 0.6
                        )
                    )
                    .frame(width: stoneSize, height: stoneSize)
                    .overlay(
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: stoneSize * 0.3, height: stoneSize * 0.3)
                            .offset(x: -stoneSize * 0.15, y: -stoneSize * 0.15)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 1, y: 1)
                    .offset(x: xOff, y: yOff)
            }
        }
    }

    // MARK: - Game Logic

    private func canTap(_ index: Int) -> Bool {
        guard !showResult, !isPaused, !showTutorial else { return false }
        guard animatingPit == nil else { return false }
        guard board.isPlayerPit(index, player: currentPlayer) else { return false }
        return board.pits[index] > 0
    }

    private func handleTap(_ pitIndex: Int) {
        guard canTap(pitIndex) else { return }

        HapticManager.impact(.medium)
        SoundManager.playPlace()

        // Animate pickup
        withAnimation(.easeInOut(duration: 0.15)) {
            animatingPit = pitIndex
        }

        // Execute sow after brief animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            animatingPit = nil

            let lastPit = board.sow(from: pitIndex, player: currentPlayer)

            withAnimation(.easeInOut(duration: 0.25)) {
                lastLandedPit = lastPit
            }

            // Check capture
            let myStore = board.playerStore(currentPlayer)
            if lastPit != myStore && board.isPlayerPit(lastPit, player: currentPlayer) && board.pits[lastPit] == 1 {
                let opposite = board.oppositePit(lastPit)
                if board.pits[opposite] > 0 {
                    // Capture!
                    let captured = board.pits[opposite] + 1 // opposite stones + the one that landed
                    board.pits[myStore] += captured
                    board.pits[lastPit] = 0
                    board.pits[opposite] = 0
                    HapticManager.impact(.heavy)
                    SoundManager.playScore()
                }
            }

            updateScores()

            // Check game end
            if board.playerSideEmpty(1) || board.playerSideEmpty(2) {
                board.collectRemaining()
                updateScores()
                endGame()
                return
            }

            // Check extra turn (last stone in own store)
            if lastPit == myStore {
                // Extra turn!
                HapticManager.notification(.success)
                showExtraTurnToast()
                // Don't switch player
            } else {
                // Switch player
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentPlayer = currentPlayer == 1 ? 2 : 1
                }
            }

            // Haptic for stone drop
            HapticManager.impact(.light)
        }
    }

    private func showExtraTurnToast() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            extraTurnMessage = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.3)) {
                extraTurnMessage = false
            }
        }
    }

    private func updateScores() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            score1 = board.p1Score
            score2 = board.p2Score
        }
    }

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

    // MARK: - Reset

    private func resetGame() {
        withAnimation {
            board = MancalaBoard()
            currentPlayer = 1
            score1 = 0
            score2 = 0
            showResult = false
            winner = nil
            isDraw = false
            lastLandedPit = nil
            animatingPit = nil
            extraTurnMessage = false
        }
        updateScores()
    }
}

#Preview {
    MancalaView()
        .preferredColorScheme(.dark)
}
