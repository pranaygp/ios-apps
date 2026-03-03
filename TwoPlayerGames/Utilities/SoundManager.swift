import AudioToolbox

enum SoundManager {
    static func playHit() {
        AudioServicesPlaySystemSound(1104)
    }

    static func playScore() {
        AudioServicesPlaySystemSound(1025)
    }

    static func playWin() {
        AudioServicesPlaySystemSound(1335)
    }

    static func playPlace() {
        AudioServicesPlaySystemSound(1105)
    }

    static func playDraw() {
        AudioServicesPlaySystemSound(1053)
    }
}
