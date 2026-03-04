import SwiftUI

struct MemoryMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    struct Card: Identifiable {
        let id: Int
        let emoji: String
        var isFaceUp = false
        var isMatched = false
    }

    @State private var cards: [Card] = []
    @State private var firstFlipped: Int?
    @State private var secondFlipped: Int?
    @State private var currentPlayer = 1
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var gameWinner: Int?
    @State private var isDraw = false
    @State private var isProcessing = false
    @State private var isPaused = false
    @State private var matchFlash = false
    @State private var lastMatchPlayer: Int?

    private let gridColumns = 4
    private let gridRows = 5
    private var totalPairs: Int { (gridColumns * gridRows) / 2 }

    private let emojis = [
        "\u{1F680}", "\u{1F3AE}", "\u{1F525}", "\u{2B50}", "\u{1F308}", "\u{1F3B5}",
        "\u{1F98A}", "\u{1F40B}", "\u{1F419}", "\u{1F996}", "\u{1F33B}", "\u{1F342}",
        "\u{26A1}", "\u{1F48E}", "\u{1F3C6}", "\u{1F381}", "\u{1F3AF}", "\u{1F52E}",
        "\u{1FA90}", "\u{1F9E9}"
    ]

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 banner (top)
                    FrostedScoreBanner(player: 2, score: score2, color: .red, isTop: true)

                    Spacer()

                    // Turn indicator
                    turnIndicator

                    // Card grid
                    cardGrid
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)

                    Spacer()

                    // Player 1 banner (bottom)
                    FrostedScoreBanner(player: 1, score: score1, color: .blue, isTop: false)
                }

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameType: .memoryMatch, gameName: "Memory Match") {
                        resetGame()
                    } onExit: {
                        dismiss()
                    }
                }

                if isDraw {
                    DrawOverlay {
                        resetGame()
                    } onExit: {
                        dismiss()
                    }
                }

                if isPaused && gameWinner == nil {
                    PauseOverlay(
                        score1: score1,
                        score2: score2,
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: { isPaused = false },
                        onRestart: {
                            isPaused = false
                            resetGame()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
            .onAppear {
                setupCards()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && gameWinner == nil {
                isPaused = true
            }
        }
    }

    // MARK: - Turn Indicator

    private var turnIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(currentPlayer == 1 ? Color.blue : Color.red)
                .frame(width: 10, height: 10)
                .shadow(color: (currentPlayer == 1 ? Color.blue : Color.red).opacity(0.5), radius: 4)
            Text("Player \(currentPlayer)'s Turn")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(currentPlayer == 1 ? Color.blue : Color.red)
        }
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.3), value: currentPlayer)
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        VStack(spacing: 6) {
            ForEach(0..<gridRows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<gridColumns, id: \.self) { col in
                        let index = row * gridColumns + col
                        if index < cards.count {
                            cardView(for: index)
                        }
                    }
                }
            }
        }
    }

    private func cardView(for index: Int) -> some View {
        let card = cards[index]
        let isFaceUp = card.isFaceUp || card.isMatched

        return Button {
            flipCard(at: index)
        } label: {
            ZStack {
                // Back face
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.15, green: 0.2, blue: 0.35),
                                Color(red: 0.1, green: 0.12, blue: 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white.opacity(0.15))
                    )
                    .opacity(isFaceUp ? 0 : 1)

                // Front face
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        card.isMatched
                            ? (lastMatchPlayer == 1 ? Color.blue.opacity(0.15) : Color.red.opacity(0.15))
                            : Color(white: 0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                card.isMatched
                                    ? (lastMatchPlayer == 1 ? Color.blue.opacity(0.4) : Color.red.opacity(0.4))
                                    : Color.white.opacity(0.15),
                                lineWidth: card.isMatched ? 2 : 1
                            )
                    )
                    .overlay(
                        Text(card.emoji)
                            .font(.system(size: 28))
                    )
                    .opacity(isFaceUp ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(isFaceUp ? 0 : 180),
                axis: (x: 0, y: 1, z: 0)
            )
            .animation(.easeInOut(duration: 0.3), value: isFaceUp)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.75, contentMode: .fit)
        .buttonStyle(.plain)
        .disabled(isFaceUp || isProcessing || isPaused)
        .opacity(card.isMatched ? 0.6 : 1.0)
        .accessibilityLabel(isFaceUp ? card.emoji : "Hidden card")
    }

    // MARK: - Game Logic

    private func setupCards() {
        let selectedEmojis = Array(emojis.shuffled().prefix(totalPairs))
        var allCards: [Card] = []
        for (i, emoji) in selectedEmojis.enumerated() {
            allCards.append(Card(id: i * 2, emoji: emoji))
            allCards.append(Card(id: i * 2 + 1, emoji: emoji))
        }
        cards = allCards.shuffled()
    }

    private func flipCard(at index: Int) {
        guard !isPaused, !isProcessing else { return }
        guard !cards[index].isFaceUp, !cards[index].isMatched else { return }

        SoundManager.playPlace()
        HapticManager.impact(.light)

        withAnimation {
            cards[index].isFaceUp = true
        }

        if firstFlipped == nil {
            firstFlipped = index
        } else if secondFlipped == nil {
            secondFlipped = index
            isProcessing = true
            checkMatch()
        }
    }

    private func checkMatch() {
        guard let first = firstFlipped, let second = secondFlipped else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if cards[first].emoji == cards[second].emoji {
                // Match!
                withAnimation {
                    cards[first].isMatched = true
                    cards[second].isMatched = true
                }
                lastMatchPlayer = currentPlayer
                if currentPlayer == 1 { score1 += 1 } else { score2 += 1 }
                SoundManager.playScore()
                HapticManager.notification(.success)

                // Check game over
                if cards.allSatisfy({ $0.isMatched }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if score1 > score2 {
                            gameWinner = 1
                            SoundManager.playWin()
                        } else if score2 > score1 {
                            gameWinner = 2
                            SoundManager.playWin()
                        } else {
                            isDraw = true
                            SoundManager.playDraw()
                            HapticManager.notification(.warning)
                        }
                    }
                }
                // Same player goes again on match
            } else {
                // No match — flip back
                withAnimation {
                    cards[first].isFaceUp = false
                    cards[second].isFaceUp = false
                }
                SoundManager.playLose()
                HapticManager.impact(.light)
                currentPlayer = currentPlayer == 1 ? 2 : 1
            }

            firstFlipped = nil
            secondFlipped = nil
            isProcessing = false
        }
    }

    private func resetGame() {
        score1 = 0
        score2 = 0
        currentPlayer = 1
        gameWinner = nil
        isDraw = false
        firstFlipped = nil
        secondFlipped = nil
        isProcessing = false
        lastMatchPlayer = nil
        setupCards()
    }
}

#Preview {
    MemoryMatchView()
        .preferredColorScheme(.dark)
}
