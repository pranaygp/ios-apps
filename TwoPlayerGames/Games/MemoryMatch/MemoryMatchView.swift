import SwiftUI

// MARK: - Model

struct MemoryCard: Identifiable, Equatable {
    let id: Int
    let symbolName: String
    let symbolColor: Color
    var isFaceUp = false
    var isMatched = false

    static func == (lhs: MemoryCard, rhs: MemoryCard) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Card Symbol Set

private let cardSymbols: [(name: String, color: Color)] = [
    ("star.fill", Color.yellow),
    ("heart.fill", Color.pink),
    ("moon.fill", Color.purple),
    ("flame.fill", Color.orange),
    ("leaf.fill", Color.green),
    ("bolt.fill", Color.cyan),
    ("drop.fill", Color.blue),
    ("pawprint.fill", Color(red: 0.6, green: 0.4, blue: 0.2)),
    ("crown.fill", Color(red: 1.0, green: 0.75, blue: 0.0)),
    ("diamond.fill", Color(red: 0.4, green: 0.85, blue: 0.95)),
]

// MARK: - View

struct MemoryMatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var themeManager: ThemeManager

    @State private var cards: [MemoryCard] = []
    @State private var firstFlipped: Int?
    @State private var secondFlipped: Int?
    @State private var currentPlayer = 1
    @State private var score1 = 0
    @State private var score2 = 0
    @State private var gameWinner: Int?
    @State private var isDraw = false
    @State private var isProcessing = false
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var matchedIndices: Set<Int> = []
    @State private var recentMatchIndices: Set<Int> = []
    @AppStorage("hasSeenTutorial_MemoryMatch") private var hasSeenTutorial = false

    private let gridColumns = 4
    private let gridRows = 5
    private var totalPairs: Int { (gridColumns * gridRows) / 2 }

    var body: some View {
        GameTransitionView {
            ZStack {
                themeManager.currentTheme.backgroundColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    FrostedScoreBanner(player: 2, score: score2, color: .red, isTop: true)

                    Spacer()

                    if gameWinner == nil && !isDraw {
                        turnIndicator
                    }

                    cardGrid
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)

                    Spacer()

                    FrostedScoreBanner(player: 1, score: score1, color: .blue, isTop: false)
                }

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                if !showTutorial && !isPaused && gameWinner == nil && !isDraw {
                    TutorialInfoButton { showTutorial = true }
                }

                if showTutorial {
                    TutorialOverlayView(content: .memoryMatch) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if let winner = gameWinner {
                    WinnerOverlay(winner: winner, gameType: .memoryMatch, gameName: "Memory Match") {
                        resetGame()
                    } onExit: {
                        dismiss()
                    }
                }

                if isDraw {
                    DrawOverlay(gameName: "Memory Match") {
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
                if !hasSeenTutorial { showTutorial = true }
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
            Text("\(PlayerProfileManager.shared.name(for: currentPlayer))'s Turn")
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
        let isRecentMatch = recentMatchIndices.contains(index)

        return Button {
            flipCard(at: index)
        } label: {
            ZStack {
                // Back face
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.currentTheme.primaryColor.opacity(0.5),
                                themeManager.currentTheme.secondaryColor.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(themeManager.currentTheme.accentColor.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "questionmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(themeManager.currentTheme.textColor.opacity(0.15))
                    )
                    .opacity(isFaceUp ? 0 : 1)

                // Front face
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        card.isMatched
                            ? card.symbolColor.opacity(0.1)
                            : Color(white: 0.12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                card.isMatched
                                    ? card.symbolColor.opacity(0.5)
                                    : Color.white.opacity(0.15),
                                lineWidth: card.isMatched ? 2 : 1
                            )
                    )
                    .overlay(
                        Image(systemName: card.symbolName)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(card.symbolColor)
                            .shadow(color: card.symbolColor.opacity(0.4), radius: 4)
                    )
                    .opacity(isFaceUp ? 1 : 0)
            }
            .rotation3DEffect(
                .degrees(isFaceUp ? 0 : 180),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .animation(.easeInOut(duration: 0.35), value: isFaceUp)
            .scaleEffect(isRecentMatch ? 1.08 : 1.0)
            .shadow(
                color: isRecentMatch ? card.symbolColor.opacity(0.6) : .clear,
                radius: isRecentMatch ? 8 : 0
            )
            .animation(.easeInOut(duration: 0.4), value: isRecentMatch)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(0.72, contentMode: .fit)
        .buttonStyle(.plain)
        .disabled(isFaceUp || isProcessing || isPaused)
        .opacity(card.isMatched && !isRecentMatch ? 0.55 : 1.0)
        .scaleEffect(card.isMatched && !isRecentMatch ? 0.92 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: card.isMatched)
        .accessibilityLabel(isFaceUp ? card.symbolName : "Hidden card")
    }

    // MARK: - Game Logic

    private func setupCards() {
        var allCards: [MemoryCard] = []
        for (i, symbol) in cardSymbols.prefix(totalPairs).enumerated() {
            allCards.append(MemoryCard(id: i * 2, symbolName: symbol.name, symbolColor: symbol.color))
            allCards.append(MemoryCard(id: i * 2 + 1, symbolName: symbol.name, symbolColor: symbol.color))
        }
        cards = allCards.shuffled()
        matchedIndices = []
        recentMatchIndices = []
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

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if cards[first].symbolName == cards[second].symbolName {
                // Match found
                withAnimation {
                    cards[first].isMatched = true
                    cards[second].isMatched = true
                }
                matchedIndices.insert(first)
                matchedIndices.insert(second)
                recentMatchIndices = [first, second]

                if currentPlayer == 1 { score1 += 1 } else { score2 += 1 }
                SoundManager.playScore()
                HapticManager.notification(.success)

                // Clear recent match glow after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation {
                        recentMatchIndices = []
                    }
                }

                // Check game over
                if cards.allSatisfy({ $0.isMatched }) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
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
                // Same player gets another turn on match
            } else {
                // No match — flip back
                withAnimation {
                    cards[first].isFaceUp = false
                    cards[second].isFaceUp = false
                }
                SoundManager.playHit()
                HapticManager.notification(.warning)
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
        setupCards()
    }
}

#Preview {
    MemoryMatchView()
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager.shared)
}
