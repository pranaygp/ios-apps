import SwiftUI

/// Tracks Player 1 vs Player 2 wins across all games in a single app session.
/// Resets when the app is force-quit (not persisted to disk).
@MainActor
class SessionTracker: ObservableObject {
    static let shared = SessionTracker()

    @Published var player1Wins = 0
    @Published var player2Wins = 0
    @Published var gamesPlayed = 0
    @Published var winsPerGame: [String: (p1: Int, p2: Int)] = [:]

    private init() {}

    func recordWin(player: Int, gameType: String) {
        gamesPlayed += 1
        if player == 1 {
            player1Wins += 1
        } else {
            player2Wins += 1
        }
        var current = winsPerGame[gameType] ?? (p1: 0, p2: 0)
        if player == 1 {
            current.p1 += 1
        } else {
            current.p2 += 1
        }
        winsPerGame[gameType] = current
    }

    func reset() {
        player1Wins = 0
        player2Wins = 0
        gamesPlayed = 0
        winsPerGame = [:]
    }

    var hasGames: Bool {
        gamesPlayed > 0
    }
}
