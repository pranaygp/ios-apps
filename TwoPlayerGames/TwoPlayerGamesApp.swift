import SwiftUI

@main
struct TwoPlayerGamesApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
