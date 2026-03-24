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
    @EnvironmentObject var gameCenterManager: GameCenterManager
    @EnvironmentObject var sessionTracker: SessionTracker
    @EnvironmentObject var profileManager: PlayerProfileManager
    @EnvironmentObject var statsManager: GameStatsManager
    @State private var selectedGame: GameType?
    @State private var showSettings = false
    @State private var showSessionDetail = false
    @State private var showPlayerSetup = false
    @State private var showStats = false
    @State private var animateCards = false
    @State private var shimmerOffset: CGFloat = -200
    @State private var floatingPhase = false

    enum GameType: Identifiable {
        case pingPong, airHockey, ticTacToe, connectFour, reactionTime, simonSays
        case tugOfWar, memoryMatch, colorConquest, sonarDuel, dotsAndBoxes, snakeVsSnake, war, battleship, wordChain, mazeRace, rhythmTap, duelDraw, checkers, reversi
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
        GameCard(
            title: "Tug of War",
            subtitle: "Tap fast to pull the rope",
            icon: "figure.strengthtraining.traditional",
            gradient: [Color(red: 0.95, green: 0.55, blue: 0.1), Color(red: 0.8, green: 0.35, blue: 0.0)],
            gameType: .tugOfWar
        ),
        GameCard(
            title: "Memory Match",
            subtitle: "Flip and find pairs",
            icon: "rectangle.on.rectangle",
            gradient: [Color(red: 0.2, green: 0.75, blue: 0.85), Color(red: 0.05, green: 0.5, blue: 0.65)],
            gameType: .memoryMatch
        ),
        GameCard(
            title: "Color Conquest",
            subtitle: "Claim territory before time runs out",
            icon: "square.grid.3x3.topleft.filled",
            gradient: [Color(red: 0.65, green: 0.2, blue: 0.9), Color(red: 0.4, green: 0.05, blue: 0.7)],
            gameType: .colorConquest
        ),
        GameCard(
            title: "Sonar Duel",
            subtitle: "LAN submarine battle",
            icon: "antenna.radiowaves.left.and.right",
            gradient: [Color(red: 0.15, green: 0.7, blue: 0.7), Color(red: 0.04, green: 0.15, blue: 0.35)],
            gameType: .sonarDuel
        ),
        GameCard(
            title: "Dots & Boxes",
            subtitle: "Classic pencil-and-paper strategy",
            icon: "square.grid.3x3",
            gradient: [Color(red: 0.3, green: 0.6, blue: 0.95), Color(red: 0.15, green: 0.35, blue: 0.8)],
            gameType: .dotsAndBoxes
        ),
        GameCard(
            title: "Snake vs Snake",
            subtitle: "Classic arcade duel",
            icon: "arrow.trianglehead.swap",
            gradient: [Color(red: 0.1, green: 0.8, blue: 0.4), Color(red: 0.05, green: 0.55, blue: 0.25)],
            gameType: .snakeVsSnake
        ),
        GameCard(
            title: "War",
            subtitle: "Classic card battle",
            icon: "suit.spade.fill",
            gradient: [Color(red: 0.85, green: 0.65, blue: 0.2), Color(red: 0.7, green: 0.4, blue: 0.1)],
            gameType: .war
        ),
        GameCard(
            title: "Battleship",
            subtitle: "Naval strategy showdown",
            icon: "shield.checkered",
            gradient: [Color(red: 0.1, green: 0.45, blue: 0.65), Color(red: 0.05, green: 0.25, blue: 0.45)],
            gameType: .battleship
        ),
        GameCard(
            title: "Word Chain",
            subtitle: "Fast-paced vocabulary duel",
            icon: "textformat.abc",
            gradient: [Color(red: 0.85, green: 0.65, blue: 0.3), Color(red: 0.7, green: 0.45, blue: 0.15)],
            gameType: .wordChain
        ),
        GameCard(
            title: "Maze Race",
            subtitle: "Navigate the labyrinth",
            icon: "square.grid.3x3.middleright.filled",
            gradient: [Color(red: 0.1, green: 0.75, blue: 0.65), Color(red: 0.05, green: 0.5, blue: 0.45)],
            gameType: .mazeRace
        ),
        GameCard(
            title: "Rhythm Tap",
            subtitle: "Tap to the beat",
            icon: "music.note.list",
            gradient: [Color(red: 0.9, green: 0.2, blue: 0.6), Color(red: 0.6, green: 0.1, blue: 0.5)],
            gameType: .rhythmTap
        ),
        GameCard(
            title: "Duel Draw",
            subtitle: "Draw and guess together",
            icon: "paintbrush.pointed.fill",
            gradient: [Color(red: 0.95, green: 0.4, blue: 0.2), Color(red: 0.85, green: 0.2, blue: 0.4)],
            gameType: .duelDraw
        ),
        GameCard(
            title: "Checkers",
            subtitle: "Classic board strategy",
            icon: "checkerboard.rectangle",
            gradient: [Color(red: 0.65, green: 0.35, blue: 0.15), Color(red: 0.45, green: 0.22, blue: 0.08)],
            gameType: .checkers
        ),
        GameCard(
            title: "Reversi",
            subtitle: "Disc-flipping strategy",
            icon: "circle.bottomhalf.filled",
            gradient: [Color(red: 0.1, green: 0.5, blue: 0.2), Color(red: 0.05, green: 0.3, blue: 0.1)],
            gameType: .reversi
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

                    // Session scoreboard
                    if sessionTracker.hasGames {
                        sessionScoreCard
                            .padding(.horizontal, 20)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

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
        .sheet(isPresented: $showSessionDetail) {
            SessionDetailView()
        }
        .sheet(isPresented: $showPlayerSetup) {
            PlayerSetupView()
                .environmentObject(profileManager)
        }
        .sheet(isPresented: $showStats) {
            StatsView()
                .environmentObject(statsManager)
                .environmentObject(profileManager)
        }
    }

    // MARK: - Session Score Card

    private var sessionScoreCard: some View {
        Button {
            HapticManager.impact(.light)
            showSessionDetail = true
        } label: {
            HStack(spacing: 16) {
                // P1
                VStack(spacing: 2) {
                    Text(profileManager.player1.emoji)
                        .font(.system(size: 14))
                    Text(profileManager.player1.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(sessionTracker.player1Wins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Text("—")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white.opacity(0.25))

                // P2
                VStack(spacing: 2) {
                    Text(profileManager.player2.emoji)
                        .font(.system(size: 14))
                    Text(profileManager.player2.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("\(sessionTracker.player2Wins)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Session")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .textCase(.uppercase)
                        .tracking(1)
                    Text("\(sessionTracker.gamesPlayed) games")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.2))
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .opacity(0.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.red.opacity(0.15)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(GameCardButtonStyle())
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

                HStack(spacing: 10) {
                    // Players button
                    Button {
                        HapticManager.impact(.light)
                        showPlayerSetup = true
                    } label: {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.cyan.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.cyan.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Players")

                    // Stats button
                    Button {
                        HapticManager.impact(.light)
                        showStats = true
                    } label: {
                        Text("📊")
                            .font(.system(size: 20))
                            .frame(width: 44, height: 44)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Statistics")

                    // Game Center button
                    if gameCenterManager.isAuthenticated {
                        Button {
                            HapticManager.impact(.light)
                            gameCenterManager.showDashboard()
                        } label: {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.yellow.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .environment(\.colorScheme, .dark)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.yellow.opacity(0.12), lineWidth: 1)
                                )
                        }
                        .accessibilityLabel("Game Center")
                    }

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
        case .tugOfWar:
            TugOfWarView()
        case .memoryMatch:
            MemoryMatchView()
        case .colorConquest:
            ColorConquestView()
        case .sonarDuel:
            SonarDuelView()
        case .dotsAndBoxes:
            DotsAndBoxesView()
        case .snakeVsSnake:
            SnakeVsSnakeView()
        case .war:
            WarView()
        case .battleship:
            BattleshipView()
        case .wordChain:
            WordChainView()
        case .mazeRace:
            MazeRaceView()
        case .rhythmTap:
            RhythmTapView()
        case .duelDraw:
            DuelDrawView()
        case .checkers:
            CheckersView()
        case .reversi:
            ReversiView()
        }
    }
}

// MARK: - Session Detail View

struct SessionDetailView: View {
    @EnvironmentObject var sessionTracker: SessionTracker
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Overall score
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Text(PlayerProfileManager.shared.emoji(for: 1))
                                .font(.system(size: 20))
                            Text(PlayerProfileManager.shared.name(for: 1))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text("\(sessionTracker.player1Wins)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Text("vs")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        VStack(spacing: 4) {
                            Text(PlayerProfileManager.shared.emoji(for: 2))
                                .font(.system(size: 20))
                            Text(PlayerProfileManager.shared.name(for: 2))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.red)
                            Text("\(sessionTracker.player2Wins)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Session Score")
                }

                // Per-game breakdown
                if !sessionTracker.winsPerGame.isEmpty {
                    Section {
                        ForEach(sessionTracker.winsPerGame.sorted(by: { $0.key < $1.key }), id: \.key) { gameName, wins in
                            HStack {
                                Text(gameName)
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                                HStack(spacing: 12) {
                                    Text("\(wins.p1)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.blue)
                                    Text("—")
                                        .foregroundStyle(.secondary)
                                    Text("\(wins.p2)")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    } header: {
                        Text("Game Breakdown")
                    }
                }

                Section {
                    HStack {
                        Text("Games Played")
                        Spacer()
                        Text("\(sessionTracker.gamesPlayed)")
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        HapticManager.impact(.medium)
                        sessionTracker.reset()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Session")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Session Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
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
        .shimmer()
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
        .environmentObject(GameCenterManager.shared)
        .environmentObject(SessionTracker.shared)
        .environmentObject(PlayerProfileManager.shared)
        .environmentObject(GameStatsManager.shared)
}
