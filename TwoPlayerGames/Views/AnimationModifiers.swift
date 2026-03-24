import SwiftUI

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.08), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: geo.size.width * phase)
                    .clipped()
                }
                .allowsHitTesting(false)
                .mask(RoundedRectangle(cornerRadius: 18))
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Press Animation Button Style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension View {
    func pressAnimation() -> some View {
        self.buttonStyle(PressButtonStyle())
    }
}

// MARK: - Screen Shake Modifier

struct ScreenShakeModifier: ViewModifier {
    @Binding var trigger: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, newVal in
                guard newVal else { return }
                let duration = 0.04
                withAnimation(.linear(duration: duration)) { offset = -6 }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                    withAnimation(.linear(duration: duration)) { offset = 5 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 2) {
                    withAnimation(.linear(duration: duration)) { offset = -3 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 3) {
                    withAnimation(.linear(duration: duration)) { offset = 2 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + duration * 4) {
                    withAnimation(.spring(response: 0.15, dampingFraction: 0.4)) { offset = 0 }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    trigger = false
                }
            }
    }
}

extension View {
    func screenShake(trigger: Binding<Bool>) -> some View {
        modifier(ScreenShakeModifier(trigger: trigger))
    }
}

// MARK: - Timer Urgency Modifier

struct TimerUrgencyModifier: ViewModifier {
    let timeRemaining: Double
    let threshold: Double
    @State private var pulseScale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .scaleEffect(timeRemaining <= threshold && timeRemaining > 0 ? pulseScale : 1.0)
            .foregroundStyle(
                timeRemaining <= threshold && timeRemaining > 0 ? Color.red : Color.primary
            )
            .onChange(of: Int(timeRemaining)) { oldVal, newVal in
                guard timeRemaining <= threshold, timeRemaining > 0 else { return }
                HapticManager.impact(.light)
                withAnimation(.easeOut(duration: 0.1)) {
                    pulseScale = 1.15
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.4)) {
                        pulseScale = 1.0
                    }
                }
            }
    }
}

extension View {
    func timerUrgency(timeRemaining: Double, threshold: Double = 5.0) -> some View {
        modifier(TimerUrgencyModifier(timeRemaining: timeRemaining, threshold: threshold))
    }
}
