import SwiftUI
import UIKit

// MARK: - Word Validator

struct WordValidator {
    private static let checker = UITextChecker()
    private static let minLength = 3

    static func isValid(_ word: String) -> Bool {
        let lowered = word.lowercased()
        guard lowered.count >= minLength else { return false }
        guard lowered.allSatisfy({ $0.isLetter }) else { return false }

        let range = NSRange(0..<lowered.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: lowered,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en"
        )
        return misspelled.location == NSNotFound
    }
}

// MARK: - Word Chain Engine

@Observable
final class WordChainEngine {
    var currentWord = ""
    var inputText = ""
    var activePlayer = 1
    var usedWords: [String] = []
    var wordHistory: [(word: String, player: Int)] = []
    var score1 = 0
    var score2 = 0
    var roundsPlayed = 0
    var timeRemaining: Double = 15.0
    var totalTime: Double = 15.0
    var winner: Int? = nil
    var showResult = false
    var errorMessage = ""
    var errorFlash = false
    var shakeAmount: CGFloat = 0
    var lastAcceptedWord = ""
    var tileAnimating = false
    var gameStarted = false

    private var timer: Timer?

    private static let starterWords = [
        "apple", "brave", "chain", "dance", "eagle", "flame", "grape", "house",
        "ivory", "joker", "knelt", "lemon", "magic", "night", "ocean", "piano",
        "queen", "river", "stone", "tiger", "ultra", "vivid", "whale", "young",
        "zebra", "amber", "blaze", "crisp", "drift", "ember", "frost", "gleam",
        "haste", "irony", "jolly", "karma", "lunar", "maple", "noble", "oasis",
        "plume", "quest", "reign", "solar", "torch", "unity", "vigor", "wrist"
    ]

    func startGame() {
        let starter = Self.starterWords.randomElement() ?? "chain"
        currentWord = starter
        usedWords = [starter]
        wordHistory = [(word: starter, player: 0)]
        inputText = ""
        activePlayer = 1
        score1 = 0
        score2 = 0
        roundsPlayed = 0
        winner = nil
        showResult = false
        errorMessage = ""
        errorFlash = false
        lastAcceptedWord = ""
        tileAnimating = false
        gameStarted = true
        timeRemaining = totalTime
        startTimer()
    }

    func submitWord() {
        let word = inputText.lowercased().trimmingCharacters(in: .whitespaces)
        inputText = ""

        guard !word.isEmpty else { return }

        // Validate: starts with last letter of current word
        let requiredLetter = currentWord.last!
        guard word.first == requiredLetter else {
            showError("Must start with '\(requiredLetter.uppercased())'")
            return
        }

        // Validate: minimum length
        guard word.count >= 3 else {
            showError("Too short! (3+ letters)")
            return
        }

        // Validate: not already used
        guard !usedWords.contains(word) else {
            showError("Already used!")
            return
        }

        // Validate: real word
        guard WordValidator.isValid(word) else {
            showError("Not a valid word!")
            return
        }

        // Word accepted
        acceptWord(word)
    }

    private func acceptWord(_ word: String) {
        usedWords.append(word)
        wordHistory.append((word: word, player: activePlayer))
        lastAcceptedWord = word
        roundsPlayed += 1
        tileAnimating = true

        if activePlayer == 1 {
            score1 += 1
        } else {
            score2 += 1
        }

        SoundManager.playPlace()
        HapticManager.notification(.success)

        currentWord = word
        activePlayer = activePlayer == 1 ? 2 : 1
        timeRemaining = totalTime

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
            tileAnimating = false
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        errorFlash = true
        HapticManager.notification(.error)
        SoundManager.playHit()

        // Screen shake
        withAnimation(.default) {
            shakeAmount = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [self] in
            withAnimation(.default) {
                shakeAmount = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [self] in
            if errorMessage == message {
                errorMessage = ""
                errorFlash = false
            }
        }
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard self.gameStarted, !self.showResult else {
                    self.timer?.invalidate()
                    return
                }
                self.timeRemaining -= 0.05
                if self.timeRemaining <= 0 {
                    self.timeUp()
                }
            }
        }
    }

    func timeUp() {
        timer?.invalidate()
        // The active player loses
        winner = activePlayer == 1 ? 2 : 1
        gameStarted = false

        // Screen shake + buzz
        withAnimation(.default) {
            shakeAmount = 12
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            withAnimation(.default) {
                shakeAmount = 0
            }
        }

        HapticManager.notification(.error)
        SoundManager.playWin()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [self] in
            showResult = true
        }
    }

    func pause() {
        timer?.invalidate()
    }

    func resume() {
        guard gameStarted, !showResult else { return }
        startTimer()
    }

    func cleanup() {
        timer?.invalidate()
        timer = nil
    }

    var timerFraction: Double {
        max(0, timeRemaining / totalTime)
    }

    var timerColor: Color {
        if timerFraction > 0.5 { return .green }
        if timerFraction > 0.25 { return .yellow }
        return .red
    }

    var requiredLetter: Character {
        currentWord.last ?? "a"
    }
}

// MARK: - Word Chain View

struct WordChainView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = WordChainEngine()
    @State private var isPaused = false
    @State private var showTutorial = false
    @AppStorage("hasSeenTutorial_WordChain") private var hasSeenTutorial = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        GameTransitionView {
            ZStack {
                // Background
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 score banner
                    FrostedScoreBanner(player: 2, score: engine.score2, color: .red, isTop: true)
                        .rotationEffect(.degrees(180))

                    Spacer()

                    // Word history (scrolling behind)
                    wordHistoryView

                    // Current word display
                    currentWordDisplay
                        .padding(.top, 12)

                    // Timer bar
                    timerBar
                        .padding(.horizontal, 32)
                        .padding(.top, 16)

                    // Active player indicator
                    activePlayerBadge
                        .padding(.top, 12)

                    // Error message
                    errorBanner
                        .padding(.top, 8)

                    // Text input
                    inputArea
                        .padding(.top, 12)
                        .padding(.horizontal, 24)

                    Spacer()

                    // Player 1 score banner
                    FrostedScoreBanner(player: 1, score: engine.score1, color: .blue, isTop: false)
                }
                .offset(x: engine.shakeAmount)

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
                    TutorialOverlayView(content: .wordChain) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if engine.showResult {
                    if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameType: .wordChain, gameName: "Word Chain") {
                            engine.startGame()
                            isInputFocused = true
                        } onExit: {
                            engine.cleanup()
                            dismiss()
                        }
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
                            isInputFocused = true
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
            } else {
                isInputFocused = true
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
                isInputFocused = true
            }
        }
    }

    // MARK: - Word History

    private var wordHistoryView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(engine.wordHistory.enumerated()), id: \.offset) { index, entry in
                    Text(entry.word.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(
                            entry.player == 0 ? .white.opacity(0.3) :
                            entry.player == 1 ? Color.blue.opacity(0.5) :
                            Color.red.opacity(0.5)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.04))
                        )
                        .transition(.asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.wordHistory.count)
        }
        .frame(height: 36)
    }

    // MARK: - Current Word Display

    private var currentWordDisplay: some View {
        HStack(spacing: 4) {
            ForEach(Array(engine.currentWord.uppercased().enumerated()), id: \.offset) { index, char in
                let isLast = index == engine.currentWord.count - 1
                Text(String(char))
                    .font(.system(size: isLast ? 42 : 36, weight: .bold, design: .serif))
                    .foregroundStyle(isLast ? .yellow : .white)
                    .shadow(color: isLast ? .yellow.opacity(0.5) : .clear, radius: 8)
                    .padding(.horizontal, isLast ? 2 : 0)
                    .scaleEffect(engine.tileAnimating && isLast ? 1.2 : 1.0)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.5)
                            .delay(Double(index) * 0.04),
                        value: engine.currentWord
                    )
            }
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: engine.currentWord)
    }

    // MARK: - Timer Bar

    private var timerBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.08))

                // Fill
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [engine.timerColor, engine.timerColor.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * engine.timerFraction)
                    .animation(.linear(duration: 0.05), value: engine.timerFraction)

                // Glow on low time
                if engine.timerFraction < 0.25 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red.opacity(0.15))
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: engine.timerFraction < 0.25)
                }
            }
        }
        .frame(height: 12)
    }

    // MARK: - Active Player Badge

    private var activePlayerBadge: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(engine.activePlayer == 1 ? Color.blue : Color.red)
                .frame(width: 10, height: 10)
            Text("Player \(engine.activePlayer)'s turn")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(engine.activePlayer == 1 ? Color.blue : Color.red)

            Text("·")
                .foregroundStyle(.white.opacity(0.3))

            Text("Start with '\(engine.requiredLetter.uppercased())'")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.yellow.opacity(0.8))
        }
        .animation(.easeInOut(duration: 0.3), value: engine.activePlayer)
    }

    // MARK: - Error Banner

    private var errorBanner: some View {
        Group {
            if !engine.errorMessage.isEmpty {
                Text(engine.errorMessage)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.red.opacity(0.15))
                    )
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(height: 36)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: engine.errorMessage)
    }

    // MARK: - Input Area

    private var inputArea: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                // Show required starting letter as hint
                Text(engine.requiredLetter.uppercased())
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.yellow.opacity(0.6))
                    .frame(width: 30)

                TextField("Type a word...", text: $engine.inputText)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isInputFocused)
                    .onSubmit {
                        engine.submitWord()
                        isInputFocused = true
                    }
                    .tint(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        engine.activePlayer == 1 ? Color.blue.opacity(0.3) : Color.red.opacity(0.3),
                        lineWidth: 1.5
                    )
            )

            // Submit button
            Button {
                engine.submitWord()
                isInputFocused = true
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(engine.inputText.isEmpty ? .white.opacity(0.2) : .yellow)
                    .shadow(color: engine.inputText.isEmpty ? .clear : .yellow.opacity(0.3), radius: 6)
            }
            .disabled(engine.inputText.isEmpty)
        }
    }
}

#Preview {
    WordChainView()
        .preferredColorScheme(.dark)
}
