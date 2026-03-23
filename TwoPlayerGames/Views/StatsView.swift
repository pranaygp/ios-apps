import SwiftUI

struct StatsView: View {
    @EnvironmentObject var statsManager: GameStatsManager
    @EnvironmentObject var profileManager: PlayerProfileManager
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false

    private let gameOrder = [
        "Ping Pong", "Air Hockey", "Tic Tac Toe", "Connect Four",
        "Reaction Time", "Simon Says", "Tug of War", "Memory Match",
        "Color Conquest", "Sonar Duel", "Dots & Boxes", "Snake vs Snake",
        "War", "Battleship", "Word Chain", "Maze Race",
        "Rhythm Tap", "Duel Draw", "Checkers", "Reversi"
    ]

    private let gameIcons: [String: String] = [
        "Ping Pong": "sportscourt",
        "Air Hockey": "circle.circle",
        "Tic Tac Toe": "number",
        "Connect Four": "circle.grid.3x3.fill",
        "Reaction Time": "bolt.fill",
        "Simon Says": "brain.head.profile",
        "Tug of War": "figure.strengthtraining.traditional",
        "Memory Match": "rectangle.on.rectangle",
        "Color Conquest": "square.grid.3x3.topleft.filled",
        "Sonar Duel": "antenna.radiowaves.left.and.right",
        "Dots & Boxes": "square.grid.3x3",
        "Snake vs Snake": "arrow.trianglehead.swap",
        "War": "suit.spade.fill",
        "Battleship": "shield.checkered",
        "Word Chain": "textformat.abc",
        "Maze Race": "square.grid.3x3.middleright.filled",
        "Rhythm Tap": "music.note.list",
        "Duel Draw": "paintbrush.pointed.fill",
        "Checkers": "checkerboard.rectangle",
        "Reversi": "circle.bottomhalf.filled"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    overallStatsCard
                    winRatioBar
                    streakCard
                    perGameList
                    resetButton
                }
                .padding(20)
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset All Stats?", isPresented: $showResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    statsManager.reset()
                }
            } message: {
                Text("This will permanently delete all game statistics. This cannot be undone.")
            }
        }
    }

    // MARK: - Overall Stats

    private var overallStatsCard: some View {
        HStack(spacing: 0) {
            statBox(
                value: "\(statsManager.totalGamesPlayed)",
                label: "Played",
                color: .white
            )
            statBox(
                value: "\(statsManager.totalP1Wins)",
                label: profileManager.player1.name,
                color: .blue
            )
            statBox(
                value: "\(statsManager.totalP2Wins)",
                label: profileManager.player2.name,
                color: .red
            )
            statBox(
                value: "\(statsManager.totalDraws)",
                label: "Draws",
                color: .gray
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func statBox(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Win Ratio Bar

    private var winRatioBar: some View {
        let p1 = statsManager.totalP1Wins
        let p2 = statsManager.totalP2Wins
        let total = max(p1 + p2, 1)
        let p1Ratio = CGFloat(p1) / CGFloat(total)

        return VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text(profileManager.player1.emoji)
                        .font(.system(size: 16))
                    Text(profileManager.player1.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                Spacer()
                HStack(spacing: 6) {
                    Text(profileManager.player2.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(profileManager.player2.emoji)
                        .font(.system(size: 16))
                }
            }

            GeometryReader { geo in
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue)
                        .frame(width: max(geo.size.width * p1Ratio - 1, 0))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.red)
                }
            }
            .frame(height: 12)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Text("\(p1) wins")
                    .font(.system(size: 12))
                    .foregroundStyle(.blue.opacity(0.7))
                Spacer()
                Text("\(p2) wins")
                    .font(.system(size: 12))
                    .foregroundStyle(.red.opacity(0.7))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
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

    // MARK: - Streak

    private var streakCard: some View {
        let best = statsManager.overallBestStreak
        return HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("🔥")
                    .font(.system(size: 24))
                Text("Best Streak")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                if best.count > 0 {
                    Text("\(best.count) by \(profileManager.name(for: best.player))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.orange)
                } else {
                    Text("—")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Per-Game List

    private var perGameList: some View {
        VStack(spacing: 0) {
            ForEach(gameOrder, id: \.self) { game in
                let record = statsManager.stats[game] ?? GameRecord()
                HStack(spacing: 12) {
                    Image(systemName: gameIcons[game] ?? "gamecontroller")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28)

                    Text(game)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    if record.gamesPlayed > 0 {
                        HStack(spacing: 8) {
                            Text("\(record.p1Wins)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.blue)
                            Text("-")
                                .foregroundStyle(.white.opacity(0.3))
                            Text("\(record.p2Wins)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.red)
                            if record.draws > 0 {
                                Text("-")
                                    .foregroundStyle(.white.opacity(0.3))
                                Text("\(record.draws)")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(.gray)
                            }
                        }
                    } else {
                        Text("—")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if game != gameOrder.last {
                    Divider()
                        .overlay(Color.white.opacity(0.05))
                        .padding(.leading, 56)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Reset

    private var resetButton: some View {
        Button {
            HapticManager.impact(.medium)
            showResetConfirmation = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("Reset All Stats")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.red.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.red.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}
