import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private let engine = AVAudioEngine()
    private let sampleRate: Double = 44100
    private var isEngineRunning = false

    private init() {
        configureSession()
        startEngine()
    }

    // MARK: - Engine Setup

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: .mixWithOthers)
        try? session.setActive(true)
    }

    private func startEngine() {
        guard !isEngineRunning else { return }
        // Attach a silent mixer so the engine graph is valid
        let mixer = engine.mainMixerNode
        mixer.outputVolume = 1.0
        do {
            try engine.start()
            isEngineRunning = true
        } catch {
            print("SoundManager: engine failed to start: \(error)")
        }
    }

    // MARK: - Public Static API (preserves call-site compatibility)

    static func playHit() {
        guard GameSettings.shared.soundEnabled else { return }
        // Punchy 200Hz thump + 600Hz ping, 100ms
        shared.playTones([
            ToneSegment(frequency: 200, duration: 0.05),
            ToneSegment(frequency: 600, duration: 0.05)
        ])
    }

    static func playScore() {
        guard GameSettings.shared.soundEnabled else { return }
        // Rising two-tone C5→E5, 150ms
        shared.playTones([
            ToneSegment(frequency: 523.25, duration: 0.075),
            ToneSegment(frequency: 659.25, duration: 0.075)
        ])
    }

    static func playWin() {
        guard GameSettings.shared.soundEnabled else { return }
        // Ascending arpeggio C5→E5→G5→C6, 400ms
        shared.playTones([
            ToneSegment(frequency: 523.25, duration: 0.1),
            ToneSegment(frequency: 659.25, duration: 0.1),
            ToneSegment(frequency: 783.99, duration: 0.1),
            ToneSegment(frequency: 1046.50, duration: 0.1)
        ])
    }

    static func playLose() {
        guard GameSettings.shared.soundEnabled else { return }
        // Descending tone G4→C4, 300ms
        shared.playTones([
            ToneSegment(frequency: 392.00, duration: 0.15),
            ToneSegment(frequency: 261.63, duration: 0.15)
        ])
    }

    static func playPlace() {
        guard GameSettings.shared.soundEnabled else { return }
        // Short 800Hz click, 50ms
        shared.playTones([ToneSegment(frequency: 800, duration: 0.05)])
    }

    static func playDraw() {
        guard GameSettings.shared.soundEnabled else { return }
        // Two equal tones, 200ms total
        shared.playTones([
            ToneSegment(frequency: 440, duration: 0.1),
            ToneSegment(frequency: 440, duration: 0.1)
        ])
    }

    static func playCountdown() {
        guard GameSettings.shared.soundEnabled else { return }
        // Short 440Hz beep, 80ms
        shared.playTones([ToneSegment(frequency: 440, duration: 0.08)])
    }

    static func playGo() {
        guard GameSettings.shared.soundEnabled else { return }
        // Higher pitched go signal
        shared.playTones([ToneSegment(frequency: 880, duration: 0.15)])
    }

    static func playDrop() {
        guard GameSettings.shared.soundEnabled else { return }
        // Descending drop sound
        shared.playTones([
            ToneSegment(frequency: 600, duration: 0.05),
            ToneSegment(frequency: 400, duration: 0.05)
        ])
    }

    static func playButtonTap() {
        guard GameSettings.shared.soundEnabled else { return }
        // Soft 600Hz tap, 40ms
        shared.playTones([ToneSegment(frequency: 600, duration: 0.04)])
    }

    static func playSimonTone(index: Int) {
        guard GameSettings.shared.soundEnabled else { return }
        let frequencies: [Double] = [261.63, 329.63, 392.00, 523.25] // C4, E4, G4, C5
        let freq = frequencies[index % frequencies.count]
        shared.playTones([ToneSegment(frequency: freq, duration: 0.3)])
    }

    // MARK: - Synthesis

    private struct ToneSegment {
        let frequency: Double
        let duration: Double
    }

    private func playTones(_ segments: [ToneSegment]) {
        if !isEngineRunning {
            startEngine()
        }
        guard isEngineRunning else { return }

        let sampleRate = self.sampleRate
        let volume = Float(GameSettings.shared.soundVolume)

        // Build the full sample buffer
        var allSamples: [Float] = []
        for seg in segments {
            let frameCount = Int(seg.duration * sampleRate)
            let fadeFrames = min(Int(0.005 * sampleRate), frameCount / 2) // 5ms fade
            for i in 0..<frameCount {
                let phase = 2.0 * Double.pi * seg.frequency * Double(i) / sampleRate
                var sample = Float(sin(phase)) * volume

                // Fade in
                if i < fadeFrames {
                    sample *= Float(i) / Float(fadeFrames)
                }
                // Fade out
                let distFromEnd = frameCount - 1 - i
                if distFromEnd < fadeFrames {
                    sample *= Float(distFromEnd) / Float(fadeFrames)
                }
                allSamples.append(sample)
            }
        }

        let totalFrames = allSamples.count
        var readIndex = 0

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let sourceNode = AVAudioSourceNode { _, _, frameCount, bufferList -> OSStatus in
            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let count = Int(frameCount)
            for frame in 0..<count {
                let value: Float
                if readIndex < totalFrames {
                    value = allSamples[readIndex]
                    readIndex += 1
                } else {
                    value = 0
                }
                for buffer in ablPointer {
                    let buf = buffer.mData?.assumingMemoryBound(to: Float.self)
                    buf?[frame] = value
                }
            }
            return noErr
        }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        // Schedule removal after playback completes
        let playbackDuration = Double(totalFrames) / sampleRate + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + playbackDuration) { [weak self] in
            self?.engine.detach(sourceNode)
        }
    }
}
