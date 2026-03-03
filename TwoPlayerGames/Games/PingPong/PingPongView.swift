import SwiftUI
import SpriteKit

struct PingPongView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var gameState = PingPongGameState()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                SpriteView(scene: gameState.makeScene(size: geo.size))
                    .ignoresSafeArea()
            }

            GameOverlay {
                dismiss()
            }

            if let winner = gameState.winner {
                WinnerOverlay(winner: winner) {
                    HapticManager.impact(.medium)
                    gameState.resetGame()
                } onExit: {
                    HapticManager.impact(.light)
                    dismiss()
                }
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
        scene?.resetGame()
    }
}

#Preview {
    PingPongView()
        .preferredColorScheme(.dark)
}
