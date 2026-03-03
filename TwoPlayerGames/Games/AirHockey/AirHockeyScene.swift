import SpriteKit
import UIKit

protocol AirHockeySceneDelegate: AnyObject {
    func scoreDidUpdate(player1: Int, player2: Int)
    func gameDidEnd(winner: Int)
}

class AirHockeyScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: AirHockeySceneDelegate?

    private var paddle1: SKShapeNode!  // bottom
    private var paddle2: SKShapeNode!  // top
    private var puck: SKShapeNode!
    private var score1Label: SKLabelNode!
    private var score2Label: SKLabelNode!

    private var score1 = 0
    private var score2 = 0
    private var winScore: Int { GameSettings.shared.airHockeyWinScore }
    private var isGameOver = false

    private var paddle1Touch: UITouch?
    private var paddle2Touch: UITouch?

    private var paddle1PrevPos: CGPoint = .zero
    private var paddle2PrevPos: CGPoint = .zero
    private var paddle1Velocity: CGVector = .zero
    private var paddle2Velocity: CGVector = .zero
    private var lastUpdateTime: TimeInterval = 0

    private let paddleRadius: CGFloat = 40
    private let puckRadius: CGFloat = 18
    private let goalWidth: CGFloat = 140
    private let rinkInset: CGFloat = 10

    private let puckFriction: CGFloat = 0.98

    struct PhysicsCategory {
        static let puck: UInt32 = 0x1 << 0
        static let paddle: UInt32 = 0x1 << 1
        static let wall: UInt32 = 0x1 << 2
        static let goal: UInt32 = 0x1 << 3
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero
        view.isMultipleTouchEnabled = true

        setupRink()
        setupGoals()
        setupPaddles()
        setupPuck()
        setupScoreLabels()
        setupCenterCircle()
    }

    private func setupRink() {
        let rink = SKShapeNode(rectOf: CGSize(width: size.width - rinkInset * 2, height: size.height - rinkInset * 2), cornerRadius: 20)
        rink.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rink.strokeColor = .white.withAlphaComponent(0.15)
        rink.lineWidth = 2
        rink.fillColor = .clear
        rink.zPosition = -1
        addChild(rink)

        // Build walls with gaps for goals
        let halfGoal = goalWidth / 2
        let midX = size.width / 2

        // Bottom wall - left segment
        addWallEdge(from: CGPoint(x: rinkInset, y: rinkInset),
                     to: CGPoint(x: midX - halfGoal, y: rinkInset))
        // Bottom wall - right segment
        addWallEdge(from: CGPoint(x: midX + halfGoal, y: rinkInset),
                     to: CGPoint(x: size.width - rinkInset, y: rinkInset))
        // Top wall - left segment
        addWallEdge(from: CGPoint(x: rinkInset, y: size.height - rinkInset),
                     to: CGPoint(x: midX - halfGoal, y: size.height - rinkInset))
        // Top wall - right segment
        addWallEdge(from: CGPoint(x: midX + halfGoal, y: size.height - rinkInset),
                     to: CGPoint(x: size.width - rinkInset, y: size.height - rinkInset))
        // Left wall
        addWallEdge(from: CGPoint(x: rinkInset, y: rinkInset),
                     to: CGPoint(x: rinkInset, y: size.height - rinkInset))
        // Right wall
        addWallEdge(from: CGPoint(x: size.width - rinkInset, y: rinkInset),
                     to: CGPoint(x: size.width - rinkInset, y: size.height - rinkInset))

        // Center line
        let centerPath = CGMutablePath()
        centerPath.move(to: CGPoint(x: rinkInset, y: size.height / 2))
        centerPath.addLine(to: CGPoint(x: size.width - rinkInset, y: size.height / 2))
        let centerLine = SKShapeNode(path: centerPath)
        centerLine.strokeColor = .white.withAlphaComponent(0.1)
        centerLine.lineWidth = 1
        centerLine.zPosition = -1
        addChild(centerLine)
    }

    private func addWallEdge(from: CGPoint, to: CGPoint) {
        let node = SKNode()
        node.physicsBody = SKPhysicsBody(edgeFrom: from, to: to)
        node.physicsBody?.categoryBitMask = PhysicsCategory.wall
        node.physicsBody?.friction = 0
        node.physicsBody?.restitution = 0.8
        addChild(node)
    }

    private func setupGoals() {
        let midX = size.width / 2

        // Goal indicators (visual)
        for isTop in [false, true] {
            let y: CGFloat = isTop ? size.height - rinkInset : rinkInset
            let goalLine = SKShapeNode(rectOf: CGSize(width: goalWidth, height: 4), cornerRadius: 2)
            goalLine.position = CGPoint(x: midX, y: y)
            goalLine.fillColor = isTop ? UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.5) : UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.5)
            goalLine.strokeColor = .clear
            goalLine.zPosition = -1
            addChild(goalLine)
        }
    }

    private func setupCenterCircle() {
        let circle = SKShapeNode(circleOfRadius: 50)
        circle.position = CGPoint(x: size.width / 2, y: size.height / 2)
        circle.strokeColor = .white.withAlphaComponent(0.1)
        circle.lineWidth = 1
        circle.fillColor = .clear
        circle.zPosition = -1
        addChild(circle)
    }

    private func setupPaddles() {
        paddle1 = createPaddle(color: UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0))
        paddle1.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        addChild(paddle1)

        paddle2 = createPaddle(color: UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0))
        paddle2.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
        addChild(paddle2)
    }

    private func createPaddle(color: UIColor) -> SKShapeNode {
        let paddle = SKShapeNode(circleOfRadius: paddleRadius)
        paddle.fillColor = color
        paddle.strokeColor = color.withAlphaComponent(0.3)
        paddle.lineWidth = 4

        let inner = SKShapeNode(circleOfRadius: paddleRadius * 0.5)
        inner.fillColor = color.withAlphaComponent(0.6)
        inner.strokeColor = .clear
        paddle.addChild(inner)

        paddle.physicsBody = SKPhysicsBody(circleOfRadius: paddleRadius)
        paddle.physicsBody?.isDynamic = false
        paddle.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle.physicsBody?.friction = 0
        paddle.physicsBody?.restitution = 1
        return paddle
    }

    private func setupPuck() {
        puck = SKShapeNode(circleOfRadius: puckRadius)
        puck.fillColor = .white
        puck.strokeColor = .white.withAlphaComponent(0.5)
        puck.lineWidth = 2
        puck.position = CGPoint(x: size.width / 2, y: size.height / 2)

        puck.physicsBody = SKPhysicsBody(circleOfRadius: puckRadius)
        puck.physicsBody?.isDynamic = true
        puck.physicsBody?.friction = 0
        puck.physicsBody?.restitution = 0.85
        puck.physicsBody?.linearDamping = 0.3
        puck.physicsBody?.angularDamping = 0
        puck.physicsBody?.allowsRotation = false
        puck.physicsBody?.mass = 0.05
        puck.physicsBody?.categoryBitMask = PhysicsCategory.puck
        puck.physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.wall
        puck.physicsBody?.collisionBitMask = PhysicsCategory.paddle | PhysicsCategory.wall
        addChild(puck)
    }

    private func setupScoreLabels() {
        score1Label = SKLabelNode(fontNamed: "Helvetica Neue")
        score1Label.text = "0"
        score1Label.fontSize = 48
        score1Label.fontColor = .white.withAlphaComponent(0.12)
        score1Label.position = CGPoint(x: size.width / 2, y: size.height * 0.28)
        score1Label.zPosition = -1
        addChild(score1Label)

        score2Label = SKLabelNode(fontNamed: "Helvetica Neue")
        score2Label.text = "0"
        score2Label.fontSize = 48
        score2Label.fontColor = .white.withAlphaComponent(0.12)
        score2Label.position = CGPoint(x: size.width / 2, y: size.height * 0.68)
        score2Label.zPosition = -1
        addChild(score2Label)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if location.y < size.height / 2 && paddle1Touch == nil {
                paddle1Touch = touch
                movePaddle(paddle1, to: location, isBottom: true)
            } else if location.y >= size.height / 2 && paddle2Touch == nil {
                paddle2Touch = touch
                movePaddle(paddle2, to: location, isBottom: false)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if touch == paddle1Touch {
                movePaddle(paddle1, to: location, isBottom: true)
            } else if touch == paddle2Touch {
                movePaddle(paddle2, to: location, isBottom: false)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == paddle1Touch { paddle1Touch = nil }
            if touch == paddle2Touch { paddle2Touch = nil }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    private func movePaddle(_ paddle: SKShapeNode, to point: CGPoint, isBottom: Bool) {
        let minX = rinkInset + paddleRadius
        let maxX = size.width - rinkInset - paddleRadius
        let clampedX = max(minX, min(maxX, point.x))

        let minY: CGFloat
        let maxY: CGFloat
        if isBottom {
            minY = rinkInset + paddleRadius
            maxY = size.height / 2 - paddleRadius
        } else {
            minY = size.height / 2 + paddleRadius
            maxY = size.height - rinkInset - paddleRadius
        }
        let clampedY = max(minY, min(maxY, point.y))

        paddle.position = CGPoint(x: clampedX, y: clampedY)
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask]
        if bodies.contains(PhysicsCategory.puck) && bodies.contains(PhysicsCategory.paddle) {
            SoundManager.playHit()
            HapticManager.impact(.medium)

            // Transfer paddle momentum to puck
            let paddleBody = contact.bodyA.categoryBitMask == PhysicsCategory.paddle ? contact.bodyA : contact.bodyB
            guard let paddleNode = paddleBody.node else { return }

            let paddleVel = paddleNode === paddle1 ? paddle1Velocity : paddle2Velocity

            // Direction from paddle center to puck
            let dx = puck.position.x - paddleNode.position.x
            let dy = puck.position.y - paddleNode.position.y
            let dist = sqrt(dx * dx + dy * dy)
            guard dist > 0 else { return }
            let normX = dx / dist
            let normY = dy / dist

            // Combine paddle speed with hit direction for realistic momentum
            let paddleSpeed = sqrt(paddleVel.dx * paddleVel.dx + paddleVel.dy * paddleVel.dy)
            let hitStrength = max(paddleSpeed * 1.8, 250)
            let maxHit: CGFloat = 1000

            let finalStrength = min(hitStrength, maxHit)
            puck.physicsBody?.velocity = CGVector(
                dx: normX * finalStrength + paddleVel.dx * 0.4,
                dy: normY * finalStrength + paddleVel.dy * 0.4
            )
        } else if bodies.contains(PhysicsCategory.puck) && bodies.contains(PhysicsCategory.wall) {
            HapticManager.impact(.light)
        }
    }

    // MARK: - Game Update

    override func update(_ currentTime: TimeInterval) {
        // Track paddle velocities
        if lastUpdateTime > 0 {
            let dt = currentTime - lastUpdateTime
            if dt > 0 && dt < 0.1 {
                paddle1Velocity = CGVector(
                    dx: (paddle1.position.x - paddle1PrevPos.x) / CGFloat(dt),
                    dy: (paddle1.position.y - paddle1PrevPos.y) / CGFloat(dt)
                )
                paddle2Velocity = CGVector(
                    dx: (paddle2.position.x - paddle2PrevPos.x) / CGFloat(dt),
                    dy: (paddle2.position.y - paddle2PrevPos.y) / CGFloat(dt)
                )
            }
        }
        lastUpdateTime = currentTime
        paddle1PrevPos = paddle1.position
        paddle2PrevPos = paddle2.position

        guard let puckPos = puck?.position, !isGameOver else { return }

        let midX = size.width / 2
        let halfGoal = goalWidth / 2

        // Check if puck went through bottom goal
        if puckPos.y < rinkInset - puckRadius &&
           puckPos.x > midX - halfGoal && puckPos.x < midX + halfGoal {
            score2 += 1
            goalScored()
        }
        // Check if puck went through top goal
        else if puckPos.y > size.height - rinkInset + puckRadius &&
                puckPos.x > midX - halfGoal && puckPos.x < midX + halfGoal {
            score1 += 1
            goalScored()
        }

        // Cap puck speed
        if let velocity = puck.physicsBody?.velocity {
            let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
            let maxSpeed: CGFloat = 800
            if speed > maxSpeed {
                let factor = maxSpeed / speed
                puck.physicsBody?.velocity = CGVector(dx: velocity.dx * factor, dy: velocity.dy * factor)
            }
        }
    }

    private func goalScored() {
        score1Label.text = "\(score1)"
        score2Label.text = "\(score2)"
        gameDelegate?.scoreDidUpdate(player1: score1, player2: score2)
        SoundManager.playScore()
        HapticManager.notification(.success)

        if score1 >= winScore {
            isGameOver = true
            puck.physicsBody?.velocity = .zero
            gameDelegate?.gameDidEnd(winner: 1)
        } else if score2 >= winScore {
            isGameOver = true
            puck.physicsBody?.velocity = .zero
            gameDelegate?.gameDidEnd(winner: 2)
        } else {
            resetPuck()
        }
    }

    private func resetPuck() {
        puck.physicsBody?.velocity = .zero
        puck.position = CGPoint(x: size.width / 2, y: size.height / 2)
        paddle1.position = CGPoint(x: size.width / 2, y: size.height * 0.2)
        paddle2.position = CGPoint(x: size.width / 2, y: size.height * 0.8)
    }

    func resetGame() {
        isGameOver = false
        score1 = 0
        score2 = 0
        score1Label.text = "0"
        score2Label.text = "0"
        resetPuck()
        gameDelegate?.scoreDidUpdate(player1: 0, player2: 0)
    }
}
