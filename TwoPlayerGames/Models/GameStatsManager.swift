import SwiftUI

struct GameRecord: Codable {
    var gamesPlayed: Int = 0
    var p1Wins: Int = 0
    var p2Wins: Int = 0
    var draws: Int = 0
    var currentStreakPlayer: Int = 0
    var currentStreak: Int = 0
    var bestStreakPlayer: Int = 0
    var bestStreak: Int = 0
}

@MainActor
class GameStatsManager: ObservableObject {
    static let shared = GameStatsManager()

    @Published var stats: [String: GameRecord] = [:]

    private let storageKey = "gameStats"

    private init() {
        load()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([String: GameRecord].self, from: data) {
            stats = decoded
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func recordWin(player: Int, game: String) {
        var record = stats[game] ?? GameRecord()
        record.gamesPlayed += 1
        if player == 1 {
            record.p1Wins += 1
        } else {
            record.p2Wins += 1
        }
        if record.currentStreakPlayer == player {
            record.currentStreak += 1
        } else {
            record.currentStreakPlayer = player
            record.currentStreak = 1
        }
        if record.currentStreak > record.bestStreak {
            record.bestStreak = record.currentStreak
            record.bestStreakPlayer = player
        }
        stats[game] = record
        save()
    }

    func recordDraw(game: String) {
        var record = stats[game] ?? GameRecord()
        record.gamesPlayed += 1
        record.draws += 1
        record.currentStreakPlayer = 0
        record.currentStreak = 0
        stats[game] = record
        save()
    }

    func reset() {
        stats = [:]
        save()
    }

    var totalGamesPlayed: Int { stats.values.reduce(0) { $0 + $1.gamesPlayed } }
    var totalP1Wins: Int { stats.values.reduce(0) { $0 + $1.p1Wins } }
    var totalP2Wins: Int { stats.values.reduce(0) { $0 + $1.p2Wins } }
    var totalDraws: Int { stats.values.reduce(0) { $0 + $1.draws } }

    var overallBestStreak: (player: Int, count: Int) {
        var best = 0
        var bestPlayer = 0
        for record in stats.values {
            if record.bestStreak > best {
                best = record.bestStreak
                bestPlayer = record.bestStreakPlayer
            }
        }
        return (bestPlayer, best)
    }
}
