import SwiftUI

// MARK: - Hex Coordinate System (Axial)

struct HexCoord: Hashable, Codable, Equatable {
    let q: Int
    let r: Int

    var s: Int { -q - r }

    func neighbors() -> [HexCoord] {
        HexCoord.directions.map { HexCoord(q: q + $0.q, r: r + $0.r) }
    }

    func distance(to other: HexCoord) -> Int {
        max(abs(q - other.q), abs(r - other.r), abs(s - other.s))
    }

    static let directions: [HexCoord] = [
        HexCoord(q: 1, r: 0), HexCoord(q: 1, r: -1), HexCoord(q: 0, r: -1),
        HexCoord(q: -1, r: 0), HexCoord(q: -1, r: 1), HexCoord(q: 0, r: 1)
    ]

    // Convert hex to pixel (pointy-top)
    func toPixel(size: CGFloat) -> CGPoint {
        let x = size * (sqrt(3) * Double(q) + sqrt(3) / 2 * Double(r))
        let y = size * (3.0 / 2.0 * Double(r))
        return CGPoint(x: x, y: y)
    }

    static func fromPixel(_ point: CGPoint, size: CGFloat) -> HexCoord {
        let q = (sqrt(3) / 3.0 * point.x - 1.0 / 3.0 * point.y) / size
        let r = (2.0 / 3.0 * point.y) / size
        return axialRound(q: q, r: r)
    }

    private static func axialRound(q: CGFloat, r: CGFloat) -> HexCoord {
        let s = -q - r
        var rq = round(q)
        var rr = round(r)
        let rs = round(s)
        let qDiff = abs(rq - q)
        let rDiff = abs(rr - r)
        let sDiff = abs(rs - s)
        if qDiff > rDiff && qDiff > sDiff {
            rq = -rr - rs
        } else if rDiff > sDiff {
            rr = -rq - rs
        }
        return HexCoord(q: Int(rq), r: Int(rr))
    }
}

// MARK: - Resources

struct Resources: Codable, Equatable {
    var iron: Int = 0
    var crystal: Int = 0
    var fuel: Int = 0
    var data: Int = 0

    static let zero = Resources()

    static func + (lhs: Resources, rhs: Resources) -> Resources {
        Resources(iron: lhs.iron + rhs.iron, crystal: lhs.crystal + rhs.crystal,
                  fuel: lhs.fuel + rhs.fuel, data: lhs.data + rhs.data)
    }

    mutating func add(_ other: Resources) {
        iron += other.iron; crystal += other.crystal
        fuel += other.fuel; data += other.data
    }

    func canAfford(_ cost: Resources) -> Bool {
        iron >= cost.iron && crystal >= cost.crystal && fuel >= cost.fuel && data >= cost.data
    }

    mutating func subtract(_ cost: Resources) {
        iron -= cost.iron; crystal -= cost.crystal
        fuel -= cost.fuel; data -= cost.data
    }

    var total: Int { iron + crystal + fuel + data }
}

// MARK: - Resource Node on Map

enum ResourceType: String, CaseIterable, Codable {
    case iron, crystal, fuel, data

    var color: Color {
        switch self {
        case .iron: return Color(red: 0.7, green: 0.75, blue: 0.8)
        case .crystal: return Color(red: 0.6, green: 0.3, blue: 0.9)
        case .fuel: return Color(red: 1.0, green: 0.6, blue: 0.15)
        case .data: return Color(red: 0.2, green: 0.9, blue: 0.4)
        }
    }

    var emoji: String {
        switch self {
        case .iron: return "🔩"
        case .crystal: return "💎"
        case .fuel: return "⛽"
        case .data: return "📡"
        }
    }
}

// MARK: - Building Types

enum BuildingType: String, CaseIterable, Codable {
    case hq, extractor, relay, factory, turret, sensor

    var displayName: String {
        switch self {
        case .hq: return "HQ"
        case .extractor: return "Extractor"
        case .relay: return "Relay"
        case .factory: return "Factory"
        case .turret: return "Turret"
        case .sensor: return "Sensor"
        }
    }

    var icon: String {
        switch self {
        case .hq: return "building.2.fill"
        case .extractor: return "gearshape.2.fill"
        case .relay: return "antenna.radiowaves.left.and.right"
        case .factory: return "hammer.fill"
        case .turret: return "scope"
        case .sensor: return "dot.radiowaves.left.and.right"
        }
    }

    var apCost: Int {
        switch self {
        case .hq: return 0
        case .extractor: return 1
        case .relay: return 1
        case .factory: return 2
        case .turret: return 1
        case .sensor: return 1
        }
    }

    var resourceCost: Resources {
        switch self {
        case .hq: return .zero
        case .extractor: return Resources(iron: 10)
        case .relay: return Resources(iron: 15, crystal: 5)
        case .factory: return Resources(iron: 25, crystal: 10)
        case .turret: return Resources(iron: 20, crystal: 15)
        case .sensor: return Resources(crystal: 5, data: 5)
        }
    }

    var visionRange: Int {
        switch self {
        case .hq: return 4
        case .extractor: return 2
        case .relay: return 3
        case .factory: return 2
        case .turret: return 3
        case .sensor: return 5
        }
    }

    var hp: Int {
        switch self {
        case .hq: return 100
        case .extractor: return 20
        case .relay: return 15
        case .factory: return 30
        case .turret: return 25
        case .sensor: return 10
        }
    }

    var color: Color {
        switch self {
        case .hq: return .white
        case .extractor: return Color(red: 0.7, green: 0.75, blue: 0.8)
        case .relay: return .cyan
        case .factory: return .orange
        case .turret: return .red
        case .sensor: return .green
        }
    }

    var requiresResourceNode: Bool {
        self == .extractor
    }
}

// MARK: - Unit Types

enum UnitType: String, CaseIterable, Codable {
    case scout, soldier, tank

    var displayName: String {
        switch self {
        case .scout: return "Scout"
        case .soldier: return "Soldier"
        case .tank: return "Tank"
        }
    }

    var icon: String {
        switch self {
        case .scout: return "eye.fill"
        case .soldier: return "figure.walk"
        case .tank: return "shield.fill"
        }
    }

    var resourceCost: Resources {
        switch self {
        case .scout: return Resources(iron: 5)
        case .soldier: return Resources(iron: 10, crystal: 5)
        case .tank: return Resources(iron: 20, crystal: 10, fuel: 5)
        }
    }

    var hp: Int {
        switch self {
        case .scout: return 10
        case .soldier: return 25
        case .tank: return 50
        }
    }

    var attack: Int {
        switch self {
        case .scout: return 3
        case .soldier: return 10
        case .tank: return 20
        }
    }

    var speed: Int { // hexes per tick
        switch self {
        case .scout: return 3
        case .soldier: return 2
        case .tank: return 1
        }
    }

    var visionRange: Int {
        switch self {
        case .scout: return 4
        case .soldier: return 2
        case .tank: return 2
        }
    }

    var buildTime: Int { // ticks
        switch self {
        case .scout: return 1
        case .soldier: return 2
        case .tank: return 3
        }
    }

    var color: Color {
        switch self {
        case .scout: return .cyan
        case .soldier: return .yellow
        case .tank: return .red
        }
    }
}

// MARK: - Game Entities

struct Building: Identifiable, Codable, Equatable {
    let id: UUID
    let type: BuildingType
    let owner: Int // 1 or 2
    let position: HexCoord
    var hp: Int
    var productionQueue: [UnitType]
    var productionProgress: Int

    init(type: BuildingType, owner: Int, position: HexCoord) {
        self.id = UUID()
        self.type = type
        self.owner = owner
        self.position = position
        self.hp = type.hp
        self.productionQueue = []
        self.productionProgress = 0
    }

    static func == (lhs: Building, rhs: Building) -> Bool { lhs.id == rhs.id }
}

struct GameUnit: Identifiable, Codable, Equatable {
    let id: UUID
    let type: UnitType
    let owner: Int
    var position: HexCoord
    var hp: Int
    var targetHex: HexCoord?

    init(type: UnitType, owner: Int, position: HexCoord) {
        self.id = UUID()
        self.type = type
        self.owner = owner
        self.position = position
        self.hp = type.hp
    }

    static func == (lhs: GameUnit, rhs: GameUnit) -> Bool { lhs.id == rhs.id }
}

// MARK: - Hex Cell

struct HexCell: Identifiable, Codable {
    let coord: HexCoord
    var resourceType: ResourceType?
    var resourceAmount: Int

    var id: String { "\(coord.q),\(coord.r)" }

    init(coord: HexCoord, resourceType: ResourceType? = nil, resourceAmount: Int = 0) {
        self.coord = coord
        self.resourceType = resourceType
        self.resourceAmount = resourceAmount
    }
}

// MARK: - Automation System

enum AutoTriggerType: String, Codable, CaseIterable {
    case sensorDetectsEnemy = "Sensor Detects Enemy"
    case resourceBelowThreshold = "Resource Below Threshold"
    case everyNTicks = "Every N Ticks"
    case buildingAttacked = "Building Attacked"
}

enum AutoConditionType: String, Codable, CaseIterable {
    case resourceAbove = "Resource > X"
    case unitsAvailable = "Units Available > X"
    case enemyInRange = "Enemy In Range"
}

enum AutoActionType: String, Codable, CaseIterable {
    case buildUnit = "Build Unit at Factory"
    case sendUnits = "Send Units to Hex"
    case activateTurret = "Activate Turrets"
    case alertPlayer = "Alert Player"
}

struct AutomationNode: Identifiable, Codable {
    let id: UUID
    var nodeType: AutoNodeType
    var position: CGPoint
    var parameter: Int // threshold, tick count, etc.

    init(nodeType: AutoNodeType, position: CGPoint, parameter: Int = 0) {
        self.id = UUID()
        self.nodeType = nodeType
        self.position = position
        self.parameter = parameter
    }
}

enum AutoNodeType: Codable, Equatable {
    case trigger(AutoTriggerType)
    case condition(AutoConditionType)
    case action(AutoActionType)

    var displayName: String {
        switch self {
        case .trigger(let t): return t.rawValue
        case .condition(let c): return c.rawValue
        case .action(let a): return a.rawValue
        }
    }

    var color: Color {
        switch self {
        case .trigger: return Color(red: 0.2, green: 0.9, blue: 0.3)
        case .condition: return Color(red: 0.95, green: 0.8, blue: 0.1)
        case .action: return Color(red: 0.95, green: 0.25, blue: 0.3)
        }
    }

    var category: String {
        switch self {
        case .trigger: return "TRIGGER"
        case .condition: return "CONDITION"
        case .action: return "ACTION"
        }
    }
}

struct AutomationConnection: Identifiable, Codable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID

    init(from: UUID, to: UUID) {
        self.id = UUID()
        self.fromNodeId = from
        self.toNodeId = to
    }
}

struct AutomationPipeline: Identifiable, Codable {
    let id: UUID
    var name: String
    var nodes: [AutomationNode]
    var connections: [AutomationConnection]
    var isEnabled: Bool

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.nodes = []
        self.connections = []
        self.isEnabled = true
    }
}

// MARK: - Player State

struct PlayerState: Codable {
    var resources: Resources
    var ap: Int
    var maxAP: Int
    var pipelines: [AutomationPipeline]

    init() {
        self.resources = Resources(iron: 30, crystal: 10, fuel: 5, data: 5)
        self.ap = 10
        self.maxAP = 10
        self.pipelines = []
    }
}

// MARK: - Game Phase

enum GridlockPhase: Codable, Equatable {
    case setup
    case playerTurn(Int)
    case transition(Int) // next player
    case processing // automations running
    case gameOver(winner: Int) // 0 = tie
}

// MARK: - Action Menu State

enum GridlockAction: Equatable {
    case none
    case buildMenu
    case placingBuilding(BuildingType)
    case deployMenu
    case placingUnit(UnitType)
    case selectingTarget(UUID) // unit ID to assign target
    case automationEditor
}

// MARK: - Map Generation

struct GridlockMapGenerator {
    static let mapRadius = 14 // 30x30 ish hex grid

    static func generate() -> (cells: [HexCoord: HexCell], p1Start: HexCoord, p2Start: HexCoord) {
        var cells: [HexCoord: HexCell] = [:]

        // Create hex grid
        for q in -mapRadius...mapRadius {
            let r1 = max(-mapRadius, -q - mapRadius)
            let r2 = min(mapRadius, -q + mapRadius)
            for r in r1...r2 {
                let coord = HexCoord(q: q, r: r)
                cells[coord] = HexCell(coord: coord)
            }
        }

        // Player starting positions (opposite corners)
        let p1Start = HexCoord(q: -mapRadius + 2, r: mapRadius - 2)
        let p2Start = HexCoord(q: mapRadius - 2, r: -mapRadius + 2)

        // Place resources with seeded randomness for symmetry
        let allCoords = Array(cells.keys).sorted { ($0.q, $0.r) < ($1.q, $1.r) }
        var rng = SeededRNG(seed: UInt64.random(in: 0...UInt64.max))

        for coord in allCoords {
            let dist1 = coord.distance(to: p1Start)
            let dist2 = coord.distance(to: p2Start)
            let minDist = min(dist1, dist2)
            let centerDist = coord.distance(to: HexCoord(q: 0, r: 0))

            // Skip area near HQs
            if minDist <= 2 { continue }

            var chance: Double = 0.12
            // Higher density in contested middle
            if centerDist <= 5 { chance = 0.25 }
            // Medium density in middle ring
            else if centerDist <= 9 { chance = 0.18 }

            if Double.random(in: 0...1, using: &rng) < chance {
                let roll = Double.random(in: 0...1, using: &rng)
                let type: ResourceType
                let amount: Int
                if roll < 0.45 {
                    type = .iron
                    amount = Int.random(in: 30...80, using: &rng)
                } else if roll < 0.72 {
                    type = .crystal
                    amount = Int.random(in: 20...50, using: &rng)
                } else if roll < 0.9 {
                    type = .fuel
                    amount = Int.random(in: 15...40, using: &rng)
                } else {
                    type = .data
                    amount = Int.random(in: 10...25, using: &rng)
                }
                cells[coord]?.resourceType = type
                cells[coord]?.resourceAmount = amount
            }
        }

        return (cells, p1Start, p2Start)
    }
}

// MARK: - Seeded RNG

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
