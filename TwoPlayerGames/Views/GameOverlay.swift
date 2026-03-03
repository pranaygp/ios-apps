import SwiftUI

struct GameOverlay: View {
    let onBack: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    onBack()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .padding(16)

                Spacer()
            }
            Spacer()
        }
    }
}

struct WinnerOverlay: View {
    let winner: Int
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    @State private var showContent = false
    @State private var showConfetti = false

    var body: some View {
        ZStack {
            Color.black.opacity(showContent ? 0.75 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: showContent)

            if showConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            VStack(spacing: 20) {
                Text("🏆")
                    .font(.system(size: 56))
                    .scaleEffect(showContent ? 1 : 0.3)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showContent)

                Text("Player \(winner) Wins!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Button(action: {
                        HapticManager.impact(.medium)
                        onPlayAgain()
                    }) {
                        Text("Play Again")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue)
                            )
                    }

                    Button(action: {
                        HapticManager.impact(.light)
                        onExit()
                    }) {
                        Text("Exit")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showContent)
        }
        .onAppear {
            showContent = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                showConfetti = true
            }
        }
    }
}

// Simple confetti particles
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
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPiece(particle: p, height: geo.size.height)
                }
            }
            .onAppear {
                let colors: [Color] = [.yellow, .blue, .red, .green, .purple, .orange, .pink]
                particles = (0..<30).map { _ in
                    ConfettiParticle(
                        x: CGFloat.random(in: 0...geo.size.width),
                        color: colors.randomElement()!,
                        size: CGFloat.random(in: 4...8),
                        delay: Double.random(in: 0...0.5),
                        duration: Double.random(in: 1.5...3.0),
                        rotation: Double.random(in: 0...360)
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
        RoundedRectangle(cornerRadius: 1)
            .fill(particle.color)
            .frame(width: particle.size, height: particle.size * 1.5)
            .rotationEffect(.degrees(animate ? particle.rotation + 360 : particle.rotation))
            .position(x: particle.x, y: animate ? height + 20 : -20)
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
