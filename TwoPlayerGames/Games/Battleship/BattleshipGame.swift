import SwiftUI

// MARK: - Models

struct Ship: Identifiable, Equatable {
    let id: String
    let name: String
    let size: Int
    var row: Int = 0
    var col: Int = 0
    var isHorizontal: Bool = true
    var isPlaced: Bool = false
    var hitCells: Set<Int> = [] // indices 0..<size that have been hit

    var isSunk: Bool { hitCells.count == size }

    func cells() -> [(Int, Int)] {
        (0..<size).map { i in
            isHorizontal ? (row, col + i) : (row + i, col)
        }
    }

    static func fleet() -> [Ship] {
        [
            Ship(id: "carrier", name: "Carrier", size: 5),
            Ship(id: "battleship", name: "Battleship", size: 4),
            Ship(id: "cruiser", name: "Cruiser", size: 3),
            Ship(id: "submarine", name: "Submarine", size: 3),
            Ship(id: "destroyer", name: "Destroyer", size: 2),
        ]
    }
}

enum CellState {
    case empty, ship, hit, miss
}

struct PlayerBoard {
    var ships: [Ship] = Ship.fleet()
    var shots: [[CellState]] = Array(repeating: Array(repeating: CellState.empty, count: 10), count: 10) // shots received

    func cellAt(_ r: Int, _ c: Int) -> CellState {
        shots[r][c]
    }

    func hasShipAt(_ r: Int, _ c: Int) -> Bool {
        ships.filter(\.isPlaced).flatMap { $0.cells() }.contains(where: { $0.0 == r && $0.1 == c })
    }

    func allSunk() -> Bool {
        ships.allSatisfy(\.isSunk)
    }

    func shipAt(_ r: Int, _ c: Int) -> Ship? {
        ships.first { ship in
            ship.isPlaced && ship.cells().contains(where: { $0.0 == r && $0.1 == c })
        }
    }

    mutating func fire(at r: Int, _ c: Int) -> (hit: Bool, sunkShip: Ship?) {
        if hasShipAt(r, c) {
            shots[r][c] = .hit
            // Mark the hit on the ship
            if let idx = ships.firstIndex(where: { $0.isPlaced && $0.cells().contains(where: { $0.0 == r && $0.1 == c }) }) {
                let cellIdx = ships[idx].cells().firstIndex(where: { $0.0 == r && $0.1 == c })!
                ships[idx].hitCells.insert(cellIdx)
                if ships[idx].isSunk {
                    return (true, ships[idx])
                }
            }
            return (true, nil)
        } else {
            shots[r][c] = .miss
            return (false, nil)
        }
    }

    func isValidPlacement(_ ship: Ship) -> Bool {
        let cells = ship.cells()
        // Check bounds
        for (r, c) in cells {
            if r < 0 || r >= 10 || c < 0 || c >= 10 { return false }
        }
        // Check overlap with other placed ships
        for other in ships where other.isPlaced && other.id != ship.id {
            for (or, oc) in other.cells() {
                if cells.contains(where: { $0.0 == or && $0.1 == oc }) { return false }
            }
        }
        return true
    }
}

// MARK: - Game Phases

enum BattleshipPhase: Equatable {
    case placing(player: Int)
    case passDevice(nextPlayer: Int, message: String)
    case battle(player: Int) // whose turn to fire
    case gameOver(winner: Int)
}

// MARK: - Main View

struct BattleshipView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var boards: [PlayerBoard] = [PlayerBoard(), PlayerBoard()]
    @State private var phase: BattleshipPhase = .placing(player: 1)
    @State private var selectedShipIndex: Int? = nil
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var lastHitCell: (Int, Int)? = nil
    @State private var lastMissCell: (Int, Int)? = nil
    @State private var sunkAnnouncement: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var showShotResult = false
    @State private var shotWasHit = false
    @AppStorage("hasSeenTutorial_Battleship") private var hasSeenTutorial = false

    private let gridSize = 10
    private let columnLabels = ["A","B","C","D","E","F","G","H","I","J"]

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                switch phase {
                case .placing(let player):
                    placementView(player: player)
                case .passDevice(let nextPlayer, let message):
                    passDeviceView(nextPlayer: nextPlayer, message: message)
                case .battle(let player):
                    battleView(currentPlayer: player)
                        .offset(x: shakeOffset)
                case .gameOver(let winner):
                    gameOverView(winner: winner)
                }

                if !isPaused && !showTutorial && !phase.isGameOver {
                    GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })
                }

                if !showTutorial && !isPaused && !phase.isGameOver {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .battleship) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if isPaused && !phase.isGameOver {
                    PauseOverlay(
                        score1: boards[0].ships.filter(\.isSunk).count,
                        score2: boards[1].ships.filter(\.isSunk).count,
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !phase.isGameOver {
                isPaused = true
            }
        }
    }

    // MARK: - Placement View

    private func placementView(player: Int) -> some View {
        let boardIndex = player - 1
        return VStack(spacing: 0) {
            // Header
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(player == 1 ? Color.blue : Color.red)
                        .frame(width: 12, height: 12)
                        .shadow(color: (player == 1 ? Color.blue : Color.red).opacity(0.5), radius: 4)
                    Text("Player \(player) — Place Your Ships")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text("Tap ship, tap grid to place. Tap placed ship to rotate.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.top, 60)
            .padding(.bottom, 12)

            // Grid
            placementGrid(boardIndex: boardIndex)
                .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            // Ship selector
            shipSelector(boardIndex: boardIndex)

            Spacer()

            // Ready button
            if boards[boardIndex].ships.allSatisfy(\.isPlaced) {
                Button {
                    HapticManager.impact(.medium)
                    SoundManager.playButtonTap()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if player == 1 {
                            phase = .passDevice(nextPlayer: 2, message: "Pass the device to Player 2")
                        } else {
                            phase = .passDevice(nextPlayer: 1, message: "Pass to Player 1 to fire first")
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("Ready!")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.8))
                            .shadow(color: .green.opacity(0.3), radius: 8, y: 4)
                    )
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private func placementGrid(boardIndex: Int) -> some View {
        let cellSize: CGFloat = (UIScreen.main.bounds.width - 32 - 20) / CGFloat(gridSize + 1) // +1 for labels

        return VStack(spacing: 1) {
            // Column headers
            HStack(spacing: 1) {
                Text("")
                    .frame(width: cellSize, height: cellSize * 0.6)
                ForEach(0..<gridSize, id: \.self) { c in
                    Text(columnLabels[c])
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: cellSize, height: cellSize * 0.6)
                }
            }

            ForEach(0..<gridSize, id: \.self) { r in
                HStack(spacing: 1) {
                    // Row label
                    Text("\(r + 1)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .frame(width: cellSize, height: cellSize)

                    ForEach(0..<gridSize, id: \.self) { c in
                        placementCell(r: r, c: c, boardIndex: boardIndex, size: cellSize)
                    }
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.04, green: 0.1, blue: 0.2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.15), lineWidth: 1)
        )
    }

    private func placementCell(r: Int, c: Int, boardIndex: Int, size: CGFloat) -> some View {
        let hasShip = boards[boardIndex].hasShipAt(r, c)
        let isSelected = selectedShipIndex != nil && {
            let ship = boards[boardIndex].ships[selectedShipIndex!]
            if ship.isPlaced { return false }
            // Preview placement
            var preview = ship
            preview.row = r
            preview.col = c
            return boards[boardIndex].isValidPlacement(preview) &&
                   preview.cells().contains(where: { $0.0 == r && $0.1 == c })
        }()

        return Button {
            handlePlacementTap(r: r, c: c, boardIndex: boardIndex)
        } label: {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    hasShip
                        ? Color(red: 0.25, green: 0.35, blue: 0.5)
                        : Color(red: 0.06, green: 0.15, blue: 0.28)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(
                            hasShip
                                ? Color.cyan.opacity(0.3)
                                : Color.white.opacity(0.06),
                            lineWidth: 0.5
                        )
                )
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
    }

    private func handlePlacementTap(r: Int, c: Int, boardIndex: Int) {
        // If tapping on an existing ship, rotate it
        if let shipIdx = boards[boardIndex].ships.firstIndex(where: {
            $0.isPlaced && $0.cells().contains(where: { $0.0 == r && $0.1 == c })
        }) {
            var rotated = boards[boardIndex].ships[shipIdx]
            rotated.isHorizontal.toggle()
            if boards[boardIndex].isValidPlacement(rotated) {
                HapticManager.impact(.light)
                withAnimation(.easeOut(duration: 0.2)) {
                    boards[boardIndex].ships[shipIdx].isHorizontal.toggle()
                }
            } else {
                HapticManager.notification(.warning)
            }
            return
        }

        // If a ship is selected, place it
        guard let idx = selectedShipIndex, !boards[boardIndex].ships[idx].isPlaced else { return }
        var ship = boards[boardIndex].ships[idx]
        ship.row = r
        ship.col = c
        ship.isPlaced = true
        if boards[boardIndex].isValidPlacement(ship) {
            HapticManager.impact(.medium)
            SoundManager.playPlace()
            withAnimation(.easeOut(duration: 0.2)) {
                boards[boardIndex].ships[idx] = ship
            }
            // Auto-select next unplaced ship
            selectedShipIndex = boards[boardIndex].ships.firstIndex(where: { !$0.isPlaced })
        } else {
            HapticManager.notification(.warning)
        }
    }

    private func shipSelector(boardIndex: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(boards[boardIndex].ships.enumerated()), id: \.element.id) { idx, ship in
                    Button {
                        if !ship.isPlaced {
                            HapticManager.impact(.light)
                            selectedShipIndex = idx
                        }
                    } label: {
                        VStack(spacing: 4) {
                            // Ship visual
                            HStack(spacing: 2) {
                                ForEach(0..<ship.size, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(ship.isPlaced ? Color.gray.opacity(0.3) : Color(red: 0.3, green: 0.45, blue: 0.65))
                                        .frame(width: 14, height: 14)
                                }
                            }
                            Text(ship.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ship.isPlaced ? .white.opacity(0.3) : .white.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    selectedShipIndex == idx && !ship.isPlaced
                                        ? Color.cyan.opacity(0.15)
                                        : Color.white.opacity(0.05)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    selectedShipIndex == idx && !ship.isPlaced
                                        ? Color.cyan.opacity(0.4)
                                        : Color.clear,
                                    lineWidth: 1.5
                                )
                        )
                        .opacity(ship.isPlaced ? 0.5 : 1)
                    }
                    .disabled(ship.isPlaced)
                }
            }
            .padding(.horizontal, 16)
        }
        .onAppear {
            selectedShipIndex = boards[boardIndex].ships.firstIndex(where: { !$0.isPlaced })
        }
    }

    // MARK: - Pass Device View

    private func passDeviceView(nextPlayer: Int, message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.cyan.opacity(0.7), .blue.opacity(0.5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(message)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("Tap anywhere to continue")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.impact(.light)
            withAnimation(.easeInOut(duration: 0.3)) {
                if case .passDevice(let nextPlayer, _) = phase {
                    if nextPlayer == 2 && !boards[1].ships.allSatisfy(\.isPlaced) {
                        // P2 needs to place ships
                        phase = .placing(player: 2)
                        selectedShipIndex = nil
                    } else {
                        // Start battle
                        phase = .battle(player: nextPlayer)
                    }
                }
            }
        }
    }

    // MARK: - Battle View

    private func battleView(currentPlayer: Int) -> some View {
        let myBoardIndex = currentPlayer - 1
        let opponentBoardIndex = currentPlayer == 1 ? 1 : 0

        return VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Circle()
                    .fill(currentPlayer == 1 ? Color.blue : Color.red)
                    .frame(width: 12, height: 12)
                    .shadow(color: (currentPlayer == 1 ? Color.blue : Color.red).opacity(0.5), radius: 4)
                Text("Player \(currentPlayer)'s Turn")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 56)
            .padding(.bottom, 8)

            // Ships remaining
            HStack(spacing: 16) {
                shipStatus(label: "Your Fleet", ships: boards[myBoardIndex].ships, color: .cyan)
                Spacer()
                shipStatus(label: "Enemy Fleet", ships: boards[opponentBoardIndex].ships, color: .red)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // Your board (top) — shows your ships + where opponent hit
            VStack(spacing: 2) {
                Text("YOUR WATERS")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .tracking(1.5)
                battleGrid(boardIndex: myBoardIndex, isOwnBoard: true)
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 10)

            // Sunk announcement
            if let announcement = sunkAnnouncement {
                Text(announcement)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .transition(.scale.combined(with: .opacity))
                    .padding(.vertical, 4)
            }

            // Opponent's board (bottom) — fire here
            VStack(spacing: 2) {
                Text("ENEMY WATERS — TAP TO FIRE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.red.opacity(0.5))
                    .tracking(1.5)
                battleGrid(boardIndex: opponentBoardIndex, isOwnBoard: false)
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func shipStatus(label: String, ships: [Ship], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color.opacity(0.6))
                .tracking(1)
            HStack(spacing: 4) {
                ForEach(ships) { ship in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ship.isSunk ? Color.red.opacity(0.3) : color.opacity(0.5))
                        .frame(width: CGFloat(ship.size) * 6, height: 8)
                        .overlay(
                            ship.isSunk ?
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color.red.opacity(0.5), lineWidth: 0.5) : nil
                        )
                }
            }
        }
    }

    private func battleGrid(boardIndex: Int, isOwnBoard: Bool) -> some View {
        let cellSize: CGFloat = (UIScreen.main.bounds.width - 32 - 20) / CGFloat(gridSize + 1)
        let smallCellSize = cellSize * 0.85 // slightly smaller for battle grids

        return VStack(spacing: 1) {
            // Column headers
            HStack(spacing: 1) {
                Text("")
                    .frame(width: smallCellSize, height: smallCellSize * 0.5)
                ForEach(0..<gridSize, id: \.self) { c in
                    Text(columnLabels[c])
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(width: smallCellSize, height: smallCellSize * 0.5)
                }
            }

            ForEach(0..<gridSize, id: \.self) { r in
                HStack(spacing: 1) {
                    Text("\(r + 1)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.25))
                        .frame(width: smallCellSize, height: smallCellSize)

                    ForEach(0..<gridSize, id: \.self) { c in
                        battleCell(r: r, c: c, boardIndex: boardIndex, isOwnBoard: isOwnBoard, size: smallCellSize)
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.04, green: 0.08, blue: 0.18))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isOwnBoard ? Color.cyan.opacity(0.1) : Color.red.opacity(0.15),
                    lineWidth: 1
                )
        )
    }

    private func battleCell(r: Int, c: Int, boardIndex: Int, isOwnBoard: Bool, size: CGFloat) -> some View {
        let state = boards[boardIndex].cellAt(r, c)
        let hasShip = boards[boardIndex].hasShipAt(r, c)
        let shipSunk = boards[boardIndex].shipAt(r, c)?.isSunk ?? false
        let isLastHit = lastHitCell?.0 == r && lastHitCell?.1 == c
        let isLastMiss = lastMissCell?.0 == r && lastMissCell?.1 == c

        return Button {
            if !isOwnBoard {
                fireShot(r: r, c: c, boardIndex: boardIndex)
            }
        } label: {
            ZStack {
                // Base cell
                RoundedRectangle(cornerRadius: 2)
                    .fill(cellColor(state: state, hasShip: hasShip, isOwnBoard: isOwnBoard, shipSunk: shipSunk))
                    .frame(width: size, height: size)

                // Ship indicator (own board only)
                if isOwnBoard && hasShip && state != .hit {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color(red: 0.2, green: 0.3, blue: 0.45).opacity(0.8))
                        .frame(width: size * 0.7, height: size * 0.7)
                }

                // Hit marker
                if state == .hit {
                    Circle()
                        .fill(Color.red)
                        .frame(width: size * 0.55, height: size * 0.55)
                        .shadow(color: .red.opacity(isLastHit ? 0.8 : 0.4), radius: isLastHit ? 6 : 2)
                        .scaleEffect(isLastHit && showShotResult ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showShotResult)

                    // X mark on hit
                    Image(systemName: "xmark")
                        .font(.system(size: size * 0.3, weight: .heavy))
                        .foregroundStyle(.white.opacity(0.9))
                }

                // Miss marker
                if state == .miss {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: size * 0.35, height: size * 0.35)
                        .scaleEffect(isLastMiss && showShotResult ? 1.4 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showShotResult)
                }

                // Sunk ship overlay
                if shipSunk && state == .hit {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.orange.opacity(0.6), lineWidth: 1.5)
                        .frame(width: size, height: size)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isOwnBoard || state != .empty || isPaused)
    }

    private func cellColor(state: CellState, hasShip: Bool, isOwnBoard: Bool, shipSunk: Bool) -> Color {
        switch state {
        case .hit:
            return shipSunk ? Color(red: 0.3, green: 0.08, blue: 0.05) : Color(red: 0.2, green: 0.06, blue: 0.04)
        case .miss:
            return Color(red: 0.06, green: 0.1, blue: 0.2)
        default:
            return Color(red: 0.06, green: 0.14, blue: 0.26)
        }
    }

    private func fireShot(r: Int, c: Int, boardIndex: Int) {
        guard case .battle(let currentPlayer) = phase else { return }
        guard boards[boardIndex].cellAt(r, c) == .empty else { return }

        let result = boards[boardIndex].fire(at: r, c)

        if result.hit {
            lastHitCell = (r, c)
            lastMissCell = nil
            shotWasHit = true
            HapticManager.notification(.success)
            SoundManager.playHit()

            // Screen shake
            withAnimation(.default) {
                shakeOffset = 6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.default) { shakeOffset = -5 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.default) { shakeOffset = 3 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.default) { shakeOffset = 0 }
            }

            if let sunk = result.sunkShip {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    sunkAnnouncement = "\(sunk.name) sunk!"
                }
                HapticManager.impact(.heavy)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { sunkAnnouncement = nil }
                }
            }
        } else {
            lastMissCell = (r, c)
            lastHitCell = nil
            shotWasHit = false
            HapticManager.impact(.light)
            SoundManager.playDrop()
        }

        showShotResult = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            showShotResult = false
        }

        // Check win
        if boards[boardIndex].allSunk() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.easeInOut(duration: 0.4)) {
                    phase = .gameOver(winner: currentPlayer)
                }
            }
            return
        }

        // Switch turns after delay
        let nextPlayer = currentPlayer == 1 ? 2 : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeInOut(duration: 0.3)) {
                phase = .passDevice(nextPlayer: nextPlayer, message: "Pass to Player \(nextPlayer)")
            }
        }
    }

    // MARK: - Game Over

    private func gameOverView(winner: Int) -> some View {
        WinnerOverlay(winner: winner, gameType: .battleship, gameName: "Battleship") {
            resetGame()
        } onExit: {
            dismiss()
        }
    }

    private func resetGame() {
        withAnimation {
            boards = [PlayerBoard(), PlayerBoard()]
            phase = .placing(player: 1)
            selectedShipIndex = nil
            lastHitCell = nil
            lastMissCell = nil
            sunkAnnouncement = nil
            shakeOffset = 0
            showShotResult = false
        }
    }
}

// MARK: - Phase Helpers

extension BattleshipPhase {
    var isGameOver: Bool {
        if case .gameOver = self { return true }
        return false
    }
}

#Preview {
    BattleshipView()
        .preferredColorScheme(.dark)
}
