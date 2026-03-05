import Foundation

// MARK: - Grid Position

struct GridPosition: Codable, Equatable, Hashable {
    var x: Int
    var y: Int

    static let gridSize = 10

    func isValid() -> Bool {
        x >= 0 && x < Self.gridSize && y >= 0 && y < Self.gridSize
    }

    func distance(to other: GridPosition) -> Int {
        max(abs(x - other.x), abs(y - other.y))
    }

    func moved(in direction: Direction) -> GridPosition {
        switch direction {
        case .up: return GridPosition(x: x, y: y - 1)
        case .down: return GridPosition(x: x, y: y + 1)
        case .left: return GridPosition(x: x - 1, y: y)
        case .right: return GridPosition(x: x + 1, y: y)
        }
    }
}

// MARK: - Direction

enum Direction: String, Codable, CaseIterable {
    case up, down, left, right

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        default: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        default: return 0
        }
    }
}

// MARK: - Player Action

enum PlayerAction: Codable, Equatable {
    case move(Direction)
    case ping
    case fireTorpedo(Direction)
    case dropMine
    case none
}

// MARK: - Torpedo

struct Torpedo: Codable, Equatable, Identifiable {
    let id: UUID
    var position: GridPosition
    let direction: Direction
    let owner: PlayerRole

    init(position: GridPosition, direction: Direction, owner: PlayerRole) {
        self.id = UUID()
        self.position = position
        self.direction = direction
        self.owner = owner
    }
}

// MARK: - Mine

struct Mine: Codable, Equatable, Identifiable {
    let id: UUID
    let position: GridPosition
    let owner: PlayerRole

    init(position: GridPosition, owner: PlayerRole) {
        self.id = UUID()
        self.position = position
        self.owner = owner
    }
}

// MARK: - Player Role

enum PlayerRole: String, Codable {
    case host
    case guest
}

// MARK: - Player State

struct PlayerState: Codable {
    var position: GridPosition
    var hp: Int = 3
    var role: PlayerRole
    var pingActive: Bool = false
    var pingTurnsRemaining: Int = 0
    var minesPlaced: Int = 0
    var maxMines: Int = 3

    var isAlive: Bool { hp > 0 }

    var visibleTiles: Set<GridPosition> {
        var tiles = Set<GridPosition>()
        for dx in -1...1 {
            for dy in -1...1 {
                let pos = GridPosition(x: position.x + dx, y: position.y + dy)
                if pos.isValid() {
                    tiles.insert(pos)
                }
            }
        }
        return tiles
    }

    var sonarTiles: Set<GridPosition> {
        var tiles = Set<GridPosition>()
        for dx in -2...2 {
            for dy in -2...2 {
                let pos = GridPosition(x: position.x + dx, y: position.y + dy)
                if pos.isValid() {
                    tiles.insert(pos)
                }
            }
        }
        return tiles
    }
}

// MARK: - Game Phase

enum GamePhase: Codable, Equatable {
    case waitingForActions
    case resolving
    case gameOver(winner: PlayerRole)
}

// MARK: - Game State

struct GameState: Codable {
    var hostPlayer: PlayerState
    var guestPlayer: PlayerState
    var torpedoes: [Torpedo] = []
    var mines: [Mine] = []
    var turnNumber: Int = 1
    var phase: GamePhase = .waitingForActions
    var hostAction: PlayerAction?
    var guestAction: PlayerAction?
    var events: [GameEvent] = []

    static func newGame() -> GameState {
        let host = PlayerState(
            position: GridPosition(x: Int.random(in: 0...3), y: Int.random(in: 0...3)),
            role: .host
        )
        let guest = PlayerState(
            position: GridPosition(x: Int.random(in: 6...9), y: Int.random(in: 6...9)),
            role: .guest
        )
        return GameState(hostPlayer: host, guestPlayer: guest)
    }

    mutating func submitAction(_ action: PlayerAction, for role: PlayerRole) {
        switch role {
        case .host: hostAction = action
        case .guest: guestAction = action
        }
    }

    var bothActionsSubmitted: Bool {
        hostAction != nil && guestAction != nil
    }

    mutating func resolveTurn() {
        events.removeAll()
        phase = .resolving

        // 1. Process moves
        resolveMove(for: .host)
        resolveMove(for: .guest)

        // 2. Process pings
        resolvePing(for: .host)
        resolvePing(for: .guest)

        // 3. Process mine drops
        resolveMineDrop(for: .host)
        resolveMineDrop(for: .guest)

        // 4. Process torpedo fires
        resolveTorpedoFire(for: .host)
        resolveTorpedoFire(for: .guest)

        // 5. Advance existing torpedoes
        advanceTorpedoes()

        // 6. Check mine proximity
        checkMineProximity()

        // 7. Decrease ping timers
        if hostPlayer.pingTurnsRemaining > 0 {
            hostPlayer.pingTurnsRemaining -= 1
            if hostPlayer.pingTurnsRemaining == 0 {
                hostPlayer.pingActive = false
            }
        }
        if guestPlayer.pingTurnsRemaining > 0 {
            guestPlayer.pingTurnsRemaining -= 1
            if guestPlayer.pingTurnsRemaining == 0 {
                guestPlayer.pingActive = false
            }
        }

        // 8. Check win conditions
        if !hostPlayer.isAlive && !guestPlayer.isAlive {
            phase = .gameOver(winner: .host) // Mutual destruction: host wins tiebreak
        } else if !hostPlayer.isAlive {
            phase = .gameOver(winner: .guest)
        } else if !guestPlayer.isAlive {
            phase = .gameOver(winner: .host)
        } else {
            phase = .waitingForActions
        }

        // Reset actions
        hostAction = nil
        guestAction = nil
        turnNumber += 1
    }

    private mutating func resolveMove(for role: PlayerRole) {
        let action = role == .host ? hostAction : guestAction
        guard case .move(let dir) = action else { return }

        let currentPos = role == .host ? hostPlayer.position : guestPlayer.position
        let newPos = currentPos.moved(in: dir)

        if newPos.isValid() {
            if role == .host {
                hostPlayer.position = newPos
            } else {
                guestPlayer.position = newPos
            }
            events.append(.moved(role: role, to: newPos))
        }
    }

    private mutating func resolvePing(for role: PlayerRole) {
        let action = role == .host ? hostAction : guestAction
        guard case .ping = action else { return }

        if role == .host {
            hostPlayer.pingActive = true
            hostPlayer.pingTurnsRemaining = 2
        } else {
            guestPlayer.pingActive = true
            guestPlayer.pingTurnsRemaining = 2
        }
        let pos = role == .host ? hostPlayer.position : guestPlayer.position
        events.append(.pinged(role: role, at: pos))
    }

    private mutating func resolveMineDrop(for role: PlayerRole) {
        let action = role == .host ? hostAction : guestAction
        guard case .dropMine = action else { return }

        let player = role == .host ? hostPlayer : guestPlayer
        guard player.minesPlaced < player.maxMines else { return }

        let mine = Mine(position: player.position, owner: role)
        mines.append(mine)
        if role == .host {
            hostPlayer.minesPlaced += 1
        } else {
            guestPlayer.minesPlaced += 1
        }
        events.append(.minePlaced(role: role, at: player.position))
    }

    private mutating func resolveTorpedoFire(for role: PlayerRole) {
        let action = role == .host ? hostAction : guestAction
        guard case .fireTorpedo(let dir) = action else { return }

        let player = role == .host ? hostPlayer : guestPlayer
        let startPos = player.position.moved(in: dir)
        if startPos.isValid() {
            let torpedo = Torpedo(position: startPos, direction: dir, owner: role)
            torpedoes.append(torpedo)
            events.append(.torpedoFired(role: role, direction: dir))
        }
    }

    private mutating func advanceTorpedoes() {
        var toRemove = Set<UUID>()

        for i in torpedoes.indices {
            // Move torpedo 2 cells per turn
            for _ in 0..<2 {
                if toRemove.contains(torpedoes[i].id) { break }

                let nextPos = torpedoes[i].position.moved(in: torpedoes[i].direction)
                if !nextPos.isValid() {
                    toRemove.insert(torpedoes[i].id)
                    break
                }
                torpedoes[i].position = nextPos

                // Check hit on players
                if torpedoes[i].owner != .host && nextPos == hostPlayer.position {
                    hostPlayer.hp -= 2
                    events.append(.torpedoHit(target: .host, at: nextPos))
                    toRemove.insert(torpedoes[i].id)
                }
                if torpedoes[i].owner != .guest && nextPos == guestPlayer.position {
                    guestPlayer.hp -= 2
                    events.append(.torpedoHit(target: .guest, at: nextPos))
                    toRemove.insert(torpedoes[i].id)
                }
            }
        }

        torpedoes.removeAll { toRemove.contains($0.id) }
    }

    private mutating func checkMineProximity() {
        var toRemove = Set<UUID>()

        for mine in mines {
            // Check if enemy is adjacent (distance 1)
            if mine.owner != .host && mine.position.distance(to: hostPlayer.position) <= 1 {
                hostPlayer.hp -= 1
                events.append(.mineDetonated(at: mine.position, target: .host))
                toRemove.insert(mine.id)
            }
            if mine.owner != .guest && mine.position.distance(to: guestPlayer.position) <= 1 {
                guestPlayer.hp -= 1
                events.append(.mineDetonated(at: mine.position, target: .guest))
                toRemove.insert(mine.id)
            }
        }

        mines.removeAll { toRemove.contains($0.id) }
    }
}

// MARK: - Game Event

enum GameEvent: Codable {
    case moved(role: PlayerRole, to: GridPosition)
    case pinged(role: PlayerRole, at: GridPosition)
    case torpedoFired(role: PlayerRole, direction: Direction)
    case torpedoHit(target: PlayerRole, at: GridPosition)
    case minePlaced(role: PlayerRole, at: GridPosition)
    case mineDetonated(at: GridPosition, target: PlayerRole)
}

// MARK: - Network Message

enum NetworkMessage: Codable {
    case gameStart(state: GameState)
    case action(PlayerAction, from: PlayerRole)
    case stateSync(GameState)
    case rematch
    case disconnect
}
