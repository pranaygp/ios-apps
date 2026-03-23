import SwiftUI

struct PlayerProfile: Codable, Equatable {
    var name: String
    var emoji: String

    static let defaultPlayer1 = PlayerProfile(name: "Player 1", emoji: "🦊")
    static let defaultPlayer2 = PlayerProfile(name: "Player 2", emoji: "🐼")

    static let availableEmojis = ["🦊", "🐼", "🦁", "🐸", "🦋", "🐙", "🦀", "🐲", "🦄", "🐺", "🦅", "🐯"]
}

@MainActor
class PlayerProfileManager: ObservableObject {
    static let shared = PlayerProfileManager()

    @Published var player1: PlayerProfile {
        didSet { save() }
    }
    @Published var player2: PlayerProfile {
        didSet { save() }
    }

    private let key1 = "playerProfile1"
    private let key2 = "playerProfile2"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key1),
           let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            player1 = profile
        } else {
            player1 = .defaultPlayer1
        }
        if let data = UserDefaults.standard.data(forKey: key2),
           let profile = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            player2 = profile
        } else {
            player2 = .defaultPlayer2
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(player1) {
            UserDefaults.standard.set(data, forKey: key1)
        }
        if let data = try? JSONEncoder().encode(player2) {
            UserDefaults.standard.set(data, forKey: key2)
        }
    }

    func name(for player: Int) -> String {
        player == 1 ? player1.name : player2.name
    }

    func emoji(for player: Int) -> String {
        player == 1 ? player1.emoji : player2.emoji
    }
}
