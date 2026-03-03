import SwiftUI

struct GameCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
}

struct HomeView: View {
    @State private var selectedGame: GameType?

    enum GameType: Identifiable {
        case pingPong, airHockey, ticTacToe
        var id: Self { self }
    }

    private let games = [
        GameCard(
            title: "Ping Pong",
            subtitle: "First to 5 wins",
            icon: "sportscourt",
            gradient: [Color(red: 0.2, green: 0.5, blue: 1.0), Color(red: 0.1, green: 0.3, blue: 0.8)]
        ),
        GameCard(
            title: "Air Hockey",
            subtitle: "First to 7 wins",
            icon: "circle.circle",
            gradient: [Color(red: 1.0, green: 0.3, blue: 0.3), Color(red: 0.8, green: 0.1, blue: 0.2)]
        ),
        GameCard(
            title: "Tic Tac Toe",
            subtitle: "Classic strategy",
            icon: "number",
            gradient: [Color(red: 0.3, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.3)]
        ),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("2 Player Games")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 20)

                        Text("Pick a game and challenge your friend!")
                            .font(.subheadline)
                            .foregroundStyle(.gray)

                        VStack(spacing: 16) {
                            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                                Button {
                                    HapticManager.impact(.light)
                                    switch index {
                                    case 0: selectedGame = .pingPong
                                    case 1: selectedGame = .airHockey
                                    default: selectedGame = .ticTacToe
                                    }
                                } label: {
                                    GameCardView(game: game)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 40)
                }
            }
            .fullScreenCover(item: $selectedGame) { game in
                switch game {
                case .pingPong:
                    PingPongView()
                case .airHockey:
                    AirHockeyView()
                case .ticTacToe:
                    TicTacToeView()
                }
            }
        }
    }
}

struct GameCardView: View {
    let game: GameCard

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: game.gradient,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)

                Image(systemName: game.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(game.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                Text(game.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
