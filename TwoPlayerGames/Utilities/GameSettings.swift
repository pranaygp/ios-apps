import SwiftUI

class GameSettings: ObservableObject {
    static let shared = GameSettings()

    @AppStorage("soundEnabled") var soundEnabled = true
    @AppStorage("hapticsEnabled") var hapticsEnabled = true
    @AppStorage("pingPongWinScore") var pingPongWinScore = 5
    @AppStorage("airHockeyWinScore") var airHockeyWinScore = 7
    @AppStorage("ticTacToeWinScore") var ticTacToeWinScore = 3
    @AppStorage("connectFourWinScore") var connectFourWinScore = 3
    @AppStorage("reactionTimeWinScore") var reactionTimeWinScore = 5
    @AppStorage("pongBallSpeed") var pongBallSpeed = 1 // 0=slow, 1=normal, 2=fast

    var pongInitialSpeed: CGFloat {
        switch pongBallSpeed {
        case 0: return 300
        case 2: return 500
        default: return 400
        }
    }
}
