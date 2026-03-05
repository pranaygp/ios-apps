import SpriteKit

protocol SonarDuelSceneDelegate: AnyObject {
    func sceneReady()
}

class SonarDuelScene: SKScene {

    weak var gameDelegate: SonarDuelSceneDelegate?

    // Grid constants
    private let gridSize = 10
    private var cellSize: CGFloat = 0
    private var gridOrigin: CGPoint = .zero

    // Layers
    private let gridLayer = SKNode()
    private let fogLayer = SKNode()
    private let entityLayer = SKNode()
    private let effectLayer = SKNode()
    private let uiLayer = SKNode()

    // Visual state
    private var fogNodes: [[SKShapeNode]] = []
    private var mySubNode: SKNode?
    private var enemySubNode: SKNode?
    private var torpedoNodes: [UUID: SKNode] = [:]
    private var mineNodes: [UUID: SKNode] = [:]
    private var mineBlinkTimers: [UUID: TimeInterval] = [:]

    // State tracking
    private var currentState: GameState?
    private var myRole: PlayerRole = .host
    private var revealedTiles = Set<GridPosition>()
    private var sonarRevealedTiles = Set<GridPosition>()
    private var enemyVisibleUntil: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0

    // Colors
    private let oceanColor = SKColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 1.0)
    private let fogColor = SKColor(red: 0.02, green: 0.04, blue: 0.1, alpha: 0.85)
    private let revealedColor = SKColor(red: 0.08, green: 0.2, blue: 0.4, alpha: 0.3)
    private let gridLineColor = SKColor(red: 0.1, green: 0.2, blue: 0.35, alpha: 0.3)
    private let mySubColor = SKColor(red: 0.2, green: 0.85, blue: 0.8, alpha: 1.0)
    private let enemySubColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)

    override func didMove(to view: SKView) {
        backgroundColor = oceanColor
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        calculateGrid()
        setupLayers()
        setupGrid()
        setupFog()
        setupSubmarines()

        gameDelegate?.sceneReady()
    }

    // MARK: - Setup

    private func calculateGrid() {
        let availableWidth = size.width - 40
        let availableHeight = size.height * 0.7
        cellSize = min(availableWidth, availableHeight) / CGFloat(gridSize)
        let gridWidth = cellSize * CGFloat(gridSize)
        let gridHeight = cellSize * CGFloat(gridSize)
        gridOrigin = CGPoint(x: -gridWidth / 2, y: -gridHeight / 2 + 20)
    }

    private func setupLayers() {
        addChild(gridLayer)
        addChild(fogLayer)
        addChild(entityLayer)
        addChild(effectLayer)
        addChild(uiLayer)
    }

    private func setupGrid() {
        // Background ocean
        let bg = SKShapeNode(rectOf: CGSize(
            width: cellSize * CGFloat(gridSize),
            height: cellSize * CGFloat(gridSize)
        ), cornerRadius: 4)
        bg.fillColor = SKColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1.0)
        bg.strokeColor = .clear
        bg.position = CGPoint(
            x: gridOrigin.x + cellSize * CGFloat(gridSize) / 2,
            y: gridOrigin.y + cellSize * CGFloat(gridSize) / 2
        )
        gridLayer.addChild(bg)

        // Grid lines
        for i in 0...gridSize {
            let x = gridOrigin.x + CGFloat(i) * cellSize
            let yStart = gridOrigin.y
            let yEnd = gridOrigin.y + CGFloat(gridSize) * cellSize

            let vLine = SKShapeNode()
            let vPath = CGMutablePath()
            vPath.move(to: CGPoint(x: x, y: yStart))
            vPath.addLine(to: CGPoint(x: x, y: yEnd))
            vLine.path = vPath
            vLine.strokeColor = gridLineColor
            vLine.lineWidth = 0.5
            gridLayer.addChild(vLine)

            let y = gridOrigin.y + CGFloat(i) * cellSize
            let xStart = gridOrigin.x
            let xEnd = gridOrigin.x + CGFloat(gridSize) * cellSize

            let hLine = SKShapeNode()
            let hPath = CGMutablePath()
            hPath.move(to: CGPoint(x: xStart, y: y))
            hPath.addLine(to: CGPoint(x: xEnd, y: y))
            hLine.path = hPath
            hLine.strokeColor = gridLineColor
            hLine.lineWidth = 0.5
            gridLayer.addChild(hLine)
        }
    }

    private func setupFog() {
        fogNodes = Array(repeating: Array(repeating: SKShapeNode(), count: gridSize), count: gridSize)
        for x in 0...gridSize - 1 {
            for y in 0...gridSize - 1 {
                let node = SKShapeNode(rectOf: CGSize(width: cellSize, height: cellSize))
                node.fillColor = fogColor
                node.strokeColor = .clear
                node.position = gridPointToScene(GridPosition(x: x, y: y))
                node.zPosition = 10
                fogLayer.addChild(node)
                fogNodes[x][y] = node
            }
        }
    }

    private func setupSubmarines() {
        mySubNode = createSubmarineNode(color: mySubColor)
        mySubNode?.zPosition = 20
        entityLayer.addChild(mySubNode!)

        enemySubNode = createSubmarineNode(color: enemySubColor)
        enemySubNode?.zPosition = 20
        enemySubNode?.alpha = 0
        entityLayer.addChild(enemySubNode!)
    }

    private func createSubmarineNode(color: SKColor) -> SKNode {
        let container = SKNode()

        // Hull - elongated oval shape
        let hull = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.75, height: cellSize * 0.4))
        hull.fillColor = color
        hull.strokeColor = color.withAlphaComponent(0.6)
        hull.lineWidth = 1.5
        container.addChild(hull)

        // Conning tower
        let tower = SKShapeNode(rectOf: CGSize(width: cellSize * 0.15, height: cellSize * 0.22), cornerRadius: 2)
        tower.fillColor = color.withAlphaComponent(0.8)
        tower.strokeColor = .clear
        tower.position = CGPoint(x: 0, y: cellSize * 0.08)
        container.addChild(tower)

        // Glow
        let glow = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.9, height: cellSize * 0.55))
        glow.fillColor = color.withAlphaComponent(0.15)
        glow.strokeColor = .clear
        glow.zPosition = -1
        container.addChild(glow)

        // Pulse animation on glow
        let pulseUp = SKAction.fadeAlpha(to: 0.3, duration: 1.0)
        let pulseDown = SKAction.fadeAlpha(to: 0.1, duration: 1.0)
        glow.run(.repeatForever(.sequence([pulseUp, pulseDown])))

        return container
    }

    // MARK: - Grid Conversion

    private func gridPointToScene(_ pos: GridPosition) -> CGPoint {
        CGPoint(
            x: gridOrigin.x + (CGFloat(pos.x) + 0.5) * cellSize,
            y: gridOrigin.y + (CGFloat(gridSize - 1 - pos.y) + 0.5) * cellSize
        )
    }

    // MARK: - Update State

    func updateGameState(_ state: GameState, myRole: PlayerRole, events: [GameEvent]) {
        self.currentState = state
        self.myRole = myRole

        let myPlayer = myRole == .host ? state.hostPlayer : state.guestPlayer
        let enemyPlayer = myRole == .host ? state.guestPlayer : state.hostPlayer

        // Update visibility
        revealedTiles = myPlayer.visibleTiles
        if myPlayer.pingActive {
            sonarRevealedTiles = myPlayer.sonarTiles
        } else {
            sonarRevealedTiles.removeAll()
        }

        // Update fog
        updateFog()

        // Move my sub
        let myPos = gridPointToScene(myPlayer.position)
        mySubNode?.run(.move(to: myPos, duration: 0.3))

        // Enemy visibility
        let enemyPos = gridPointToScene(enemyPlayer.position)
        enemySubNode?.position = enemyPos

        let canSeeEnemy = revealedTiles.contains(enemyPlayer.position) ||
                          sonarRevealedTiles.contains(enemyPlayer.position) ||
                          enemyPlayer.pingActive

        if canSeeEnemy {
            enemySubNode?.run(.fadeAlpha(to: 1.0, duration: 0.2))
            if enemyPlayer.pingActive {
                enemyVisibleUntil = lastUpdateTime + 2.0
            }
        } else {
            enemySubNode?.run(.fadeAlpha(to: 0.0, duration: 0.3))
        }

        // Process events for animations
        for event in events {
            animateEvent(event, state: state)
        }

        // Update torpedoes
        updateTorpedoes(state.torpedoes)

        // Update mines
        updateMines(state.mines, myPlayer: myPlayer)
    }

    private func updateFog() {
        for x in 0..<gridSize {
            for y in 0..<gridSize {
                let pos = GridPosition(x: x, y: y)
                let node = fogNodes[x][y]

                if revealedTiles.contains(pos) {
                    node.run(.fadeAlpha(to: 0.0, duration: 0.2))
                } else if sonarRevealedTiles.contains(pos) {
                    node.fillColor = SKColor(red: 0.05, green: 0.3, blue: 0.15, alpha: 0.3)
                    node.run(.fadeAlpha(to: 1.0, duration: 0.2))
                } else {
                    node.fillColor = fogColor
                    node.run(.fadeAlpha(to: 1.0, duration: 0.3))
                }
            }
        }
    }

    private func updateTorpedoes(_ torpedoes: [Torpedo]) {
        // Remove old torpedo nodes
        let currentIDs = Set(torpedoes.map { $0.id })
        for (id, node) in torpedoNodes {
            if !currentIDs.contains(id) {
                node.removeFromParent()
                torpedoNodes.removeValue(forKey: id)
            }
        }

        // Add/update torpedo nodes
        for torpedo in torpedoes {
            let pos = gridPointToScene(torpedo.position)
            let isVisible = revealedTiles.contains(torpedo.position) || sonarRevealedTiles.contains(torpedo.position)

            if let node = torpedoNodes[torpedo.id] {
                node.run(.move(to: pos, duration: 0.2))
                node.alpha = isVisible ? 1.0 : 0.0
            } else {
                let node = createTorpedoNode(direction: torpedo.direction, owner: torpedo.owner)
                node.position = pos
                node.alpha = isVisible ? 1.0 : 0.0
                entityLayer.addChild(node)
                torpedoNodes[torpedo.id] = node
            }
        }
    }

    private func createTorpedoNode(direction: Direction, owner: PlayerRole) -> SKNode {
        let container = SKNode()
        container.zPosition = 25

        let body = SKShapeNode(ellipseOf: CGSize(width: cellSize * 0.35, height: cellSize * 0.15))
        body.fillColor = SKColor(red: 1.0, green: 0.7, blue: 0.1, alpha: 1.0)
        body.strokeColor = SKColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 0.8)
        body.lineWidth = 1

        // Rotate based on direction
        let angle: CGFloat
        switch direction {
        case .up: angle = .pi / 2
        case .down: angle = -.pi / 2
        case .left: angle = .pi
        case .right: angle = 0
        }
        body.zRotation = angle
        container.addChild(body)

        // Trail particle
        if let trail = createTorpedoTrail() {
            trail.zPosition = -1
            trail.targetNode = entityLayer
            container.addChild(trail)
        }

        // Glow
        let glow = SKShapeNode(circleOfRadius: cellSize * 0.2)
        glow.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.0, alpha: 0.2)
        glow.strokeColor = .clear
        container.addChild(glow)

        return container
    }

    private func createTorpedoTrail() -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 40
        emitter.particleLifetime = 0.5
        emitter.particleLifetimeRange = 0.2
        emitter.emissionAngle = .pi
        emitter.emissionAngleRange = 0.3
        emitter.particleSpeed = 20
        emitter.particleSpeedRange = 10
        emitter.particleAlpha = 0.7
        emitter.particleAlphaRange = 0.3
        emitter.particleAlphaSpeed = -1.5
        emitter.particleScale = 0.05
        emitter.particleScaleRange = 0.02
        emitter.particleScaleSpeed = -0.05
        emitter.particleColor = SKColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        emitter.particleColorBlendFactor = 1.0

        // Create a small white texture
        let size = CGSize(width: 8, height: 8)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        UIColor.white.setFill()
        UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        emitter.particleTexture = SKTexture(image: image)

        return emitter
    }

    private func updateMines(_ mines: [Mine], myPlayer: PlayerState) {
        let currentIDs = Set(mines.map { $0.id })
        for (id, node) in mineNodes {
            if !currentIDs.contains(id) {
                node.removeFromParent()
                mineNodes.removeValue(forKey: id)
                mineBlinkTimers.removeValue(forKey: id)
            }
        }

        for mine in mines {
            let isMyMine = mine.owner == myRole
            let isVisible = isMyMine || revealedTiles.contains(mine.position) || sonarRevealedTiles.contains(mine.position)

            if let node = mineNodes[mine.id] {
                node.alpha = isVisible ? 1.0 : 0.0
            } else {
                let node = createMineNode(isMine: isMyMine)
                node.position = gridPointToScene(mine.position)
                node.alpha = isVisible ? 1.0 : 0.0
                node.zPosition = 15
                entityLayer.addChild(node)
                mineNodes[mine.id] = node
            }
        }
    }

    private func createMineNode(isMine: Bool) -> SKNode {
        let container = SKNode()

        let body = SKShapeNode(circleOfRadius: cellSize * 0.15)
        body.fillColor = isMine ? SKColor(red: 0.8, green: 0.5, blue: 0.0, alpha: 0.8) : SKColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 0.8)
        body.strokeColor = .clear
        container.addChild(body)

        // Blink dot
        let dot = SKShapeNode(circleOfRadius: cellSize * 0.05)
        dot.fillColor = .red
        dot.strokeColor = .clear
        dot.name = "blinkDot"
        container.addChild(dot)

        let blinkOn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let blinkOff = SKAction.fadeAlpha(to: 0.1, duration: 0.3)
        let wait = SKAction.wait(forDuration: 0.8)
        dot.run(.repeatForever(.sequence([blinkOn, wait, blinkOff, wait])))

        return container
    }

    // MARK: - Event Animations

    private func animateEvent(_ event: GameEvent, state: GameState) {
        switch event {
        case .pinged(let role, let at):
            animateSonarPing(at: at, isMe: role == myRole)

        case .torpedoHit(_, let at):
            animateExplosion(at: at, large: true)

        case .mineDetonated(let at, _):
            animateExplosion(at: at, large: false)

        case .torpedoFired(let role, _):
            if role == myRole {
                HapticManager.impact(.medium)
            }

        default:
            break
        }
    }

    func animateSonarPing(at position: GridPosition, isMe: Bool) {
        let scenePos = gridPointToScene(position)
        let color = isMe ? SKColor(red: 0.1, green: 0.9, blue: 0.4, alpha: 1.0) : SKColor(red: 0.9, green: 0.3, blue: 0.3, alpha: 0.6)

        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 1)
            ring.strokeColor = color
            ring.fillColor = .clear
            ring.lineWidth = 2.5
            ring.position = scenePos
            ring.zPosition = 30
            ring.alpha = 0
            effectLayer.addChild(ring)

            let delay = SKAction.wait(forDuration: Double(i) * 0.25)
            let fadeIn = SKAction.fadeAlpha(to: 0.8, duration: 0.1)
            let expand = SKAction.scale(to: cellSize * 2.5, duration: 0.8)
            let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.6)
            let group = SKAction.group([expand, fadeOut])
            let sequence = SKAction.sequence([delay, fadeIn, group, .removeFromParent()])
            ring.run(sequence)
        }

        if isMe {
            HapticManager.impact(.light)
        }
    }

    func animateExplosion(at position: GridPosition, large: Bool) {
        let scenePos = gridPointToScene(position)

        // Flash
        let flash = SKShapeNode(circleOfRadius: large ? cellSize * 1.2 : cellSize * 0.8)
        flash.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.2, alpha: 0.8)
        flash.strokeColor = .clear
        flash.position = scenePos
        flash.zPosition = 40
        effectLayer.addChild(flash)

        let flashAnim = SKAction.sequence([
            .fadeAlpha(to: 1.0, duration: 0.05),
            .group([
                .scale(to: 1.5, duration: 0.3),
                .fadeAlpha(to: 0.0, duration: 0.3)
            ]),
            .removeFromParent()
        ])
        flash.run(flashAnim)

        // Particles
        let particleCount = large ? 16 : 10
        for _ in 0..<particleCount {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...4))
            let isOrange = Bool.random()
            particle.fillColor = isOrange ?
                SKColor(red: 1.0, green: CGFloat.random(in: 0.3...0.6), blue: 0.0, alpha: 1.0) :
                SKColor(red: 1.0, green: CGFloat.random(in: 0.1...0.3), blue: 0.0, alpha: 1.0)
            particle.strokeColor = .clear
            particle.position = scenePos
            particle.zPosition = 41
            effectLayer.addChild(particle)

            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: cellSize * 0.5...cellSize * (large ? 2.0 : 1.2))
            let dest = CGPoint(
                x: scenePos.x + cos(angle) * distance,
                y: scenePos.y + sin(angle) * distance
            )
            let duration = Double.random(in: 0.3...0.6)

            particle.run(.sequence([
                .group([
                    .move(to: dest, duration: duration),
                    .fadeAlpha(to: 0.0, duration: duration),
                    .scale(to: 0.1, duration: duration)
                ]),
                .removeFromParent()
            ]))
        }

        // Screen shake
        if large {
            let shakeAmount: CGFloat = 4
            let shake = SKAction.sequence([
                .moveBy(x: shakeAmount, y: shakeAmount, duration: 0.02),
                .moveBy(x: -shakeAmount * 2, y: -shakeAmount, duration: 0.02),
                .moveBy(x: shakeAmount, y: -shakeAmount, duration: 0.02),
                .moveBy(x: 0, y: shakeAmount, duration: 0.02),
            ])
            gridLayer.run(.sequence([.repeat(shake, count: 3), .move(to: .zero, duration: 0.05)]))
        }

        HapticManager.notification(.error)
    }

    // MARK: - Water Ambient Effects

    override func update(_ currentTime: TimeInterval) {
        lastUpdateTime = currentTime

        // Fade enemy if ping visibility expired
        if let state = currentState {
            let enemyPlayer = myRole == .host ? state.guestPlayer : state.hostPlayer
            let canSeeNormally = revealedTiles.contains(enemyPlayer.position) || sonarRevealedTiles.contains(enemyPlayer.position)
            if !canSeeNormally && currentTime > enemyVisibleUntil {
                enemySubNode?.run(.fadeAlpha(to: 0.0, duration: 0.3))
            }
        }
    }

    // MARK: - Ambient Bubbles

    func spawnAmbientBubble() {
        let x = CGFloat.random(in: gridOrigin.x...(gridOrigin.x + cellSize * CGFloat(gridSize)))
        let bubble = SKShapeNode(circleOfRadius: CGFloat.random(in: 1...3))
        bubble.fillColor = SKColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 0.2)
        bubble.strokeColor = .clear
        bubble.position = CGPoint(x: x, y: gridOrigin.y - 10)
        bubble.zPosition = 5
        gridLayer.addChild(bubble)

        let riseHeight = cellSize * CGFloat(gridSize) + 20
        bubble.run(.sequence([
            .group([
                .moveBy(x: CGFloat.random(in: -15...15), y: riseHeight, duration: Double.random(in: 4...8)),
                .sequence([
                    .fadeAlpha(to: 0.4, duration: 1),
                    .wait(forDuration: 2),
                    .fadeAlpha(to: 0, duration: 1)
                ])
            ]),
            .removeFromParent()
        ]))
    }
}
