import SwiftUI

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let unlockThreshold: Int
    let primaryColor: Color
    let secondaryColor: Color
    let accentColor: Color
    let backgroundColor: Color
    let cardBackground: Color
    let textColor: Color
}

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    static let allThemes: [AppTheme] = [
        AppTheme(
            id: "classic", name: "Classic", unlockThreshold: 0,
            primaryColor: .blue,
            secondaryColor: .purple,
            accentColor: .cyan,
            backgroundColor: Color(white: 0.06),
            cardBackground: Color.white.opacity(0.03),
            textColor: .white
        ),
        AppTheme(
            id: "midnight", name: "Midnight", unlockThreshold: 5,
            primaryColor: Color(red: 0.15, green: 0.2, blue: 0.6),
            secondaryColor: Color(red: 0.1, green: 0.12, blue: 0.35),
            accentColor: Color(red: 0.4, green: 0.5, blue: 1.0),
            backgroundColor: Color(red: 0.03, green: 0.03, blue: 0.1),
            cardBackground: Color(red: 0.08, green: 0.08, blue: 0.2),
            textColor: Color(red: 0.85, green: 0.88, blue: 1.0)
        ),
        AppTheme(
            id: "neon", name: "Neon", unlockThreshold: 15,
            primaryColor: Color(red: 1.0, green: 0.1, blue: 0.6),
            secondaryColor: Color(red: 0.0, green: 1.0, blue: 0.8),
            accentColor: Color(red: 0.4, green: 1.0, blue: 0.2),
            backgroundColor: Color(red: 0.02, green: 0.02, blue: 0.05),
            cardBackground: Color(red: 0.06, green: 0.06, blue: 0.1),
            textColor: .white
        ),
        AppTheme(
            id: "retro", name: "Retro", unlockThreshold: 30,
            primaryColor: Color(red: 0.9, green: 0.65, blue: 0.2),
            secondaryColor: Color(red: 0.7, green: 0.4, blue: 0.15),
            accentColor: Color(red: 1.0, green: 0.8, blue: 0.3),
            backgroundColor: Color(red: 0.08, green: 0.06, blue: 0.04),
            cardBackground: Color(red: 0.14, green: 0.1, blue: 0.06),
            textColor: Color(red: 1.0, green: 0.95, blue: 0.85)
        ),
        AppTheme(
            id: "ocean", name: "Ocean", unlockThreshold: 50,
            primaryColor: Color(red: 0.0, green: 0.7, blue: 0.7),
            secondaryColor: Color(red: 0.1, green: 0.5, blue: 0.6),
            accentColor: Color(red: 0.4, green: 0.9, blue: 0.8),
            backgroundColor: Color(red: 0.02, green: 0.06, blue: 0.08),
            cardBackground: Color(red: 0.04, green: 0.1, blue: 0.14),
            textColor: Color(red: 0.85, green: 0.98, blue: 1.0)
        ),
        AppTheme(
            id: "sunset", name: "Sunset", unlockThreshold: 75,
            primaryColor: Color(red: 1.0, green: 0.45, blue: 0.35),
            secondaryColor: Color(red: 0.6, green: 0.2, blue: 0.7),
            accentColor: Color(red: 1.0, green: 0.8, blue: 0.3),
            backgroundColor: Color(red: 0.08, green: 0.03, blue: 0.06),
            cardBackground: Color(red: 0.15, green: 0.06, blue: 0.1),
            textColor: Color(red: 1.0, green: 0.93, blue: 0.9)
        ),
    ]

    @AppStorage("selectedTheme") private var selectedThemeID: String = "classic"
    @AppStorage("unlockedThemes") private var unlockedThemesRaw: String = "classic"

    @Published var currentTheme: AppTheme
    @Published var showUnlockToast = false
    @Published var unlockedThemeName = ""

    private init() {
        currentTheme = ThemeManager.allThemes[0]
        // Load selected theme
        if let theme = ThemeManager.allThemes.first(where: { $0.id == selectedThemeID }) {
            currentTheme = theme
        }
    }

    var unlockedThemeIDs: Set<String> {
        Set(unlockedThemesRaw.split(separator: ",").map(String.init))
    }

    func isUnlocked(_ theme: AppTheme) -> Bool {
        unlockedThemeIDs.contains(theme.id)
    }

    func selectTheme(_ theme: AppTheme) {
        guard isUnlocked(theme) else { return }
        selectedThemeID = theme.id
        currentTheme = theme
    }

    func gamesNeededToUnlock(_ theme: AppTheme) -> Int {
        let played = GameStatsManager.shared.totalGamesPlayed
        return max(0, theme.unlockThreshold - played)
    }

    /// Call after a game ends to check for newly unlocked themes
    func checkForUnlocks() {
        let played = GameStatsManager.shared.totalGamesPlayed
        var ids = unlockedThemeIDs

        for theme in ThemeManager.allThemes {
            if played >= theme.unlockThreshold && !ids.contains(theme.id) {
                ids.insert(theme.id)
                // Show toast for the newly unlocked theme
                unlockedThemeName = theme.name
                showUnlockToast = true

                // Auto-dismiss after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.showUnlockToast = false
                }
            }
        }

        unlockedThemesRaw = ids.sorted().joined(separator: ",")
    }
}
