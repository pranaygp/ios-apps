import SwiftUI
import GameKit

struct GameOverlay: View {
    let onBack: () -> Void
    var onPause: (() -> Void)? = nil

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    if let onPause {
                        onPause()
                    } else {
                        onBack()
                    }
                }) {
                    Image(systemName: onPause != nil ? "pause.fill" : "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
                .accessibilityLabel(onPause != nil ? "Pause game" : "Close game")
                .padding(16)

                Spacer()
            }
            Spacer()
        }
    }
}

// MARK: - Pause Overlay

struct PauseOverlay: View {
    let score1: Int
    let score2: Int
    let player1Color: Color
    let player2Color: Color
    let onResume: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(showContent ? 0.8 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: showContent)

            VStack(spacing: 24) {
                // Pause icon
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white.opacity(0.6))
                    .scaleEffect(showContent ? 1 : 0.5)

                Text("Paused")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Score display
                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(player1Color)
                            .frame(width: 12, height: 12)
                        Text("P1")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(score1)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Text("—")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white.opacity(0.3))

                    VStack(spacing: 4) {
                        Circle()
                            .fill(player2Color)
                            .frame(width: 12, height: 12)
                        Text("P2")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(score2)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.vertical, 8)

                // Buttons
                VStack(spacing: 10) {
                    Button(action: {
                        HapticManager.impact(.medium)
                        SoundManager.playButtonTap()
                        onResume()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Resume")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        )
                    }
                    .accessibilityLabel("Resume game")

                    Button(action: {
                        HapticManager.impact(.medium)
                        SoundManager.playButtonTap()
                        onRestart()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("Restart")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .accessibilityLabel("Restart game")

                    Button(action: {
                        HapticManager.impact(.light)
                        SoundManager.playButtonTap()
                        onExit()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Exit to Menu")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .accessibilityLabel("Exit to menu")
                }
                .padding(.horizontal, 8)
            }
            .padding(32)
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showContent)
        }
        .onAppear { showContent = true }
    }
}

// MARK: - Frosted Score Banner

struct FrostedScoreBanner: View {
    let player: Int
    let score: Int
    let color: Color
    let isTop: Bool

    @State private var animatedScore: Int = 0
    @State private var scoreScale: CGFloat = 1.0

    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 14, height: 14)
                    .shadow(color: color.opacity(0.5), radius: 4)
                Text("Player \(player)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            Spacer()
            Text("\(animatedScore)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .scaleEffect(scoreScale)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Player \(player) score: \(animatedScore)")
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            ZStack {
                color.opacity(0.08)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(0.5)
            }
        )
        .rotationEffect(isTop ? .degrees(180) : .zero)
        .onAppear { animatedScore = score }
        .onChange(of: score) { _, newVal in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                scoreScale = 1.3
                animatedScore = newVal
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    scoreScale = 1.0
                }
            }
        }
    }
}

// MARK: - Winner Overlay

struct WinnerOverlay: View {
    let winner: Int
    var gameType: GameCenterManager.GameType? = nil
    var gameName: String? = nil
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false
    @State private var trophyBounce = false
    @State private var glowPulse = false
    @State private var textOffset: CGFloat = 30

    private var winnerColor: Color {
        winner == 1 ? .blue : .red
    }

    var body: some View {
        ZStack {
            // Dimmed background with color tint
            ZStack {
                Color.black.opacity(showContent ? 0.8 : 0)
                winnerColor.opacity(showContent ? 0.08 : 0)
            }
            .ignoresSafeArea()
            .animation(.easeOut(duration: 0.4), value: showContent)

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 24) {
                // Trophy with glow
                ZStack {
                    // Glow ring
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [winnerColor.opacity(0.3), winnerColor.opacity(0)],
                                center: .center,
                                startRadius: 10,
                                endRadius: 60
                            )
                        )
                        .frame(width: 120, height: 120)
                        .scaleEffect(glowPulse ? 1.2 : 0.9)
                        .opacity(glowPulse ? 0.8 : 0.4)

                    Text("\u{1F3C6}")
                        .font(.system(size: 64))
                        .scaleEffect(showContent ? 1 : 0.1)
                        .offset(y: trophyBounce ? 0 : -8)
                        .accessibilityLabel("Trophy")
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.5), value: showContent)

                // Winner text
                VStack(spacing: 6) {
                    Text("Player \(winner)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(winnerColor)
                        .textCase(.uppercase)
                        .tracking(2)
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : 10)

                    Text("Wins!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .opacity(showContent ? 1 : 0)
                        .offset(y: showContent ? 0 : textOffset)
                }
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: showContent)

                // Buttons
                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.impact(.medium)
                        onPlayAgain()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("Play Again")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(winnerColor)
                                .shadow(color: winnerColor.opacity(0.4), radius: 8, y: 4)
                        )
                    }
                    .accessibilityLabel("Play Again")

                    Button(action: {
                        HapticManager.impact(.light)
                        onExit()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Home")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .accessibilityLabel("Go to Home")
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.25), value: showContent)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(
                                LinearGradient(
                                    colors: [winnerColor.opacity(0.3), Color.white.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: winnerColor.opacity(0.2), radius: 30, y: 10)
            )
            .scaleEffect(showContent ? 1 : 0.7)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: showContent)
        }
        .onAppear {
            showContent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showConfetti = true
            }
            // Trophy bounce loop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    trophyBounce = true
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            }

            // Report win to Game Center
            if let gameType {
                GameCenterManager.shared.reportWin(for: gameType)
            }

            // Report win to session tracker
            if let gameName {
                SessionTracker.shared.recordWin(player: winner, gameType: gameName)
            }
        }
    }
}

// MARK: - Draw Overlay

struct DrawOverlay: View {
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(showContent ? 0.75 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: showContent)

            VStack(spacing: 24) {
                Text("\u{1F91D}")
                    .font(.system(size: 56))
                    .scaleEffect(showContent ? 1 : 0.3)
                    .accessibilityLabel("Handshake")

                Text("It's a Draw!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.impact(.medium)
                        onPlayAgain()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 14, weight: .bold))
                            Text("Play Again")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.blue)
                        )
                    }

                    Button(action: {
                        HapticManager.impact(.light)
                        onExit()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Home")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showContent)
        }
        .onAppear { showContent = true }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        let x: CGFloat
        let color: Color
        let size: CGFloat
        let delay: Double
        let duration: Double
        let rotation: Double
        let horizontalDrift: CGFloat
        let shape: Int // 0 = rect, 1 = circle, 2 = triangle
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPiece(particle: p, height: geo.size.height)
                }
            }
            .onAppear {
                let colors: [Color] = [
                    .yellow, .blue, .red, .green, .purple, .orange, .pink,
                    .cyan, .mint, Color(red: 1, green: 0.8, blue: 0), Color(red: 1, green: 0.4, blue: 0.7)
                ]
                particles = (0..<60).map { _ in
                    ConfettiParticle(
                        x: CGFloat.random(in: -20...(geo.size.width + 20)),
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 4...10),
                        delay: Double.random(in: 0...0.8),
                        duration: Double.random(in: 1.8...3.5),
                        rotation: Double.random(in: 0...360),
                        horizontalDrift: CGFloat.random(in: -40...40),
                        shape: Int.random(in: 0...2)
                    )
                }
            }
        }
    }
}

struct ConfettiPiece: View {
    let particle: ConfettiView.ConfettiParticle
    let height: CGFloat
    @State private var animate = false

    var body: some View {
        Group {
            switch particle.shape {
            case 0:
                RoundedRectangle(cornerRadius: 1)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 1.5)
            case 1:
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size * 0.8, height: particle.size * 0.8)
            default:
                Triangle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            }
        }
        .shadow(color: particle.color.opacity(0.5), radius: 2)
        .rotationEffect(.degrees(animate ? particle.rotation + 720 : particle.rotation))
        .rotation3DEffect(.degrees(animate ? 360 : 0), axis: (x: 1, y: 0, z: 0))
        .position(
            x: animate ? particle.x + particle.horizontalDrift : particle.x,
            y: animate ? height + 30 : -30
        )
        .opacity(animate ? 0 : 1)
        .onAppear {
            withAnimation(
                .easeIn(duration: particle.duration)
                .delay(particle.delay)
            ) {
                animate = true
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Game Transition Wrapper

struct GameTransitionView<Content: View>: View {
    let content: Content
    @State private var appeared = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(appeared ? 1 : 0.92)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.3), value: appeared)
            .onAppear {
                appeared = true
            }
    }
}
