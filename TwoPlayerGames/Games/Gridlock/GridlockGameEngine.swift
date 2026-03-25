import SwiftUI
import Combine

class GridlockGameEngine: ObservableObject {
    // MARK: - Published State
    @Published var cells: [HexCoord: HexCell] = [:]
    @Published var buildings: [Building] = []
    @Published var units: [GameUnit] = []
    @Published var playerStates: [Int: PlayerState] = [1: PlayerState(), 2: PlayerState()]
    @Published var phase: GridlockPhase = .setup
    @Published var currentPlayer: Int = 1
    @Published var tickCount: Int = 0
    @Published var gameTimeRemaining: TimeInterval = 600 // 10 minutes
    @Published var combatLog: [String] = []

    private var tickTimer: Timer?
    private var gameTimer: Timer?
    private let tickInterval: TimeInterval = 5.0 // seconds between ticks

    // MARK: - Initialization

    func startNewGame() {
        let map = GridlockMapGenerator.generate()
        cells = map.cells
        buildings = []
        units = []
        playerStates = [1: PlayerState(), 2: PlayerState()]
        tickCount = 0
        gameTimeRemaining = 600
        combatLog = []

        // Place HQs
        let hq1 = Building(type: .hq, owner: 1, position: map.p1Start)
        let hq2 = Building(type: .hq, owner: 2, position: map.p2Start)
        buildings.append(hq1)
        buildings.append(hq2)

        phase = .playerTurn(1)
        currentPlayer = 1
        startTimers()
    }

    // MARK: - Visibility

    func visibleHexes(for player: Int) -> Set<HexCoord> {
        var visible = Set<HexCoord>()

        for building in buildings where building.owner == player {
            let range = building.type.visionRange
            addHexesInRange(center: building.position, range: range, to: &visible)
        }

        for unit in units where unit.owner == player {
            let range = unit.type.visionRange
            addHexesInRange(center: unit.position, range: range, to: &visible)
        }

        return visible
    }

    private func addHexesInRange(center: HexCoord, range: Int, to set: inout Set<HexCoord>) {
        for q in -range...range {
            let r1 = max(-range, -q - range)
            let r2 = min(range, -q + range)
            for r in r1...r2 {
                let coord = HexCoord(q: center.q + q, r: center.r + r)
                if cells[coord] != nil {
                    set.insert(coord)
                }
            }
        }
    }

    // MARK: - AP Management

    func currentAP() -> Int {
        playerStates[currentPlayer]?.ap ?? 0
    }

    func spendAP(_ amount: Int) -> Bool {
        guard var state = playerStates[currentPlayer], state.ap >= amount else { return false }
        state.ap -= amount
        playerStates[currentPlayer] = state
        return true
    }

    func currentResources() -> Resources {
        playerStates[currentPlayer]?.resources ?? .zero
    }

    // MARK: - Building Placement

    func canPlaceBuilding(_ type: BuildingType, at coord: HexCoord) -> Bool {
        guard cells[coord] != nil else { return false }
        guard building(at: coord) == nil else { return false }
        guard units(at: coord).filter({ $0.owner != currentPlayer }).isEmpty else { return false }

        let state = playerStates[currentPlayer]!
        guard state.ap >= type.apCost else { return false }
        guard state.resources.canAfford(type.resourceCost) else { return false }

        if type.requiresResourceNode {
            guard cells[coord]?.resourceType != nil else { return false }
        }

        // Must be within range of existing building
        let ownBuildings = buildings.filter { $0.owner == currentPlayer }
        let inRange = ownBuildings.contains { coord.distance(to: $0.position) <= $0.type.visionRange }
        return inRange
    }

    func placeBuilding(_ type: BuildingType, at coord: HexCoord) -> Bool {
        guard canPlaceBuilding(type, at: coord) else { return false }
        guard spendAP(type.apCost) else { return false }

        playerStates[currentPlayer]?.resources.subtract(type.resourceCost)
        let building = Building(type: type, owner: currentPlayer, position: coord)
        buildings.append(building)
        HapticManager.impact(.medium)
        SoundManager.playPlace()
        return true
    }

    // MARK: - Unit Deployment

    func canDeployUnit(_ type: UnitType) -> Bool {
        let state = playerStates[currentPlayer]!
        guard state.ap >= 1 else { return false }
        guard state.resources.canAfford(type.resourceCost) else { return false }
        // Need a factory
        return buildings.contains { $0.type == .factory && $0.owner == currentPlayer }
    }

    func deployUnit(_ type: UnitType, at coord: HexCoord) -> Bool {
        // Must be adjacent to own factory
        let factories = buildings.filter { $0.type == .factory && $0.owner == currentPlayer }
        guard factories.contains(where: { coord.distance(to: $0.position) <= 1 }) else { return false }
        guard cells[coord] != nil else { return false }
        guard building(at: coord) == nil else { return false }
        guard spendAP(1) else { return false }

        playerStates[currentPlayer]?.resources.subtract(type.resourceCost)
        let unit = GameUnit(type: type, owner: currentPlayer, position: coord)
        units.append(unit)
        HapticManager.impact(.light)
        return true
    }

    func assignTarget(unitId: UUID, target: HexCoord) {
        if let idx = units.firstIndex(where: { $0.id == unitId }) {
            units[idx].targetHex = target
        }
    }

    // MARK: - Turn Management

    func endTurn() {
        processTick()
        let nextPlayer = currentPlayer == 1 ? 2 : 1
        phase = .transition(nextPlayer)
        HapticManager.impact(.medium)
    }

    func startNextPlayerTurn() {
        currentPlayer = currentPlayer == 1 ? 2 : 1
        phase = .playerTurn(currentPlayer)
    }

    // MARK: - Tick Processing

    func processTick() {
        tickCount += 1

        // Resource production
        for building in buildings {
            switch building.type {
            case .hq:
                playerStates[building.owner]?.resources.iron += 1
            case .extractor:
                if let cell = cells[building.position], let resType = cell.resourceType, cell.resourceAmount > 0 {
                    cells[building.position]?.resourceAmount -= 1
                    switch resType {
                    case .iron: playerStates[building.owner]?.resources.iron += 2
                    case .crystal: playerStates[building.owner]?.resources.crystal += 2
                    case .fuel: playerStates[building.owner]?.resources.fuel += 2
                    case .data: playerStates[building.owner]?.resources.data += 2
                    }
                }
            default: break
            }
        }

        // Unit movement
        moveUnits()

        // Combat resolution
        resolveCombat()

        // Turret attacks
        processTurrets()

        // AP regen
        for player in [1, 2] {
            if var state = playerStates[player] {
                let regen: Int
                if gameTimeRemaining > 480 { regen = 2 } // opening boost
                else if gameTimeRemaining < 120 { regen = 2 } // endgame boost
                else { regen = 1 }
                state.ap = min(state.maxAP, state.ap + regen)
                playerStates[player] = state
            }
        }

        // Run automations
        for player in [1, 2] {
            runAutomations(for: player)
        }

        // Check win conditions
        checkWinConditions()
    }

    // MARK: - Unit Movement

    private func moveUnits() {
        for i in units.indices {
            guard let target = units[i].targetHex else { continue }
            if units[i].position == target {
                units[i].targetHex = nil
                continue
            }

            let speed = units[i].type.speed
            var current = units[i].position

            for _ in 0..<speed {
                if current == target { break }
                let neighbors = current.neighbors().filter { cells[$0] != nil }
                if let next = neighbors.min(by: { $0.distance(to: target) < $1.distance(to: target) }) {
                    if next.distance(to: target) < current.distance(to: target) {
                        current = next
                    } else {
                        break
                    }
                }
            }
            units[i].position = current
        }
    }

    // MARK: - Combat

    private func resolveCombat() {
        // Group units by position
        var positionMap: [HexCoord: [Int]] = [:] // coord -> unit indices
        for (i, unit) in units.enumerated() {
            positionMap[unit.position, default: []].append(i)
        }

        var toRemove = Set<UUID>()

        for (_, indices) in positionMap {
            let p1Units = indices.filter { units[$0].owner == 1 }
            let p2Units = indices.filter { units[$0].owner == 2 }

            guard !p1Units.isEmpty && !p2Units.isEmpty else { continue }

            // Each unit attacks a random enemy
            for idx in p1Units {
                if let target = p2Units.randomElement() {
                    units[target].hp -= units[idx].type.attack
                    if units[target].hp <= 0 { toRemove.insert(units[target].id) }
                }
            }
            for idx in p2Units {
                if let target = p1Units.randomElement() {
                    units[target].hp -= units[idx].type.attack
                    if units[target].hp <= 0 { toRemove.insert(units[target].id) }
                }
            }
        }

        // Units attack buildings at their position
        for unit in units where !toRemove.contains(unit.id) {
            if let bIdx = buildings.firstIndex(where: { $0.position == unit.position && $0.owner != unit.owner }) {
                buildings[bIdx].hp -= unit.type.attack
                if buildings[bIdx].hp <= 0 && buildings[bIdx].type != .hq {
                    combatLog.append("\(unit.type.displayName) destroyed \(buildings[bIdx].type.displayName)")
                    buildings.remove(at: bIdx)
                } else if buildings[bIdx].hp <= 0 && buildings[bIdx].type == .hq {
                    // HQ destroyed = game over
                    let winner = unit.owner
                    phase = .gameOver(winner: winner)
                }
            }
        }

        units.removeAll { toRemove.contains($0.id) }
    }

    // MARK: - Turrets

    private func processTurrets() {
        for building in buildings where building.type == .turret {
            let enemyUnits = units.filter { $0.owner != building.owner && $0.position.distance(to: building.position) <= 3 }
            if let target = enemyUnits.first {
                if let idx = units.firstIndex(where: { $0.id == target.id }) {
                    units[idx].hp -= 8
                    if units[idx].hp <= 0 {
                        combatLog.append("Turret destroyed \(units[idx].type.displayName)")
                        units.remove(at: idx)
                    }
                }
            }
        }
    }

    // MARK: - Automation Execution

    private func runAutomations(for player: Int) {
        guard let state = playerStates[player] else { return }

        for pipeline in state.pipelines where pipeline.isEnabled {
            // Simple pipeline execution: find trigger -> check conditions -> run actions
            let triggers = pipeline.nodes.filter {
                if case .trigger = $0.nodeType { return true }
                return false
            }

            for trigger in triggers {
                let triggered = evaluateTrigger(trigger, player: player)
                if !triggered { continue }

                // Find connected conditions
                let connectedConditionIds = pipeline.connections
                    .filter { $0.fromNodeId == trigger.id }
                    .map { $0.toNodeId }
                let conditions = pipeline.nodes.filter { connectedConditionIds.contains($0.id) }

                let allConditionsMet = conditions.allSatisfy { evaluateCondition($0, player: player) }
                if !allConditionsMet && !conditions.isEmpty { continue }

                // Find actions connected to conditions (or directly to trigger if no conditions)
                let sourceIds = conditions.isEmpty ? [trigger.id] : conditions.map { $0.id }
                let actionIds = pipeline.connections
                    .filter { sourceIds.contains($0.fromNodeId) }
                    .map { $0.toNodeId }
                let actions = pipeline.nodes.filter { actionIds.contains($0.id) }

                for action in actions {
                    executeAction(action, player: player)
                }
            }
        }
    }

    private func evaluateTrigger(_ node: AutomationNode, player: Int) -> Bool {
        guard case .trigger(let type) = node.nodeType else { return false }
        switch type {
        case .sensorDetectsEnemy:
            let sensors = buildings.filter { $0.type == .sensor && $0.owner == player }
            let enemies = units.filter { $0.owner != player }
            return sensors.contains { sensor in
                enemies.contains { $0.position.distance(to: sensor.position) <= sensor.type.visionRange }
            }
        case .resourceBelowThreshold:
            let res = playerStates[player]?.resources ?? .zero
            return res.iron < node.parameter
        case .everyNTicks:
            let n = max(1, node.parameter)
            return tickCount % n == 0
        case .buildingAttacked:
            return buildings.contains { b in
                b.owner == player && b.hp < b.type.hp
            }
        }
    }

    private func evaluateCondition(_ node: AutomationNode, player: Int) -> Bool {
        guard case .condition(let type) = node.nodeType else { return false }
        switch type {
        case .resourceAbove:
            let res = playerStates[player]?.resources ?? .zero
            return res.iron > node.parameter
        case .unitsAvailable:
            return units.filter({ $0.owner == player }).count > node.parameter
        case .enemyInRange:
            let ownBuildings = buildings.filter { $0.owner == player }
            let enemies = units.filter { $0.owner != player }
            return ownBuildings.contains { b in
                enemies.contains { $0.position.distance(to: b.position) <= node.parameter }
            }
        }
    }

    private func executeAction(_ node: AutomationNode, player: Int) {
        guard case .action(let type) = node.nodeType else { return }
        switch type {
        case .buildUnit:
            // Auto-build scout at first available factory
            if let factory = buildings.first(where: { $0.type == .factory && $0.owner == player }) {
                if playerStates[player]?.resources.canAfford(UnitType.scout.resourceCost) == true {
                    playerStates[player]?.resources.subtract(UnitType.scout.resourceCost)
                    let adj = factory.position.neighbors().first { coord in
                        cells[coord] != nil && building(at: coord) == nil
                    }
                    if let pos = adj {
                        units.append(GameUnit(type: .scout, owner: player, position: pos))
                    }
                }
            }
        case .sendUnits:
            // Send idle units toward enemy HQ
            let enemyHQ = buildings.first(where: { $0.type == .hq && $0.owner != player })
            if let target = enemyHQ?.position {
                for i in units.indices where units[i].owner == player && units[i].targetHex == nil {
                    units[i].targetHex = target
                }
            }
        case .activateTurret:
            break // Turrets auto-fire already
        case .alertPlayer:
            combatLog.append("⚠️ P\(player) automation alert triggered!")
        }
    }

    // MARK: - Win Conditions

    private func checkWinConditions() {
        // Check if any HQ is destroyed (hp <= 0)
        for building in buildings where building.type == .hq && building.hp <= 0 {
            let winner = building.owner == 1 ? 2 : 1
            phase = .gameOver(winner: winner)
            return
        }

        // Time ran out
        if gameTimeRemaining <= 0 {
            let r1 = playerStates[1]?.resources.total ?? 0
            let r2 = playerStates[2]?.resources.total ?? 0
            if r1 > r2 { phase = .gameOver(winner: 1) }
            else if r2 > r1 { phase = .gameOver(winner: 2) }
            else { phase = .gameOver(winner: 0) }
        }
    }

    // MARK: - Helpers

    func building(at coord: HexCoord) -> Building? {
        buildings.first { $0.position == coord }
    }

    func units(at coord: HexCoord) -> [GameUnit] {
        units.filter { $0.position == coord }
    }

    // MARK: - Timers

    private func startTimers() {
        tickTimer?.invalidate()
        gameTimer?.invalidate()

        tickTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.processTick()
        }

        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if case .gameOver = self.phase { return }
            self.gameTimeRemaining = max(0, self.gameTimeRemaining - 1)
            if self.gameTimeRemaining <= 0 {
                self.checkWinConditions()
            }
        }
    }

    func stopTimers() {
        tickTimer?.invalidate()
        gameTimer?.invalidate()
        tickTimer = nil
        gameTimer = nil
    }

    func resumeTimers() {
        if tickTimer == nil { startTimers() }
    }

    deinit {
        stopTimers()
    }
}
