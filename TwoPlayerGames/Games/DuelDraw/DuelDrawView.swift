import SwiftUI

// MARK: - Drawing Stroke

struct DrawingStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    let color: Color
    let lineWidth: CGFloat
    let isEraser: Bool
}

// MARK: - Guess Entry

struct GuessEntry: Identifiable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
    let player: Int
}

// MARK: - Word Bank

struct WordBank {
    static let words: [String] = [
        "cat", "dog", "house", "tree", "sun", "moon", "star", "car", "bus", "boat",
        "fish", "bird", "flower", "apple", "banana", "pizza", "cake", "hat", "shoe", "book",
        "clock", "chair", "table", "lamp", "door", "key", "heart", "crown", "flag", "bell",
        "guitar", "drum", "piano", "robot", "rocket", "airplane", "train", "bicycle", "balloon", "kite",
        "mountain", "river", "cloud", "rain", "snow", "fire", "lightning", "rainbow", "bridge", "castle",
        "sword", "shield", "diamond", "ring", "ghost", "skull", "spider", "butterfly", "turtle", "snake",
        "elephant", "giraffe", "penguin", "whale", "octopus", "crab", "frog", "bear", "lion", "monkey",
        "ice cream", "hamburger", "hot dog", "donut", "candy", "cookie", "popcorn", "cheese", "egg", "bread",
        "camera", "phone", "computer", "television", "umbrella", "glasses", "candle", "scissors", "pencil", "envelope",
        "snowman", "pumpkin", "present", "trophy", "medal", "anchor", "compass", "telescope", "volcano", "island"
    ]
}

// MARK: - Duel Draw Engine

@Observable
final class DuelDrawEngine {
    // Game state
    var currentRound = 1
    let totalRounds = 8
    var score1 = 0
    var score2 = 0
    var drawer = 1 // which player is drawing
    var guesser: Int { drawer == 1 ? 2 : 1 }
    var secretWord = ""
    var gameStarted = false
    var showResult = false
    var winner: Int? = nil
    var roundPhase: RoundPhase = .drawing
    var showRoundTransition = false
    var transitionMessage = ""

    // Drawing state
    var strokes: [DrawingStroke] = []
    var currentStroke: DrawingStroke? = nil
    var selectedColor: Color = .black
    var selectedLineWidth: CGFloat = 4.0
    var isErasing = false

    // Guessing state
    var guessText = ""
    var guesses: [GuessEntry] = []
    var roundCorrect = false

    // Timer
    var timeRemaining: Double = 30.0
    let roundTime: Double = 30.0
    private var timer: Timer?

    // Used words tracker
    private var usedWords: Set<String> = []

    // Color palette
    let colors: [(Color, String)] = [
        (.black, "Black"),
        (.red, "Red"),
        (.blue, "Blue"),
        (.green, "Green"),
        (.orange, "Orange"),
        (.purple, "Purple")
    ]

    let brushSizes: [(CGFloat, String)] = [
        (3.0, "Thin"),
        (6.0, "Medium"),
        (10.0, "Thick")
    ]

    enum RoundPhase {
        case drawing
        case revealed // time ran out
        case correct  // guesser got it
    }

    func startGame() {
        score1 = 0
        score2 = 0
        currentRound = 1
        drawer = 1
        winner = nil
        showResult = false
        usedWords = []
        gameStarted = true
        startRound()
    }

    func startRound() {
        // Pick a random unused word
        let available = WordBank.words.filter { !usedWords.contains($0) }
        secretWord = available.randomElement() ?? WordBank.words.randomElement()!
        usedWords.insert(secretWord)

        strokes = []
        currentStroke = nil
        guesses = []
        guessText = ""
        roundCorrect = false
        roundPhase = .drawing
        selectedColor = .black
        selectedLineWidth = 4.0
        isErasing = false
        showRoundTransition = false
        timeRemaining = roundTime
        startTimer()
    }

    func submitGuess() {
        let guess = guessText.trimmingCharacters(in: .whitespaces).lowercased()
        guessText = ""
        guard !guess.isEmpty else { return }

        let isCorrect = guess == secretWord.lowercased()
        guesses.append(GuessEntry(text: guess, isCorrect: isCorrect, player: guesser))

        if isCorrect {
            roundCorrect = true
            roundPhase = .correct
            timer?.invalidate()

            // Calculate score: 1 base point + time bonus (up to 2 extra)
            let timeBonus = Int((timeRemaining / roundTime) * 2)
            let points = 1 + timeBonus

            if guesser == 1 {
                score1 += points
            } else {
                score2 += points
            }

            SoundManager.playScore()
            HapticManager.notification(.success)

            // Advance after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [self] in
                advanceRound()
            }
        } else {
            HapticManager.notification(.error)
            SoundManager.playHit()
        }
    }

    func beginStroke(at point: CGPoint) {
        guard roundPhase == .drawing else { return }
        let stroke = DrawingStroke(
            points: [point],
            color: isErasing ? Color(white: 1.0) : selectedColor,
            lineWidth: isErasing ? 20.0 : selectedLineWidth,
            isEraser: isErasing
        )
        currentStroke = stroke
    }

    func continueStroke(to point: CGPoint) {
        currentStroke?.points.append(point)
    }

    func endStroke() {
        if let stroke = currentStroke {
            strokes.append(stroke)
            currentStroke = nil
        }
    }

    func clearCanvas() {
        strokes = []
        currentStroke = nil
        HapticManager.impact(.medium)
    }

    private func timeUp() {
        timer?.invalidate()
        roundPhase = .revealed
        HapticManager.notification(.error)
        SoundManager.playLose()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            advanceRound()
        }
    }

    private func advanceRound() {
        if currentRound >= totalRounds {
            // Game over
            if score1 > score2 {
                winner = 1
            } else if score2 > score1 {
                winner = 2
            } else {
                winner = nil // draw
            }
            gameStarted = false
            SoundManager.playWin()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                showResult = true
            }
        } else {
            // Show transition
            currentRound += 1
            drawer = drawer == 1 ? 2 : 1
            showRoundTransition = true
            transitionMessage = "Round \(currentRound) of \(totalRounds)"

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [self] in
                showRoundTransition = false
                startRound()
            }
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.gameStarted, self.roundPhase == .drawing else {
                    self?.timer?.invalidate()
                    return
                }
                self.timeRemaining -= 0.05
                // Haptic tick in last 5 seconds
                if self.timeRemaining <= 5 && self.timeRemaining > 0 {
                    let rounded = self.timeRemaining + 0.025
                    if rounded.truncatingRemainder(dividingBy: 1.0) < 0.08 {
                        HapticManager.impact(.light)
                    }
                }
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.timeUp()
                }
            }
        }
    }

    var timerFraction: Double {
        max(0, timeRemaining / roundTime)
    }

    var timerColor: Color {
        if timerFraction > 0.5 { return .green }
        if timerFraction > 0.25 { return .yellow }
        return .red
    }

    func pause() {
        timer?.invalidate()
    }

    func resume() {
        guard gameStarted, roundPhase == .drawing else { return }
        startTimer()
    }

    func cleanup() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Duel Draw View

struct DuelDrawView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = DuelDrawEngine()
    @State private var isPaused = false
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial_DuelDraw") private var hasSeenTutorial = false
    @FocusState private var isGuessFocused: Bool

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top score banner (P2, rotated for face-to-face)
                    FrostedScoreBanner(player: 2, score: engine.score2, color: .red, isTop: true)
                        .rotationEffect(.degrees(180))

                    // Player 1 half (top, rotated 180 for face-to-face)
                    playerHalf(player: 1)
                        .rotationEffect(.degrees(180))

                    // Center divider
                    centerDivider

                    // Player 2 half (bottom, normal)
                    playerHalf(player: 2)

                    // Bottom score banner (P1)
                    FrostedScoreBanner(player: 1, score: engine.score1, color: .blue, isTop: false)
                }

                // Round transition
                if engine.showRoundTransition {
                    roundTransitionOverlay
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
                    TutorialOverlayView(content: .duelDraw) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if engine.showResult {
                    if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameType: .duelDraw, gameName: "Duel Draw") {
                            engine.startGame()
                        } onExit: {
                            engine.cleanup()
                            dismiss()
                        }
                    } else {
                        DrawOverlay(gameName: "Duel Draw", onPlayAgain: {
                            engine.startGame()
                        }, onExit: {
                            engine.cleanup()
                            dismiss()
                        })
                    }
                }

                if isPaused && !engine.showResult {
                    PauseOverlay(
                        score1: engine.score1,
                        score2: engine.score2,
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

    // MARK: - Player Half

    @ViewBuilder
    private func playerHalf(player: Int) -> some View {
        let isDrawer = engine.drawer == player

        GeometryReader { geo in
            VStack(spacing: 0) {
                if isDrawer {
                    drawerView(player: player, size: geo.size)
                } else {
                    guesserView(player: player, size: geo.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Drawer View

    private func drawerView(player: Int, size: CGSize) -> some View {
        VStack(spacing: 6) {
            // Secret word display
            HStack(spacing: 8) {
                Text("Draw:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(engine.secretWord.uppercased())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow)
                    .shadow(color: .yellow.opacity(0.3), radius: 4)
            }
            .padding(.top, 6)

            // Canvas
            let canvasSize = min(size.width - 16, size.height - 90)
            drawingCanvas(size: canvasSize)
                .frame(width: canvasSize, height: canvasSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 8)

            // Toolbar
            drawerToolbar
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Drawing Canvas

    private func drawingCanvas(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            // White background
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.white)
            )

            // Draw all completed strokes
            for stroke in engine.strokes {
                drawStroke(stroke, in: &context)
            }

            // Draw current (in-progress) stroke
            if let current = engine.currentStroke {
                drawStroke(current, in: &context)
            }

            // Round result overlays
            if engine.roundPhase == .correct {
                let rect = CGRect(origin: .zero, size: canvasSize)
                context.fill(Path(rect), with: .color(.green.opacity(0.15)))
            } else if engine.roundPhase == .revealed {
                let rect = CGRect(origin: .zero, size: canvasSize)
                context.fill(Path(rect), with: .color(.red.opacity(0.15)))
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let point = value.location
                    // Clamp to canvas bounds
                    let clamped = CGPoint(
                        x: max(0, min(size, point.x)),
                        y: max(0, min(size, point.y))
                    )
                    if engine.currentStroke == nil {
                        engine.beginStroke(at: clamped)
                    } else {
                        engine.continueStroke(to: clamped)
                    }
                }
                .onEnded { _ in
                    engine.endStroke()
                }
        )
        .allowsHitTesting(engine.roundPhase == .drawing)
    }

    private func drawStroke(_ stroke: DrawingStroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else {
            // Single point — draw a dot
            if let point = stroke.points.first {
                let dotSize = stroke.lineWidth
                let rect = CGRect(
                    x: point.x - dotSize / 2,
                    y: point.y - dotSize / 2,
                    width: dotSize,
                    height: dotSize
                )
                if stroke.isEraser {
                    context.fill(Path(ellipseIn: rect), with: .color(.white))
                } else {
                    context.fill(Path(ellipseIn: rect), with: .color(stroke.color))
                }
            }
            return
        }

        var path = Path()
        path.move(to: stroke.points[0])
        for i in 1..<stroke.points.count {
            let mid = CGPoint(
                x: (stroke.points[i - 1].x + stroke.points[i].x) / 2,
                y: (stroke.points[i - 1].y + stroke.points[i].y) / 2
            )
            path.addQuadCurve(to: mid, control: stroke.points[i - 1])
        }
        if let last = stroke.points.last {
            path.addLine(to: last)
        }

        if stroke.isEraser {
            context.stroke(path, with: .color(.white), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
        } else {
            context.stroke(path, with: .color(stroke.color), style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round))
        }
    }

    // MARK: - Drawer Toolbar

    private var drawerToolbar: some View {
        HStack(spacing: 6) {
            // Color palette
            ForEach(Array(engine.colors.enumerated()), id: \.offset) { _, item in
                let (color, name) = item
                Button {
                    engine.selectedColor = color
                    engine.isErasing = false
                    HapticManager.selection()
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(
                                    !engine.isErasing && engine.selectedColor == color
                                        ? Color.yellow : Color.white.opacity(0.2),
                                    lineWidth: !engine.isErasing && engine.selectedColor == color ? 2.5 : 1
                                )
                        )
                }
                .accessibilityLabel(name)
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))

            // Brush sizes
            ForEach(Array(engine.brushSizes.enumerated()), id: \.offset) { _, item in
                let (size, name) = item
                Button {
                    engine.selectedLineWidth = size
                    engine.isErasing = false
                    HapticManager.selection()
                } label: {
                    Circle()
                        .fill(Color.white)
                        .frame(width: size + 6, height: size + 6)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(!engine.isErasing && engine.selectedLineWidth == size
                                      ? Color.yellow.opacity(0.3) : Color.clear)
                        )
                }
                .accessibilityLabel(name)
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(0.2))

            // Eraser
            Button {
                engine.isErasing.toggle()
                HapticManager.selection()
            } label: {
                Image(systemName: "eraser.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(engine.isErasing ? .yellow : .white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(engine.isErasing ? Color.yellow.opacity(0.2) : Color.clear)
                    )
            }
            .accessibilityLabel("Eraser")

            // Clear
            Button {
                engine.clearCanvas()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel("Clear canvas")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
    }

    // MARK: - Guesser View

    private func guesserView(player: Int, size: CGSize) -> some View {
        VStack(spacing: 6) {
            // Role label
            HStack(spacing: 8) {
                Text("Guess the drawing!")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 6)

            // Mirrored canvas (read-only)
            let canvasSize = min(size.width - 16, size.height - 100)
            guesserCanvas(size: canvasSize)
                .frame(width: canvasSize, height: canvasSize)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.horizontal, 8)

            // Guess input + history
            guesserControls(player: player)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
        }
    }

    // MARK: - Guesser Canvas (Read-only Mirror)

    private func guesserCanvas(size: CGFloat) -> some View {
        Canvas { context, canvasSize in
            // White background
            context.fill(
                Path(CGRect(origin: .zero, size: canvasSize)),
                with: .color(.white)
            )

            // Draw all strokes (mirrored from drawer)
            for stroke in engine.strokes {
                drawStroke(stroke, in: &context)
            }

            if let current = engine.currentStroke {
                drawStroke(current, in: &context)
            }

            // Overlays
            if engine.roundPhase == .correct {
                let rect = CGRect(origin: .zero, size: canvasSize)
                context.fill(Path(rect), with: .color(.green.opacity(0.15)))
            } else if engine.roundPhase == .revealed {
                let rect = CGRect(origin: .zero, size: canvasSize)
                context.fill(Path(rect), with: .color(.red.opacity(0.15)))
            }
        }
        .overlay {
            // Show result text on canvas
            if engine.roundPhase == .correct {
                VStack(spacing: 4) {
                    Text("\u{2705}")
                        .font(.system(size: 36))
                    Text("Correct!")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }
                .transition(.scale.combined(with: .opacity))
            } else if engine.roundPhase == .revealed {
                VStack(spacing: 4) {
                    Text("\u{23F0}")
                        .font(.system(size: 36))
                    Text("It was: \(engine.secretWord.uppercased())")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.red)
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.roundPhase == .correct)
        .allowsHitTesting(false)
    }

    // MARK: - Guesser Controls

    private func guesserControls(player: Int) -> some View {
        VStack(spacing: 6) {
            // Recent guesses
            if !engine.guesses.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(engine.guesses) { guess in
                            Text(guess.text)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(guess.isCorrect ? .green : .red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule()
                                        .fill(guess.isCorrect ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                                )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 30)
            }

            // Text input
            HStack(spacing: 8) {
                TextField("Type your guess...", text: $engine.guessText)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isGuessFocused)
                    .onSubmit {
                        engine.submitGuess()
                        isGuessFocused = true
                    }
                    .tint(.green)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(engine.roundPhase != .drawing)

                Button {
                    engine.submitGuess()
                    isGuessFocused = true
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(engine.guessText.isEmpty ? .white.opacity(0.2) : .green)
                }
                .disabled(engine.guessText.isEmpty || engine.roundPhase != .drawing)
            }
        }
    }

    // MARK: - Center Divider

    private var centerDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.15), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)

            Text("R\(engine.currentRound)/\(engine.totalRounds)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.4))

            // Timer bar (compact)
            timerPill

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
        .padding(.horizontal, 12)
        .frame(height: 28)
    }

    private var timerPill: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(engine.timerColor)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(engine.timerColor)
                        .frame(width: geo.size.width * engine.timerFraction)
                        .animation(.linear(duration: 0.05), value: engine.timerFraction)
                }
            }
            .frame(width: 50, height: 6)

            Text("\(Int(engine.timeRemaining))s")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(engine.timerColor)
                .frame(width: 22, alignment: .trailing)
                .timerUrgency(timeRemaining: engine.timeRemaining)
        }
    }

    // MARK: - Round Transition

    private var roundTransitionOverlay: some View {
        VStack(spacing: 8) {
            Text(engine.transitionMessage)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Text("\(PlayerProfileManager.shared.name(for: engine.drawer)) draws")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(engine.drawer == 1 ? .blue : .red)
                Text("·")
                    .foregroundStyle(.white.opacity(0.3))
                Text("\(PlayerProfileManager.shared.name(for: engine.guesser)) guesses")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(engine.guesser == 1 ? .blue : .red)
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
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 20)
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.showRoundTransition)
    }
}

#Preview {
    DuelDrawView()
        .preferredColorScheme(.dark)
}
