import GameKit
import SwiftUI

@MainActor
class GameCenterManager: ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var localPlayerName: String = "Player"

    // Leaderboard IDs — configure these in App Store Connect
    enum LeaderboardID: String, CaseIterable {
        case pingPongWins = "com.windsorsoft.TwoPlayerGames.pingpong.wins"
        case airHockeyWins = "com.windsorsoft.TwoPlayerGames.airhockey.wins"
        case ticTacToeWins = "com.windsorsoft.TwoPlayerGames.tictactoe.wins"
        case connectFourWins = "com.windsorsoft.TwoPlayerGames.connectfour.wins"
        case reactionTimeWins = "com.windsorsoft.TwoPlayerGames.reactiontime.wins"
        case simonSaysWins = "com.windsorsoft.TwoPlayerGames.simonsays.wins"
        case tugOfWarWins = "com.windsorsoft.TwoPlayerGames.tugofwar.wins"
        case memoryMatchWins = "com.windsorsoft.TwoPlayerGames.memorymatch.wins"
        case colorConquestWins = "com.windsorsoft.TwoPlayerGames.colorconquest.wins"
        case totalWins = "com.windsorsoft.TwoPlayerGames.total.wins"
    }

    // Achievement IDs
    enum AchievementID: String {
        case firstWin = "com.windsorsoft.TwoPlayerGames.achievement.firstwin"
        case tenWins = "com.windsorsoft.TwoPlayerGames.achievement.tenwins"
        case tryAllGames = "com.windsorsoft.TwoPlayerGames.achievement.tryall"
    }

    private init() {}

    // MARK: - Authentication

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                if let error {
                    print("Game Center auth error: \(error.localizedDescription)")
                    self?.isAuthenticated = false
                    return
                }

                if viewController != nil {
                    // iOS will present the Game Center login UI automatically
                    // when needed — nothing to do here
                    return
                }

                if GKLocalPlayer.local.isAuthenticated {
                    self?.isAuthenticated = true
                    self?.localPlayerName = GKLocalPlayer.local.displayName
                    print("Game Center authenticated: \(GKLocalPlayer.local.displayName)")
                } else {
                    self?.isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Access Point (Game Center dashboard button)

    func showAccessPoint(showHighlights: Bool = false) {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.showHighlights = showHighlights
        GKAccessPoint.shared.isActive = true
    }

    func hideAccessPoint() {
        GKAccessPoint.shared.isActive = false
    }

    // MARK: - Leaderboards

    func reportScore(_ score: Int, leaderboardID: LeaderboardID) {
        guard isAuthenticated else { return }

        Task {
            do {
                try await GKLeaderboard.submitScore(
                    score,
                    context: 0,
                    player: GKLocalPlayer.local,
                    leaderboardIDs: [leaderboardID.rawValue]
                )
                print("Score \(score) submitted to \(leaderboardID.rawValue)")
            } catch {
                print("Failed to submit score: \(error.localizedDescription)")
            }
        }
    }

    func reportWin(for game: GameType) {
        // Increment win counts using UserDefaults as local tracker
        let key = "wins_\(game.leaderboardID.rawValue)"
        let currentWins = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(currentWins, forKey: key)

        reportScore(currentWins, leaderboardID: game.leaderboardID)

        // Also track total wins
        let totalKey = "wins_total"
        let totalWins = UserDefaults.standard.integer(forKey: totalKey) + 1
        UserDefaults.standard.set(totalWins, forKey: totalKey)
        reportScore(totalWins, leaderboardID: .totalWins)

        // Check achievements
        checkAchievements(totalWins: totalWins)
    }

    // MARK: - Achievements

    private func checkAchievements(totalWins: Int) {
        guard isAuthenticated else { return }

        Task {
            // First Win
            if totalWins >= 1 {
                await reportAchievement(.firstWin, percentComplete: 100)
            }

            // Ten Wins
            if totalWins >= 10 {
                await reportAchievement(.tenWins, percentComplete: 100)
            } else {
                await reportAchievement(.tenWins, percentComplete: Double(totalWins) * 10)
            }

            // Try All Games
            let gameTypes: [GameType] = [.pingPong, .airHockey, .ticTacToe, .connectFour, .reactionTime, .simonSays, .tugOfWar, .memoryMatch, .colorConquest]
            let gamesPlayed = gameTypes.filter { game in
                UserDefaults.standard.integer(forKey: "wins_\(game.leaderboardID.rawValue)") > 0
            }.count
            let percent = Double(gamesPlayed) / Double(gameTypes.count) * 100
            await reportAchievement(.tryAllGames, percentComplete: percent)
        }
    }

    private func reportAchievement(_ achievement: AchievementID, percentComplete: Double) async {
        let gkAchievement = GKAchievement(identifier: achievement.rawValue)
        gkAchievement.percentComplete = percentComplete
        gkAchievement.showsCompletionBanner = true

        do {
            try await GKAchievement.report([gkAchievement])
        } catch {
            print("Failed to report achievement: \(error.localizedDescription)")
        }
    }

    // MARK: - Show Game Center Dashboard

    func showDashboard() {
        guard isAuthenticated else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let gcVC = GKGameCenterViewController(state: .default)
        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared
        rootVC.present(gcVC, animated: true)
    }

    func showLeaderboard(_ leaderboardID: LeaderboardID) {
        guard isAuthenticated else { return }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        let gcVC = GKGameCenterViewController(leaderboardID: leaderboardID.rawValue, playerScope: .global, timeScope: .allTime)
        gcVC.gameCenterDelegate = GameCenterDismissHandler.shared
        rootVC.present(gcVC, animated: true)
    }
}

// MARK: - Game Type Extension for Leaderboard Mapping

extension GameCenterManager {
    enum GameType {
        case pingPong, airHockey, ticTacToe, connectFour, reactionTime, simonSays
        case tugOfWar, memoryMatch, colorConquest

        var leaderboardID: LeaderboardID {
            switch self {
            case .pingPong: return .pingPongWins
            case .airHockey: return .airHockeyWins
            case .ticTacToe: return .ticTacToeWins
            case .connectFour: return .connectFourWins
            case .reactionTime: return .reactionTimeWins
            case .simonSays: return .simonSaysWins
            case .tugOfWar: return .tugOfWarWins
            case .memoryMatch: return .memoryMatchWins
            case .colorConquest: return .colorConquestWins
            }
        }
    }
}

// MARK: - Dismiss Handler

class GameCenterDismissHandler: NSObject, GKGameCenterControllerDelegate {
    static let shared = GameCenterDismissHandler()
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
