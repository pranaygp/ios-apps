import SwiftUI

// MARK: - Note Model

struct RhythmNote: Identifiable {
    let id = UUID()
    let lane: Int // 0, 1, 2
    let spawnTime: TimeInterval
    var progress: CGFloat = 0 // 0 = top, 1 = hit zone
    var hit = false
    var missed = false
}

// MARK: - Hit Result

enum HitResult {
    case perfect, good, miss

    var points: Int {
        switch self {
        case .perfect: return 100
        case .good: return 50
        case .miss: return 0
        }
    }

    var text: String {
        switch self {
        case .perfect: return "PERFECT"
        case .good: return "GOOD"
        case .miss: return "MISS"
        }
    }

    var color: Color {
        switch self {
        case .perfect: return .yellow
        case .good: return .green
        case .miss: return .red
        }
    }
}

// MARK: - Feedback Flash

struct HitFeedback: Identifiable {
    let id = UUID()
    let result: HitResult
    let lane: Int
    let time: TimeInterval
}

// MARK: - Rhythm Tap Engine

@Observable
final class RhythmTapEngine {
    let lanesCount = 3
    let roundDuration: TimeInterval = 60
    let roundsToWin = 2

    // Game state
    var p1Notes: [RhythmNote] = []
    var p2Notes: [RhythmNote] = []
    var p1Score = 0
    var p2Score = 0
    var p1RoundScore = 0
    var p2RoundScore = 0
    var p1Combo = 0
    var p2Combo = 0
    var p1MaxCombo = 0
    var p2MaxCombo = 0
    var currentRound = 1
    var roundTimeRemaining: TimeInterval = 60
    var winner: Int? = nil
    var showResult = false
    var gameStarted = false
    var roundWinner: Int? = nil
    var showRoundBanner = false

    var p1Feedback: [HitFeedback] = []
    var p2Feedback: [HitFeedback] = []

    // Lane flash on tap
    var p1LaneFlash: [Bool] = [false, false, false]
    var p2LaneFlash: [Bool] = [false, false, false]

    // BPM and note generation
    private var baseBPM: Double = 100
    private var currentBPM: Double = 100
    private var elapsedTime: TimeInterval = 0
    private var nextNoteTime: TimeInterval = 0
    private var displayLink: CADisplayLink?
    private var lastFrameTime: TimeInterval = 0

    // Note speed: how many seconds to traverse from top to hit zone
    private var noteTraversalTime: TimeInterval = 2.0

    // Hit windows (in progress units, where 1.0 = at hit zone)
    private let perfectWindow: CGFloat = 0.06
    private let goodWindow: CGFloat = 0.12

    func startGame() {
        p1Score = 0
        p2Score = 0
        currentRound = 1
        winner = nil
        showResult = false
        gameStarted = true
        startRound()
    }

    func startRound() {
        p1Notes = []
        p2Notes = []
        p1RoundScore = 0
        p2RoundScore = 0
        p1Combo = 0
        p2Combo = 0
        p1MaxCombo = 0
        p2MaxCombo = 0
        p1Feedback = []
        p2Feedback = []
        p1LaneFlash = [false, false, false]
        p2LaneFlash = [false, false, false]
        roundWinner = nil
        showRoundBanner = false
        roundTimeRemaining = roundDuration
        elapsedTime = 0
        baseBPM = 100
        currentBPM = 100
        nextNoteTime = 0.5
        noteTraversalTime = 2.0
        lastFrameTime = 0
        startDisplayLink()
    }

    func tapLane(player: Int, lane: Int) {
        guard gameStarted, !showResult, !showRoundBanner else { return }

        // Flash the lane
        if player == 1 {
            p1LaneFlash[lane] = true
        } else {
            p2LaneFlash[lane] = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }
            if player == 1 {
                self.p1LaneFlash[lane] = false
            } else {
                self.p2LaneFlash[lane] = false
            }
        }

        let notes = player == 1 ? p1Notes : p2Notes

        // Find the closest unhit note in this lane near the hit zone
        var bestIndex: Int? = nil
        var bestDistance: CGFloat = .infinity

        for (index, note) in notes.enumerated() {
            guard note.lane == lane, !note.hit, !note.missed else { continue }
            let distance = abs(note.progress - 1.0)
            if distance < bestDistance && distance < goodWindow {
                bestDistance = distance
                bestIndex = index
            }
        }

        if let idx = bestIndex {
            let distance = abs(notes[idx].progress - 1.0)
            let result: HitResult = distance <= perfectWindow ? .perfect : .good

            if player == 1 {
                p1Notes[idx].hit = true
                p1RoundScore += result.points
                if result == .perfect {
                    p1Combo += 1
                    p1RoundScore += min(p1Combo, 10) * 5 // combo bonus
                } else {
                    p1Combo += 1
                }
                p1MaxCombo = max(p1MaxCombo, p1Combo)
                p1Feedback.append(HitFeedback(result: result, lane: lane, time: elapsedTime))
            } else {
                p2Notes[idx].hit = true
                p2RoundScore += result.points
                if result == .perfect {
                    p2Combo += 1
                    p2RoundScore += min(p2Combo, 10) * 5
                } else {
                    p2Combo += 1
                }
                p2MaxCombo = max(p2MaxCombo, p2Combo)
                p2Feedback.append(HitFeedback(result: result, lane: lane, time: elapsedTime))
            }

            if result == .perfect {
                HapticManager.impact(.heavy)
            } else {
                HapticManager.impact(.medium)
            }
            SoundManager.playHit()
        } else {
            // Missed tap - break combo
            if player == 1 {
                p1Combo = 0
            } else {
                p2Combo = 0
            }
            HapticManager.impact(.light)
        }
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] dt in
            Task { @MainActor in
                self?.update(dt: dt)
            }
        }, selector: #selector(DisplayLinkTarget.step))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @MainActor
    private func update(dt: TimeInterval) {
        guard gameStarted, !showResult, !showRoundBanner else { return }

        let frameDt = min(dt, 1.0 / 30.0) // cap at ~30fps minimum
        elapsedTime += frameDt
        roundTimeRemaining = max(0, roundDuration - elapsedTime)

        // Increase BPM over time
        let progress = elapsedTime / roundDuration
        currentBPM = baseBPM + progress * 60 // 100 -> 160 BPM
        noteTraversalTime = max(1.2, 2.0 - progress * 0.8) // 2.0 -> 1.2 seconds

        // Generate notes
        if elapsedTime >= nextNoteTime {
            spawnNote()
            let beatInterval = 60.0 / currentBPM
            nextNoteTime = elapsedTime + beatInterval
        }

        // Update note positions
        let progressPerFrame = CGFloat(frameDt / noteTraversalTime)

        for i in p1Notes.indices {
            if !p1Notes[i].hit && !p1Notes[i].missed {
                p1Notes[i].progress += progressPerFrame
                if p1Notes[i].progress > 1.0 + goodWindow {
                    p1Notes[i].missed = true
                    p1Combo = 0
                    p1Feedback.append(HitFeedback(result: .miss, lane: p1Notes[i].lane, time: elapsedTime))
                }
            }
        }

        for i in p2Notes.indices {
            if !p2Notes[i].hit && !p2Notes[i].missed {
                p2Notes[i].progress += progressPerFrame
                if p2Notes[i].progress > 1.0 + goodWindow {
                    p2Notes[i].missed = true
                    p2Combo = 0
                    p2Feedback.append(HitFeedback(result: .miss, lane: p2Notes[i].lane, time: elapsedTime))
                }
            }
        }

        // Cleanup old notes (well past hit zone)
        p1Notes.removeAll { ($0.hit || $0.missed) && $0.progress > 1.5 }
        p2Notes.removeAll { ($0.hit || $0.missed) && $0.progress > 1.5 }

        // Cleanup old feedback
        p1Feedback.removeAll { elapsedTime - $0.time > 0.8 }
        p2Feedback.removeAll { elapsedTime - $0.time > 0.8 }

        // Check round end
        if roundTimeRemaining <= 0 {
            endRound()
        }
    }

    private func spawnNote() {
        // Generate a note pattern — sometimes single, sometimes double
        let singleLane = Int.random(in: 0..<lanesCount)
        let note1 = RhythmNote(lane: singleLane, spawnTime: elapsedTime)

        // Both players get the same pattern
        p1Notes.append(note1)
        p2Notes.append(RhythmNote(lane: singleLane, spawnTime: elapsedTime))

        // 25% chance of a double note at higher BPMs
        if currentBPM > 120 && Double.random(in: 0...1) < 0.25 {
            var secondLane = Int.random(in: 0..<lanesCount)
            while secondLane == singleLane {
                secondLane = Int.random(in: 0..<lanesCount)
            }
            p1Notes.append(RhythmNote(lane: secondLane, spawnTime: elapsedTime))
            p2Notes.append(RhythmNote(lane: secondLane, spawnTime: elapsedTime))
        }
    }

    private func endRound() {
        displayLink?.invalidate()
        displayLink = nil

        let p1Wins = p1RoundScore > p2RoundScore
        let tie = p1RoundScore == p2RoundScore

        if tie {
            // In case of tie, higher combo wins; if still tie, both get a point
            if p1MaxCombo > p2MaxCombo {
                roundWinner = 1
                p1Score += 1
            } else if p2MaxCombo > p1MaxCombo {
                roundWinner = 2
                p2Score += 1
            } else {
                // True tie — no one scores, replay round
                roundWinner = nil
            }
        } else {
            roundWinner = p1Wins ? 1 : 2
            if p1Wins {
                p1Score += 1
            } else {
                p2Score += 1
            }
        }

        SoundManager.playScore()
        HapticManager.impact(.medium)

        if p1Score >= roundsToWin || p2Score >= roundsToWin {
            winner = p1Score >= roundsToWin ? 1 : 2
            SoundManager.playWin()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
                gameStarted = false
                showResult = true
            }
        } else {
            showRoundBanner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                showRoundBanner = false
                currentRound += 1
                startRound()
            }
        }
    }

    func pause() {
        displayLink?.invalidate()
        displayLink = nil
    }

    func resume() {
        guard gameStarted, !showResult else { return }
        startDisplayLink()
    }

    func cleanup() {
        displayLink?.invalidate()
        displayLink = nil
    }

    var formattedTime: String {
        let seconds = Int(roundTimeRemaining)
        return "\(seconds)s"
    }
}

// MARK: - CADisplayLink Target

private class DisplayLinkTarget {
    let callback: (TimeInterval) -> Void
    private var lastTimestamp: TimeInterval = 0

    init(callback: @escaping (TimeInterval) -> Void) {
        self.callback = callback
    }

    @objc func step(link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
        }
        let dt = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        callback(dt)
    }
}

// MARK: - Lane Colors

private let laneColors: [Color] = [
    Color(red: 1.0, green: 0.2, blue: 0.5),  // pink/magenta
    Color(red: 0.2, green: 0.8, blue: 1.0),   // cyan
    Color(red: 0.4, green: 1.0, blue: 0.3),   // green
]

// MARK: - Rhythm Tap View

struct RhythmTapView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = RhythmTapEngine()
    @State private var isPaused = false
    @State private var showTutorial = false
    @AppStorage("hasSeenRhythmTapTutorial") private var hasSeenTutorial = false

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.04).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score banner (top, rotated for face-to-face)
                    FrostedScoreBanner(player: 2, score: engine.p2Score, color: .red, isTop: true)
                        .rotationEffect(.degrees(180))

                    // Player 1 half (top, rotated 180)
                    playerLanesView(player: 1)
                        .rotationEffect(.degrees(180))

                    // Center divider
                    centerDivider

                    // Player 2 half (bottom, normal)
                    playerLanesView(player: 2)

                    // Player 1 score banner (bottom)
                    FrostedScoreBanner(player: 1, score: engine.p1Score, color: .blue, isTop: false)
                }

                // Round winner banner
                if engine.showRoundBanner {
                    roundBannerOverlay
                }

                GameOverlay(onBack: {
                    engine.cleanup()
                    dismiss()
                }, onPause: {
                    engine.pause()
                    isPaused = true
                })

                if !showTutorial && !isPaused && !engine.showResult {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .rhythmTap) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if engine.showResult {
                    if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameType: .rhythmTap, gameName: "Rhythm Tap") {
                            engine.startGame()
                        } onExit: {
                            engine.cleanup()
                            dismiss()
                        }
                    }
                }

                if isPaused && !engine.showResult {
                    PauseOverlay(
                        score1: engine.p1Score,
                        score2: engine.p2Score,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: {
                            isPaused = false
                            engine.resume()
                        },
                        onRestart: {
                            isPaused = false
                            engine.startGame()
                        },
                        onExit: {
                            engine.cleanup()
                            dismiss()
                        }
                    )
                }
            }
        }
        .onAppear {
            engine.startGame()
            if !hasSeenTutorial {
                showTutorial = true
                engine.pause()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !engine.showResult {
                engine.pause()
                isPaused = true
            }
        }
        .onChange(of: showTutorial) { _, showing in
            if !showing {
                engine.resume()
            }
        }
    }

    // MARK: - Player Lanes View

    private func playerLanesView(player: Int) -> some View {
        GeometryReader { geo in
            let notes = player == 1 ? engine.p1Notes : engine.p2Notes
            let feedback = player == 1 ? engine.p1Feedback : engine.p2Feedback
            let combo = player == 1 ? engine.p1Combo : engine.p2Combo
            let roundScore = player == 1 ? engine.p1RoundScore : engine.p2RoundScore
            let laneFlash = player == 1 ? engine.p1LaneFlash : engine.p2LaneFlash
            let laneWidth = geo.size.width / CGFloat(engine.lanesCount)
            let hitZoneY = geo.size.height * 0.85

            ZStack {
                // Lane backgrounds
                ForEach(0..<engine.lanesCount, id: \.self) { lane in
                    let xCenter = CGFloat(lane) * laneWidth + laneWidth / 2

                    // Lane stripe
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    laneColors[lane].opacity(laneFlash[lane] ? 0.2 : 0.05),
                                    laneColors[lane].opacity(laneFlash[lane] ? 0.15 : 0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: laneWidth - 4)
                        .position(x: xCenter, y: geo.size.height / 2)

                    // Lane divider lines
                    if lane > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 1, height: geo.size.height)
                            .position(x: CGFloat(lane) * laneWidth, y: geo.size.height / 2)
                    }
                }

                // Hit zone line
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .position(x: geo.size.width / 2, y: hitZoneY)

                // Hit zone targets
                ForEach(0..<engine.lanesCount, id: \.self) { lane in
                    let xCenter = CGFloat(lane) * laneWidth + laneWidth / 2
                    let isFlashing = laneFlash[lane]

                    Circle()
                        .stroke(laneColors[lane].opacity(isFlashing ? 0.8 : 0.3), lineWidth: 2)
                        .frame(width: laneWidth * 0.55, height: laneWidth * 0.55)
                        .background(
                            Circle()
                                .fill(laneColors[lane].opacity(isFlashing ? 0.2 : 0.05))
                        )
                        .position(x: xCenter, y: hitZoneY)
                }

                // Falling notes
                ForEach(notes) { note in
                    if !note.hit && !note.missed {
                        let xCenter = CGFloat(note.lane) * laneWidth + laneWidth / 2
                        let noteY = note.progress * hitZoneY
                        let noteSize = laneWidth * 0.45

                        ZStack {
                            // Glow
                            Circle()
                                .fill(laneColors[note.lane].opacity(0.3))
                                .frame(width: noteSize * 1.4, height: noteSize * 1.4)
                                .blur(radius: 4)

                            // Note body
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [laneColors[note.lane], laneColors[note.lane].opacity(0.7)],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: noteSize / 2
                                    )
                                )
                                .frame(width: noteSize, height: noteSize)
                                .shadow(color: laneColors[note.lane].opacity(0.5), radius: 6)
                        }
                        .position(x: xCenter, y: noteY)
                    }
                }

                // Hit feedback text
                ForEach(feedback) { fb in
                    let xCenter = CGFloat(fb.lane) * laneWidth + laneWidth / 2

                    Text(fb.result.text)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(fb.result.color)
                        .shadow(color: fb.result.color.opacity(0.6), radius: 4)
                        .position(x: xCenter, y: hitZoneY - 30)
                        .transition(.opacity.combined(with: .scale))
                }

                // Combo & score HUD
                VStack(spacing: 2) {
                    if combo >= 3 {
                        Text("\(combo)x COMBO")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(.yellow)
                            .shadow(color: .yellow.opacity(0.5), radius: 4)
                    }
                    Text("\(roundScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .position(x: geo.size.width / 2, y: 20)
            }
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        let lane = Int(value.location.x / laneWidth)
                        let clampedLane = max(0, min(engine.lanesCount - 1, lane))
                        engine.tapLane(player: player, lane: clampedLane)
                    }
            )
        }
    }

    // MARK: - Center Divider

    private var centerDivider: some View {
        HStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text("R\(engine.currentRound)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 8)

            Text(engine.formattedTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.3))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .padding(.horizontal, 16)
        .frame(height: 28)
    }

    // MARK: - Round Banner

    private var roundBannerOverlay: some View {
        let bannerColor: Color = {
            if let rw = engine.roundWinner {
                return rw == 1 ? .blue : .red
            }
            return .gray
        }()
        let bannerText: String = {
            if let rw = engine.roundWinner {
                return "Player \(rw)"
            }
            return "Tie!"
        }()

        return VStack(spacing: 6) {
            Text(bannerText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(bannerColor)
                .textCase(.uppercase)
                .tracking(1.5)

            Text("Round \(engine.currentRound) Complete!")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("P1")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text("\(engine.p1RoundScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("vs")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                VStack(spacing: 2) {
                    Text("P2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.red.opacity(0.7))
                    Text("\(engine.p2RoundScore)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(bannerColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: bannerColor.opacity(0.2), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.showRoundBanner)
    }
}

// MARK: - Battleship View (exists elsewhere; ensure no naming collision)

#Preview {
    RhythmTapView()
        .preferredColorScheme(.dark)
}
