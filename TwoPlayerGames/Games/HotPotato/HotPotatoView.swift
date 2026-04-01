import SwiftUI

// MARK: - Hot Potato View

struct HotPotatoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var themeManager: ThemeManager

    // MARK: - Game State

    @State private var score1 = 0
    @State private var score2 = 0
    @State private var gameWinner: Int?
    @State private var roundActive = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var showCountdown = true
    @State private var countdown: Int = 3
    @State private var showRoundResult = false
    @State private var roundLoser: Int?
    @State private var showExplosion = false
    @State private var shakeScreen = false
    @AppStorage("hasSeenTutorial_HotPotato") private var hasSeenTutorial = false

    // MARK: - Bomb State

    /// 0.0 = fully on P2 side (top), 1.0 = fully on P1 side (bottom), 0.5 = center
    @State private var bombPosition: CGFloat = 0.5
    @State private var bombWobble: Double = 0
    @State private var bombScale: CGFloat = 1.0
    @State private var fuseGlow: CGFloat = 0.5
    @State private var edgeGlowOpacity: CGFloat = 0
    @State private var sparkParticles: [SparkParticle] = []

    // MARK: - Timer State

    @State private var roundTimer: Timer?
    @State private var tickTimer: Timer?
    @State private var roundTimeRemaining: Double = 0
    @State private var roundDuration: Double = 0
    @State private var tickInterval: Double = 0.6
    @State private var currentRound: Int = 0

    // MARK: - Tap Flash

    @State private var p1Flash = false
    @State private var p2Flash = false

    // MARK: - Constants

    private let winScore = 5
    private let bombPassAmount: CGFloat = 0.15
    private let bombDecay: CGFloat = 0.02

    var body: some View {
        GameTransitionView {
            ZStack {
                themeManager.currentTheme.backgroundColor.ignoresSafeArea()

                // Edge glow (danger indicator)
                edgeGlowView

                VStack(spacing: 0) {
                    // Player 2 tap zone (top, inverted)
                    tapZone(player: 2)
                        .rotationEffect(.degrees(180))

                    // Bomb area
                    bombAreaView

                    // Player 1 tap zone (bottom)
                    tapZone(player: 1)
                }

                // Countdown overlay
                if showCountdown {
                    countdownOverlay
                }

                // Explosion overlay
                if showExplosion {
                    explosionOverlay
                }

                // Round result
                if showRoundResult, let loser = roundLoser {
                    roundResultOverlay(loser: loser)
                }

                GameOverlay(onBack: { dismiss() }, onPause: {
                    isPaused = true
                    stopTimers()
                })

                if !showTutorial && !isPaused && gameWinner == nil {
                    TutorialInfoButton {
                        showTutorial = true
                        stopTimers()
                    }
                }

                if showTutorial {
                    TutorialOverlayView(content: .hotPotato) {
                        showTutorial = false
                        hasSeenTutorial = true
                        if !isPaused && gameWinner == nil { startCountdown() }
                    }
                }

                if let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameName: "Hot Potato") {
                        resetGame()
                    } onExit: {
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
                            startCountdown()
                        },
                        onRestart: {
                            isPaused = false
                            resetGame()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
            .screenShake(trigger: $shakeScreen)
            .onAppear {
                if !hasSeenTutorial {
                    showTutorial = true
                } else {
                    startCountdown()
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && gameWinner == nil {
                isPaused = true
                stopTimers()
            }
        }
    }

    // MARK: - Edge Glow

    private var edgeGlowView: some View {
        ZStack {
            // Top edge glow
            VStack {
                LinearGradient(
                    colors: [Color.red.opacity(edgeGlowOpacity), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .ignoresSafeArea()
                Spacer()
            }
            // Bottom edge glow
            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.red.opacity(edgeGlowOpacity)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 80)
                .ignoresSafeArea()
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Tap Zone

    private func tapZone(player: Int) -> some View {
        let score = player == 1 ? score1 : score2
        let isFlashing = player == 1 ? p1Flash : p2Flash
        let color: Color = player == 1 ? .blue : .red

        return Button {
            handleTap(player: player)
        } label: {
            ZStack {
                color.opacity(isFlashing ? 0.25 : 0.06)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.08), value: isFlashing)

                VStack(spacing: 12) {
                    Text(PlayerProfileManager.shared.name(for: player))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())

                    if roundActive {
                        Text("TAP!")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundStyle(color)
                            .opacity(0.8)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!roundActive || isPaused)
        .accessibilityLabel("Player \(player) zone, score \(score)")
    }

    // MARK: - Bomb Area

    private var bombAreaView: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let bombY = height * bombPosition

            ZStack {
                // Track background
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)

                // Danger zone indicators
                VStack {
                    Rectangle()
                        .fill(Color.red.opacity(0.1))
                        .frame(height: 20)
                    Spacer()
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(height: 20)
                }

                // Center line
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: geo.size.width * 0.6, height: 1)
                    .position(x: geo.size.width / 2, y: height / 2)

                // Spark particles
                ForEach(sparkParticles) { spark in
                    Circle()
                        .fill(spark.color)
                        .frame(width: spark.size, height: spark.size)
                        .position(x: geo.size.width / 2 + spark.offsetX, y: bombY + spark.offsetY)
                        .opacity(spark.opacity)
                }

                // Bomb
                bombView
                    .position(x: geo.size.width / 2, y: bombY)
                    .animation(.interpolatingSpring(stiffness: 200, damping: 15), value: bombPosition)
            }
        }
        .frame(height: 200)
    }

    private var bombView: some View {
        let urgency = roundDuration > 0 ? 1.0 - (roundTimeRemaining / roundDuration) : 0

        return ZStack {
            // Glow behind bomb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.orange.opacity(0.3 + urgency * 0.4),
                            Color.red.opacity(0.1 + urgency * 0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 50 + urgency * 20
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(fuseGlow > 0.5 ? 1.1 : 0.9)

            // Bomb body
            ZStack {
                // Main bomb circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(white: 0.25), Color(white: 0.08)],
                            center: .init(x: 0.35, y: 0.3),
                            startRadius: 0,
                            endRadius: 35
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.3), lineWidth: 2)
                    )

                // Fuse
                Path { path in
                    path.move(to: CGPoint(x: 0, y: -30))
                    path.addQuadCurve(
                        to: CGPoint(x: 8, y: -42),
                        control: CGPoint(x: 12, y: -34)
                    )
                }
                .stroke(Color(red: 0.5, green: 0.35, blue: 0.15), lineWidth: 3)

                // Fuse spark
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, .yellow, .orange, .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 8 + urgency * 6
                        )
                    )
                    .frame(width: 16 + urgency * 12, height: 16 + urgency * 12)
                    .offset(x: 8, y: -42)
                    .opacity(fuseGlow)

                // Highlight
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 16, height: 14)
                    .offset(x: -10, y: -12)

                // Bomb emoji overlay for extra visual fun
                Text("\u{1F4A3}")
                    .font(.system(size: 44))
                    .opacity(0.0) // hidden, using custom drawing above
            }
            .scaleEffect(bombScale)
            .rotationEffect(.degrees(bombWobble))
        }
    }

    // MARK: - Countdown

    private var countdownOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            Text(countdown > 0 ? "\(countdown)" : "GO!")
                .font(.system(size: 80, weight: .heavy, design: .rounded))
                .foregroundStyle(countdown > 0 ? .white : .green)
                .scaleEffect(countdown > 0 ? 1.0 : 1.3)
                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: countdown)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Explosion Overlay

    private var explosionOverlay: some View {
        ZStack {
            Color.orange.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 12) {
                Text("BOOM!")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .orange, radius: 20)
                    .shadow(color: .red.opacity(0.5), radius: 40)
                    .scaleEffect(showExplosion ? 1.0 : 0.1)
                    .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showExplosion)
            }

            // Explosion particles
            ForEach(0..<20, id: \.self) { i in
                ExplosionParticle(index: i, trigger: showExplosion)
            }
        }
    }

    // MARK: - Round Result

    private func roundResultOverlay(loser: Int) -> some View {
        let winner = loser == 1 ? 2 : 1
        return ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            VStack(spacing: 8) {
                Text(PlayerProfileManager.shared.name(for: winner))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(winner == 1 ? Color.blue : Color.red)
                    .textCase(.uppercase)
                    .tracking(2)
                Text("Wins the Round!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    // MARK: - Countdown Logic

    private func startCountdown() {
        showCountdown = true
        countdown = 3
        bombPosition = 0.5
        roundActive = false
        showRoundResult = false
        roundLoser = nil
        showExplosion = false
        bombWobble = 0
        bombScale = 1.0
        edgeGlowOpacity = 0
        sparkParticles = []

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
                        startRound()
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            tick()
        }
    }

    // MARK: - Round Logic

    private func startRound() {
        currentRound += 1
        roundActive = true

        // Random duration: starts 3-8s, shrinks by round (min 2-5s by round 9+)
        let minTime = max(2.0, 3.0 - Double(currentRound - 1) * 0.125)
        let maxTime = max(5.0, 8.0 - Double(currentRound - 1) * 0.375)
        roundDuration = Double.random(in: minTime...maxTime)
        roundTimeRemaining = roundDuration

        // Push bomb randomly toward one player to start
        let startPush: CGFloat = CGFloat.random(in: 0.08...0.15)
        bombPosition = Bool.random() ? (0.5 + startPush) : (0.5 - startPush)

        // Start ticking
        startTickTimer()

        // Start countdown to explosion
        startRoundTimer()

        // Start bomb animation
        startBombAnimations()
    }

    private func startRoundTimer() {
        roundTimer?.invalidate()
        let startTime = Date()
        roundTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            roundTimeRemaining = max(0, roundDuration - elapsed)

            // Update urgency effects
            let urgency = 1.0 - (roundTimeRemaining / roundDuration)

            // Edge glow intensifies
            withAnimation(.easeOut(duration: 0.1)) {
                edgeGlowOpacity = max(0, urgency - 0.3) * 0.5
            }

            // Bomb wobble increases
            let wobbleAmount = urgency * 8
            bombWobble = Double.random(in: -wobbleAmount...wobbleAmount)

            // Bomb scale pulses faster as time runs out
            let pulseSpeed = 0.3 + (1.0 - urgency) * 0.4
            withAnimation(.easeInOut(duration: pulseSpeed)) {
                bombScale = urgency > 0.5 ? CGFloat.random(in: 0.95...1.1) : 1.0
            }

            // Fuse glow
            fuseGlow = 0.5 + urgency * 0.5

            // Spawn sparks near the end
            if urgency > 0.6 && Int.random(in: 0...3) == 0 {
                spawnSpark()
            }

            if roundTimeRemaining <= 0 {
                explode()
            }
        }
    }

    private func startTickTimer() {
        tickTimer?.invalidate()
        tickInterval = 0.6
        scheduleTick()
    }

    private func scheduleTick() {
        guard roundActive else { return }
        tickTimer?.invalidate()

        // Tick interval decreases as time runs out
        let urgency = roundDuration > 0 ? 1.0 - (roundTimeRemaining / roundDuration) : 0
        tickInterval = max(0.1, 0.6 - urgency * 0.45)

        tickTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: false) { _ in
            guard self.roundActive else { return }
            SoundManager.playPlace() // tick sound
            if urgency > 0.7 {
                HapticManager.impact(.light)
            }
            self.scheduleTick()
        }
    }

    private func stopTimers() {
        roundActive = false
        roundTimer?.invalidate()
        roundTimer = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func startBombAnimations() {
        // Continuous fuse glow animation
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            fuseGlow = 1.0
        }
    }

    private func spawnSpark() {
        let spark = SparkParticle(
            id: UUID(),
            offsetX: CGFloat.random(in: -30...30),
            offsetY: CGFloat.random(in: -30...10),
            size: CGFloat.random(in: 2...5),
            color: [Color.yellow, Color.orange, Color.red].randomElement()!,
            opacity: 1.0
        )
        sparkParticles.append(spark)

        // Fade out and remove
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let idx = sparkParticles.firstIndex(where: { $0.id == spark.id }) {
                sparkParticles[idx].opacity = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sparkParticles.removeAll { $0.id == spark.id }
        }
    }

    // MARK: - Game Logic

    private func handleTap(player: Int) {
        guard roundActive, !isPaused else { return }

        HapticManager.impact(.light)
        SoundManager.playHit()

        // Pass bomb away from tapping player
        if player == 1 {
            // Player 1 (bottom, position=1.0 side) pushes bomb toward P2 (top, position=0.0)
            bombPosition = max(0.0, bombPosition - bombPassAmount)
            p1Flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { p1Flash = false }
        } else {
            // Player 2 (top, position=0.0 side) pushes bomb toward P1 (bottom, position=1.0)
            bombPosition = min(1.0, bombPosition + bombPassAmount)
            p2Flash = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { p2Flash = false }
        }
    }

    private func explode() {
        stopTimers()

        // Determine who loses — bomb is on their side
        // bombPosition > 0.5 means closer to P1 (bottom), < 0.5 means closer to P2 (top)
        let loser = bombPosition >= 0.5 ? 1 : 2
        let winner = loser == 1 ? 2 : 1
        roundLoser = loser

        // Explosion effects
        showExplosion = true
        shakeScreen = true
        HapticManager.notification(.error)
        SoundManager.playLose()

        // After explosion, show round result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showExplosion = false

            if winner == 1 { score1 += 1 } else { score2 += 1 }
            SoundManager.playScore()

            showRoundResult = true

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                showRoundResult = false

                if score1 >= winScore {
                    gameWinner = 1
                    SoundManager.playWin()
                } else if score2 >= winScore {
                    gameWinner = 2
                    SoundManager.playWin()
                } else {
                    startCountdown()
                }
            }
        }
    }

    private func resetGame() {
        score1 = 0
        score2 = 0
        gameWinner = nil
        currentRound = 0
        stopTimers()
        startCountdown()
    }
}

// MARK: - Spark Particle

struct SparkParticle: Identifiable {
    let id: UUID
    var offsetX: CGFloat
    var offsetY: CGFloat
    var size: CGFloat
    var color: Color
    var opacity: Double
}

// MARK: - Explosion Particle

struct ExplosionParticle: View {
    let index: Int
    let trigger: Bool
    @State private var animate = false

    var body: some View {
        let angle = Double(index) / 20.0 * 360.0
        let distance: CGFloat = CGFloat.random(in: 80...180)
        let colors: [Color] = [.yellow, .orange, .red, .white]
        let color = colors[index % colors.count]

        Circle()
            .fill(color)
            .frame(width: CGFloat.random(in: 6...14), height: CGFloat.random(in: 6...14))
            .offset(
                x: animate ? cos(angle * .pi / 180) * distance : 0,
                y: animate ? sin(angle * .pi / 180) * distance : 0
            )
            .opacity(animate ? 0 : 1)
            .scaleEffect(animate ? 0.3 : 1.5)
            .onAppear {
                withAnimation(.easeOut(duration: Double.random(in: 0.5...1.0))) {
                    animate = true
                }
            }
    }
}

#Preview {
    HotPotatoView()
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager.shared)
}
