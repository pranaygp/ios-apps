import SpriteKit
import UIKit
import CoreImage

protocol PingPongSceneDelegate: AnyObject {
    func scoreDidUpdate(player1: Int, player2: Int)
    func gameDidEnd(winner: Int)
}

class PingPongScene: SKScene, SKPhysicsContactDelegate {
    weak var gameDelegate: PingPongSceneDelegate?

    private var paddle1: SKShapeNode!  // bottom
    private var paddle2: SKShapeNode!  // top
    private var ball: SKShapeNode!
    private var score1Label: SKLabelNode!
    private var score2Label: SKLabelNode!
    private var centerLine: SKShapeNode!

    private var score1 = 0
    private var score2 = 0
    private let winScore = 5
    private var isGameOver = false

    private var paddle1Touch: UITouch?
    private var paddle2Touch: UITouch?

    private let paddleWidth: CGFloat = 100
    private let paddleHeight: CGFloat = 16
    private let ballRadius: CGFloat = 10
    private let paddleCornerRadius: CGFloat = 8
    private let initialBallSpeed: CGFloat = 400

    struct PhysicsCategory {
        static let ball: UInt32 = 0x1 << 0
        static let paddle: UInt32 = 0x1 << 1
        static let wall: UInt32 = 0x1 << 2
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        physicsWorld.contactDelegate = self
        physicsWorld.gravity = .zero
        view.isMultipleTouchEnabled = true

        setupWalls()
        setupCenterLine()
        setupPaddles()
        setupBall()
        setupScoreLabels()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.launchBall()
        }
    }

    private func setupWalls() {
        // Only left and right walls — top and bottom are open for scoring
        let leftNode = SKNode()
        leftNode.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: size.height))
        leftNode.physicsBody?.categoryBitMask = PhysicsCategory.wall
        leftNode.physicsBody?.friction = 0
        leftNode.physicsBody?.restitution = 1
        addChild(leftNode)

        let rightNode = SKNode()
        rightNode.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: size.width, y: 0), to: CGPoint(x: size.width, y: size.height))
        rightNode.physicsBody?.categoryBitMask = PhysicsCategory.wall
        rightNode.physicsBody?.friction = 0
        rightNode.physicsBody?.restitution = 1
        addChild(rightNode)
    }

    private func setupCenterLine() {
        let path = CGMutablePath()
        let dashLength: CGFloat = 10
        let gapLength: CGFloat = 8
        var x: CGFloat = 0
        while x < size.width {
            path.move(to: CGPoint(x: x, y: size.height / 2))
            path.addLine(to: CGPoint(x: min(x + dashLength, size.width), y: size.height / 2))
            x += dashLength + gapLength
        }
        centerLine = SKShapeNode(path: path)
        centerLine.strokeColor = .white.withAlphaComponent(0.15)
        centerLine.lineWidth = 2
        centerLine.zPosition = -1
        addChild(centerLine)
    }

    private func setupPaddles() {
        let paddleSize = CGSize(width: paddleWidth, height: paddleHeight)

        paddle1 = SKShapeNode(rectOf: paddleSize, cornerRadius: paddleCornerRadius)
        paddle1.fillColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
        paddle1.strokeColor = .clear
        paddle1.position = CGPoint(x: size.width / 2, y: 60)
        paddle1.physicsBody = SKPhysicsBody(rectangleOf: paddleSize)
        paddle1.physicsBody?.isDynamic = false
        paddle1.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle1.physicsBody?.friction = 0
        paddle1.physicsBody?.restitution = 1
        addChild(paddle1)

        paddle2 = SKShapeNode(rectOf: paddleSize, cornerRadius: paddleCornerRadius)
        paddle2.fillColor = UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)
        paddle2.strokeColor = .clear
        paddle2.position = CGPoint(x: size.width / 2, y: size.height - 60)
        paddle2.physicsBody = SKPhysicsBody(rectangleOf: paddleSize)
        paddle2.physicsBody?.isDynamic = false
        paddle2.physicsBody?.categoryBitMask = PhysicsCategory.paddle
        paddle2.physicsBody?.friction = 0
        paddle2.physicsBody?.restitution = 1
        addChild(paddle2)
    }

    private func setupBall() {
        ball = SKShapeNode(circleOfRadius: ballRadius)
        ball.fillColor = .white
        ball.strokeColor = .clear
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)

        let glow = SKEffectNode()
        glow.shouldRasterize = true
        glow.filter = CIFilter(name: "CIGaussianBlur", parameters: ["inputRadius": 6.0])
        let glowCircle = SKShapeNode(circleOfRadius: ballRadius + 2)
        glowCircle.fillColor = .white.withAlphaComponent(0.3)
        glowCircle.strokeColor = .clear
        glow.addChild(glowCircle)
        ball.addChild(glow)

        ball.physicsBody = SKPhysicsBody(circleOfRadius: ballRadius)
        ball.physicsBody?.isDynamic = true
        ball.physicsBody?.friction = 0
        ball.physicsBody?.restitution = 1
        ball.physicsBody?.linearDamping = 0
        ball.physicsBody?.angularDamping = 0
        ball.physicsBody?.allowsRotation = false
        ball.physicsBody?.categoryBitMask = PhysicsCategory.ball
        ball.physicsBody?.contactTestBitMask = PhysicsCategory.paddle | PhysicsCategory.wall
        ball.physicsBody?.collisionBitMask = PhysicsCategory.paddle | PhysicsCategory.wall
        addChild(ball)
    }

    private func setupScoreLabels() {
        score1Label = SKLabelNode(fontNamed: "Helvetica Neue")
        score1Label.text = "0"
        score1Label.fontSize = 48
        score1Label.fontColor = .white.withAlphaComponent(0.15)
        score1Label.position = CGPoint(x: size.width / 2, y: size.height * 0.25 - 20)
        score1Label.zPosition = -1
        addChild(score1Label)

        score2Label = SKLabelNode(fontNamed: "Helvetica Neue")
        score2Label.text = "0"
        score2Label.fontSize = 48
        score2Label.fontColor = .white.withAlphaComponent(0.15)
        score2Label.position = CGPoint(x: size.width / 2, y: size.height * 0.75 - 20)
        score2Label.zPosition = -1
        addChild(score2Label)
    }

    private func launchBall() {
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ball.physicsBody?.velocity = .zero

        let angle = CGFloat.random(in: -CGFloat.pi / 4...CGFloat.pi / 4)
        let direction: CGFloat = Bool.random() ? 1 : -1
        let dx = sin(angle) * initialBallSpeed
        let dy = direction * cos(angle) * initialBallSpeed

        ball.physicsBody?.velocity = CGVector(dx: dx, dy: dy)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if location.y < size.height / 2 && paddle1Touch == nil {
                paddle1Touch = touch
                movePaddle(paddle1, toX: location.x)
            } else if location.y >= size.height / 2 && paddle2Touch == nil {
                paddle2Touch = touch
                movePaddle(paddle2, toX: location.x)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if touch == paddle1Touch {
                movePaddle(paddle1, toX: location.x)
            } else if touch == paddle2Touch {
                movePaddle(paddle2, toX: location.x)
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

    private func movePaddle(_ paddle: SKShapeNode, toX x: CGFloat) {
        let halfWidth = paddleWidth / 2
        let clampedX = max(halfWidth, min(size.width - halfWidth, x))
        paddle.position.x = clampedX
    }

    // MARK: - Physics Contact

    func didBegin(_ contact: SKPhysicsContact) {
        let bodies = [contact.bodyA.categoryBitMask, contact.bodyB.categoryBitMask]
        if bodies.contains(PhysicsCategory.ball) && bodies.contains(PhysicsCategory.paddle) {
            SoundManager.playHit()
            HapticManager.impact(.light)

            // Add slight speed increase
            if let velocity = ball.physicsBody?.velocity {
                let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
                let maxSpeed: CGFloat = 700
                if speed < maxSpeed {
                    let factor: CGFloat = 1.05
                    ball.physicsBody?.velocity = CGVector(dx: velocity.dx * factor, dy: velocity.dy * factor)
                }
            }
        }
    }

    // MARK: - Game Update

    override func update(_ currentTime: TimeInterval) {
        guard let ballY = ball?.position.y, !isGameOver else { return }

        // Ensure minimum vertical velocity so ball doesn't go purely horizontal
        if let velocity = ball.physicsBody?.velocity {
            let minVertical: CGFloat = 150
            if abs(velocity.dy) < minVertical && (abs(velocity.dx) > 1 || abs(velocity.dy) > 1) {
                let sign: CGFloat = velocity.dy >= 0 ? 1 : -1
                ball.physicsBody?.velocity.dy = sign * minVertical
            }
        }

        // Check scoring
        if ballY < -ballRadius {
            score2 += 1
            updateScores()
            SoundManager.playScore()
            HapticManager.notification(.success)
            checkWin()
        } else if ballY > size.height + ballRadius {
            score1 += 1
            updateScores()
            SoundManager.playScore()
            HapticManager.notification(.success)
            checkWin()
        }
    }

    private func updateScores() {
        score1Label.text = "\(score1)"
        score2Label.text = "\(score2)"
        gameDelegate?.scoreDidUpdate(player1: score1, player2: score2)

        ball.physicsBody?.velocity = .zero
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func checkWin() {
        if score1 >= winScore {
            isGameOver = true
            ball.physicsBody?.velocity = .zero
            gameDelegate?.gameDidEnd(winner: 1)
        } else if score2 >= winScore {
            isGameOver = true
            ball.physicsBody?.velocity = .zero
            gameDelegate?.gameDidEnd(winner: 2)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self, !self.isGameOver else { return }
                self.launchBall()
            }
        }
    }

    func resetGame() {
        isGameOver = false
        score1 = 0
        score2 = 0
        score1Label.text = "0"
        score2Label.text = "0"
        ball.position = CGPoint(x: size.width / 2, y: size.height / 2)
        ball.physicsBody?.velocity = .zero
        paddle1.position.x = size.width / 2
        paddle2.position.x = size.width / 2
        gameDelegate?.scoreDidUpdate(player1: 0, player2: 0)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.launchBall()
        }
    }
}
