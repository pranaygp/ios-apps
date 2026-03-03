import SwiftUI

struct GameCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let gameType: HomeView.GameType
}

struct HomeView: View {
    @State private var selectedGame: GameType?
    @State private var showSettings = false
    @State private var animateCards = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var floatingPhase = false

    enum GameType: Identifiable {
        case pingPong, airHockey, ticTacToe, connectFour, reactionTime, simonSays
        var id: Self { self }
    }

    private let games = [
        GameCard(
            title: "Ping Pong",
            subtitle: "Classic paddle battle",
            icon: "sportscourt",
            gradient: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.1, green: 0.3, blue: 0.85)],
            gameType: .pingPong
        ),
        GameCard(
            title: "Air Hockey",
            subtitle: "Flick and score",
            icon: "circle.circle",
            gradient: [Color(red: 1.0, green: 0.35, blue: 0.35), Color(red: 0.8, green: 0.12, blue: 0.2)],
            gameType: .airHockey
        ),
        GameCard(
            title: "Tic Tac Toe",
            subtitle: "Classic strategy",
            icon: "number",
            gradient: [Color(red: 0.3, green: 0.82, blue: 0.45), Color(red: 0.12, green: 0.62, blue: 0.3)],
            gameType: .ticTacToe
        ),
        GameCard(
            title: "Connect Four",
            subtitle: "Drop to connect",
            icon: "circle.grid.3x3.fill",
            gradient: [Color(red: 1.0, green: 0.7, blue: 0.15), Color(red: 0.9, green: 0.5, blue: 0.05)],
            gameType: .connectFour
        ),
        GameCard(
            title: "Reaction Time",
            subtitle: "Test your reflexes",
            icon: "bolt.fill",
            gradient: [Color(red: 0.8, green: 0.3, blue: 1.0), Color(red: 0.55, green: 0.1, blue: 0.85)],
            gameType: .reactionTime
        ),
        GameCard(
            title: "Simon Says",
            subtitle: "Memory pattern challenge",
            icon: "brain.head.profile",
            gradient: [Color(red: 1.0, green: 0.45, blue: 0.55), Color(red: 0.85, green: 0.2, blue: 0.4)],
            gameType: .simonSays
        ),
    ]

    var body: some View {
        ZStack {
            // Animated gradient background
            backgroundView

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    headerView
                        .padding(.top, 16)

                    // Game cards
                    VStack(spacing: 14) {
                        ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                            Button {
                                HapticManager.impact(.light)
                                SoundManager.playButtonTap()
                                selectedGame = game.gameType
                            } label: {
                                GameCardView(game: game)
                            }
                            .accessibilityLabel("\(game.title): \(game.subtitle)")
                            .buttonStyle(GameCardButtonStyle())
                            .opacity(animateCards ? 1 : 0)
                            .offset(y: animateCards ? (floatingPhase ? -1.5 : 1.5) : 20)
                            .animation(.easeOut(duration: 0.4).delay(Double(index) * 0.08), value: animateCards)
                            .animation(.easeInOut(duration: 2.5 + Double(index) * 0.2).repeatForever(autoreverses: true), value: floatingPhase)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation {
                animateCards = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                floatingPhase = true
            }
            withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                shimmerOffset = 300
            }
        }
        .fullScreenCover(item: $selectedGame) { game in
            gameView(for: game)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var backgroundView: some View {
        ZStack {
            Color(white: 0.06).ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.blue.opacity(0.12), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: -80, y: -200)
                .blur(radius: 20)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.08), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 100, y: 300)
                .blur(radius: 20)
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("2 Player")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(2)

                    Text("Games")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .overlay(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: 80)
                            .offset(x: shimmerOffset)
                            .mask(
                                Text("Games")
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                            )
                        )
                        .clipped()
                }

                Spacer()

                Button {
                    HapticManager.impact(.light)
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Settings")
            }
            .padding(.horizontal, 24)

            Text("Challenge your friend!")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func gameView(for game: GameType) -> some View {
        switch game {
        case .pingPong:
            PingPongView()
        case .airHockey:
            AirHockeyView()
        case .ticTacToe:
            TicTacToeView()
        case .connectFour:
            ConnectFourView()
        case .reactionTime:
            ReactionTimeView()
        case .simonSays:
            SimonSaysView()
        }
    }
}

struct GameCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GameCardView: View {
    let game: GameCard

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: game.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: game.gradient[0].opacity(0.3), radius: 8, y: 2)

                Image(systemName: game.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(game.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)

                Text(game.subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.white.opacity(0.25))
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.5)
        )
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
