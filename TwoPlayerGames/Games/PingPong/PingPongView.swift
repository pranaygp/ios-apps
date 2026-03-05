import SwiftUI
import SpriteKit

struct PingPongView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var gameState = PingPongGameState()
    @State private var isPaused = false

    var body: some View {
        GameTransitionView {
            ZStack {
                Color.black.ignoresSafeArea()

                GeometryReader { geo in
                    SpriteView(scene: gameState.makeScene(size: geo.size))
                }
                .ignoresSafeArea()

                GameOverlay(onBack: { dismiss() }, onPause: {
                    isPaused = true
                    gameState.pauseScene()
                })

                if let winner = gameState.winner {
                    WinnerOverlay(winner: winner, gameType: .pingPong, gameName: "Ping Pong") {
                        gameState.resetGame()
                    } onExit: {
                        dismiss()
                    }
                }

                if isPaused && gameState.winner == nil {
                    PauseOverlay(
                        score1: gameState.score1,
                        score2: gameState.score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: {
                            isPaused = false
                            gameState.resumeScene()
                        },
                        onRestart: {
                            isPaused = false
                            gameState.resetGame()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && gameState.winner == nil {
                isPaused = true
                gameState.pauseScene()
            }
        }
    }
}

class PingPongGameState: ObservableObject, PingPongSceneDelegate {
    @Published var score1 = 0
    @Published var score2 = 0
    @Published var winner: Int?

    private var scene: PingPongScene?

    func makeScene(size: CGSize) -> PingPongScene {
        if let existing = scene { return existing }
        let s = PingPongScene(size: size)
        s.scaleMode = .resizeFill
        s.gameDelegate = self
        scene = s
        return s
    }

    func scoreDidUpdate(player1: Int, player2: Int) {
        DispatchQueue.main.async {
            self.score1 = player1
            self.score2 = player2
        }
    }

    func gameDidEnd(winner: Int) {
        DispatchQueue.main.async {
            self.winner = winner
        }
    }

    func resetGame() {
        winner = nil
        scene?.isPaused = false
        scene?.resetGame()
    }

    func pauseScene() {
        scene?.isPaused = true
    }

    func resumeScene() {
        scene?.isPaused = false
    }
}

#Preview {
    PingPongView()
        .preferredColorScheme(.dark)
}
