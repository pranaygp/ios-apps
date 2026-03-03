import AudioToolbox

enum SoundManager {
    static func playHit() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    static func playScore() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1025)
    }

    static func playWin() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1335)
    }

    static func playPlace() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1105)
    }

    static func playDraw() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1053)
    }

    static func playCountdown() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1057)
    }

    static func playGo() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1025)
    }

    static func playDrop() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }
}
