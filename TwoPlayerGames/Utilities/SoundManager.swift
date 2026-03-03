import AudioToolbox

enum SoundManager {
    static func playHit() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1104)
    }

    static func playScore() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1016)
    }

    static func playWin() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1335)
    }

    static func playLose() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1073)
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
        AudioServicesPlaySystemSound(1113)
    }

    static func playDrop() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1100)
    }

    static func playButtonTap() {
        guard GameSettings.shared.soundEnabled else { return }
        AudioServicesPlaySystemSound(1123)
    }

    static func playSimonTone(index: Int) {
        guard GameSettings.shared.soundEnabled else { return }
        let sounds: [SystemSoundID] = [1052, 1054, 1109, 1110]
        let id = sounds[index % sounds.count]
        AudioServicesPlaySystemSound(id)
    }
}
