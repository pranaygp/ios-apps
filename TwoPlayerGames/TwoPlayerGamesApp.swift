import SwiftUI
import GameKit

@main
struct TwoPlayerGamesApp: App {
    @State private var showSplash = true
    @StateObject private var gameCenterManager = GameCenterManager.shared
    @StateObject private var sessionTracker = SessionTracker.shared
    @StateObject private var profileManager = PlayerProfileManager.shared
    @StateObject private var statsManager = GameStatsManager.shared
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .preferredColorScheme(.dark)
                    .environmentObject(gameCenterManager)
                    .environmentObject(sessionTracker)
                    .environmentObject(profileManager)
                    .environmentObject(statsManager)
                    .environmentObject(themeManager)

                if showSplash {
                    SplashScreen()
                        .transition(.opacity)
                        .zIndex(1)
                }

                ThemeUnlockToast(
                    themeName: themeManager.unlockedThemeName,
                    isVisible: themeManager.showUnlockToast
                )
                .zIndex(2)
            }
            .animation(.easeOut(duration: 0.5), value: showSplash)
            .onAppear {
                // Authenticate Game Center on launch
                gameCenterManager.authenticate()

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showSplash = false
                }
            }
        }
    }
}

struct SplashScreen: View {
    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            // Subtle background glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.15), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .opacity(glowOpacity)

            VStack(spacing: 10) {
                Text("2 Player")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                    .textCase(.uppercase)
                    .tracking(4)

                Text("Games")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.2).delay(0.3)) {
                glowOpacity = 1.0
            }
        }
    }
}
