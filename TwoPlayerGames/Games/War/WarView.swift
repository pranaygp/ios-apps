import SwiftUI

// MARK: - Card Model

struct PlayingCard: Identifiable, Equatable {
    let id = UUID()
    let rank: Int   // 2–14 (11=J, 12=Q, 13=K, 14=A)
    let suit: Int   // 0=♠, 1=♥, 2=♦, 3=♣

    var rankString: String {
        switch rank {
        case 2...10: return "\(rank)"
        case 11: return "J"
        case 12: return "Q"
        case 13: return "K"
        case 14: return "A"
        default: return "?"
        }
    }

    var suitString: String {
        switch suit {
        case 0: return "♠"
        case 1: return "♥"
        case 2: return "♦"
        case 3: return "♣"
        default: return "?"
        }
    }

    var suitColor: Color {
        suit == 1 || suit == 2 ? .red : .white
    }

    static func fullDeck() -> [PlayingCard] {
        var deck: [PlayingCard] = []
        for suit in 0..<4 {
            for rank in 2...14 {
                deck.append(PlayingCard(rank: rank, suit: suit))
            }
        }
        return deck.shuffled()
    }
}

// MARK: - War Game Engine

@Observable
final class WarGameEngine {
    var player1Deck: [PlayingCard] = []
    var player2Deck: [PlayingCard] = []
    var player1Card: PlayingCard?
    var player2Card: PlayingCard?
    var player1Tapped = false
    var player2Tapped = false
    var isRevealed = false
    var isWar = false
    var warPile: [PlayingCard] = []
    var warDepth = 0
    var roundMessage = ""
    var winner: Int? = nil
    var showResult = false
    var isAnimating = false
    var speedMode = false
    var speedTimer: Timer?
    var shakeAmount: CGFloat = 0

    func startGame() {
        let deck = PlayingCard.fullDeck()
        player1Deck = Array(deck[0..<26])
        player2Deck = Array(deck[26..<52])
        player1Card = nil
        player2Card = nil
        player1Tapped = false
        player2Tapped = false
        isRevealed = false
        isWar = false
        warPile = []
        warDepth = 0
        roundMessage = ""
        winner = nil
        showResult = false
        isAnimating = false
    }

    func playerTap(_ player: Int) {
        guard !isAnimating, !showResult, !isRevealed else { return }

        if player == 1 && !player1Tapped {
            player1Tapped = true
            HapticManager.impact(.light)
            SoundManager.playButtonTap()
        } else if player == 2 && !player2Tapped {
            player2Tapped = true
            HapticManager.impact(.light)
            SoundManager.playButtonTap()
        }

        if player1Tapped && player2Tapped {
            flipCards()
        }
    }

    func flipCards() {
        guard !player1Deck.isEmpty, !player2Deck.isEmpty else { return }

        isAnimating = true
        player1Card = player1Deck.removeFirst()
        player2Card = player2Deck.removeFirst()
        isRevealed = true

        SoundManager.playPlace()
        HapticManager.impact(.medium)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            resolveRound()
        }
    }

    func resolveRound() {
        guard let c1 = player1Card, let c2 = player2Card else { return }

        if c1.rank > c2.rank {
            // Player 1 wins
            roundMessage = "Player 1 wins!"
            var winnings = [c1, c2] + warPile
            winnings.shuffle()
            player1Deck.append(contentsOf: winnings)
            warPile = []
            warDepth = 0

            SoundManager.playScore()
            HapticManager.notification(.success)

            finishRound()
        } else if c2.rank > c1.rank {
            // Player 2 wins
            roundMessage = "Player 2 wins!"
            var winnings = [c1, c2] + warPile
            winnings.shuffle()
            player2Deck.append(contentsOf: winnings)
            warPile = []
            warDepth = 0

            SoundManager.playScore()
            HapticManager.notification(.success)

            finishRound()
        } else {
            // WAR!
            declareWar()
        }
    }

    func declareWar() {
        guard let c1 = player1Card, let c2 = player2Card else { return }

        isWar = true
        warDepth += 1
        roundMessage = warDepth > 1 ? "DOUBLE WAR!" : "WAR!"
        warPile.append(contentsOf: [c1, c2])

        // Screen shake
        withAnimation(.default) {
            shakeAmount = 10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
            withAnimation(.default) {
                shakeAmount = 0
            }
        }

        HapticManager.notification(.warning)
        SoundManager.playHit()

        // Each player places 3 face-down cards
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [self] in
            let p1FaceDown = min(3, player1Deck.count)
            let p2FaceDown = min(3, player2Deck.count)

            if p1FaceDown == 0 {
                // Player 1 has no cards left for war — loses
                endGame(winner: 2)
                return
            }
            if p2FaceDown == 0 {
                // Player 2 has no cards left for war — loses
                endGame(winner: 1)
                return
            }

            for _ in 0..<p1FaceDown {
                warPile.append(player1Deck.removeFirst())
            }
            for _ in 0..<p2FaceDown {
                warPile.append(player2Deck.removeFirst())
            }

            SoundManager.playDrop()

            // Check if either player can flip
            if player1Deck.isEmpty {
                endGame(winner: 2)
                return
            }
            if player2Deck.isEmpty {
                endGame(winner: 1)
                return
            }

            // Flip new face-up cards
            isRevealed = false
            player1Card = nil
            player2Card = nil
            isWar = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                player1Card = player1Deck.removeFirst()
                player2Card = player2Deck.removeFirst()
                isRevealed = true

                SoundManager.playPlace()
                HapticManager.impact(.heavy)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                    resolveRound()
                }
            }
        }
    }

    func finishRound() {
        // Check win condition
        if player1Deck.isEmpty && player1Card == nil {
            endGame(winner: 2)
            return
        }
        if player2Deck.isEmpty && player2Card == nil {
            endGame(winner: 1)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (speedMode ? 0.4 : 0.8)) { [self] in
            isRevealed = false
            player1Card = nil
            player2Card = nil
            player1Tapped = false
            player2Tapped = false
            isAnimating = false
            roundMessage = ""

            if speedMode {
                autoFlip()
            }
        }
    }

    func endGame(winner w: Int) {
        winner = w
        isAnimating = false
        roundMessage = ""
        if w == 1 {
            SoundManager.playWin()
        } else {
            SoundManager.playWin()
        }
        HapticManager.notification(.success)

        stopSpeedMode()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            showResult = true
        }
    }

    func toggleSpeedMode() {
        speedMode.toggle()
        if speedMode && !isAnimating && !showResult && !isRevealed {
            autoFlip()
        } else if !speedMode {
            stopSpeedMode()
        }
    }

    func autoFlip() {
        guard speedMode, !isAnimating, !showResult else { return }
        player1Tapped = true
        player2Tapped = true
        flipCards()
    }

    func stopSpeedMode() {
        speedTimer?.invalidate()
        speedTimer = nil
    }
}

// MARK: - War View

struct WarView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var engine = WarGameEngine()
    @State private var isPaused = false
    @State private var warFlash = false
    @State private var cardFlip1: Double = 0
    @State private var cardFlip2: Double = 0

    var body: some View {
        GameTransitionView {
            ZStack {
                Color(white: 0.06).ignoresSafeArea()

                VStack(spacing: 0) {
                    // Player 2 area (top, rotated 180°)
                    player2Area
                        .rotationEffect(.degrees(180))

                    // Center divider with info
                    centerArea

                    // Player 1 area (bottom)
                    player1Area
                }
                .offset(x: engine.shakeAmount)

                GameOverlay(onBack: { dismiss() }, onPause: { isPaused = true })

                // WAR flash overlay
                if warFlash {
                    warFlashOverlay
                }

                if engine.showResult {
                    if let winner = engine.winner {
                        WinnerOverlay(winner: winner, gameType: .war, gameName: "War") {
                            restart()
                        } onExit: {
                            dismiss()
                        }
                    }
                }

                if isPaused && !engine.showResult {
                    PauseOverlay(
                        score1: engine.player1Deck.count + (engine.player1Card != nil ? 1 : 0),
                        score2: engine.player2Deck.count + (engine.player2Card != nil ? 1 : 0),
                        player1Color: .blue,
                        player2Color: .red,
                        onResume: { isPaused = false },
                        onRestart: {
                            isPaused = false
                            restart()
                        },
                        onExit: { dismiss() }
                    )
                }
            }
        }
        .onAppear {
            engine.startGame()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase != .active && !engine.showResult {
                isPaused = true
                engine.stopSpeedMode()
            }
        }
        .onChange(of: engine.isWar) { _, isWar in
            if isWar {
                withAnimation(.easeInOut(duration: 0.15).repeatCount(3, autoreverses: true)) {
                    warFlash = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    warFlash = false
                }
            }
        }
        .onChange(of: engine.isRevealed) { _, revealed in
            if revealed {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    cardFlip1 = 0
                    cardFlip2 = 0
                }
            } else {
                cardFlip1 = 180
                cardFlip2 = 180
            }
        }
    }

    // MARK: - Player 1 Area (Bottom)

    private var player1Area: some View {
        Button {
            if !isPaused { engine.playerTap(1) }
        } label: {
            ZStack {
                // Background tap zone
                Color.blue.opacity(engine.player1Tapped && !engine.isRevealed ? 0.08 : 0.03)

                VStack(spacing: 16) {
                    Spacer()

                    // Card display
                    if let card = engine.player1Card, engine.isRevealed {
                        cardView(card: card)
                            .rotation3DEffect(.degrees(cardFlip1), axis: (x: 0, y: 1, z: 0))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        cardBackView(color: .blue)
                            .opacity(engine.player1Deck.isEmpty ? 0.3 : 1)
                    }

                    // Deck count
                    HStack(spacing: 8) {
                        Circle().fill(Color.blue).frame(width: 10, height: 10)
                        Text("Player 1")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(engine.player1Deck.count) cards")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if !engine.player1Tapped && !engine.isRevealed && !engine.isAnimating && !engine.speedMode && !engine.showResult {
                        Text("TAP TO FLIP")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.blue.opacity(0.5))
                            .tracking(2)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Player 2 Area (Top)

    private var player2Area: some View {
        Button {
            if !isPaused { engine.playerTap(2) }
        } label: {
            ZStack {
                Color.red.opacity(engine.player2Tapped && !engine.isRevealed ? 0.08 : 0.03)

                VStack(spacing: 16) {
                    Spacer()

                    if let card = engine.player2Card, engine.isRevealed {
                        cardView(card: card)
                            .rotation3DEffect(.degrees(cardFlip2), axis: (x: 0, y: 1, z: 0))
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        cardBackView(color: .red)
                            .opacity(engine.player2Deck.isEmpty ? 0.3 : 1)
                    }

                    HStack(spacing: 8) {
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                        Text("Player 2")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.red)
                        Text("·")
                            .foregroundStyle(.white.opacity(0.3))
                        Text("\(engine.player2Deck.count) cards")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    if !engine.player2Tapped && !engine.isRevealed && !engine.isAnimating && !engine.speedMode && !engine.showResult {
                        Text("TAP TO FLIP")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.red.opacity(0.5))
                            .tracking(2)
                    }

                    Spacer().frame(height: 20)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Center Area

    private var centerArea: some View {
        HStack {
            // Round message
            if !engine.roundMessage.isEmpty {
                Text(engine.roundMessage)
                    .font(.system(size: engine.roundMessage.contains("WAR") ? 22 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(engine.roundMessage.contains("WAR") ? .orange : .white.opacity(0.7))
                    .shadow(color: engine.roundMessage.contains("WAR") ? .orange.opacity(0.5) : .clear, radius: 8)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: engine.roundMessage)
            }

            Spacer()

            // War pile indicator
            if !engine.warPile.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                    Text("\(engine.warPile.count)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(.orange.opacity(0.15))
                )
            }

            Spacer()

            // Speed mode toggle
            Button {
                HapticManager.impact(.light)
                engine.toggleSpeedMode()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: engine.speedMode ? "hare.fill" : "hare")
                        .font(.system(size: 13))
                    Text(engine.speedMode ? "AUTO" : "Speed")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(engine.speedMode ? .green : .white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(engine.speedMode ? Color.green.opacity(0.15) : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(engine.speedMode ? Color.green.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .opacity(0.3)
        )
        .overlay(
            VStack {
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
                Spacer()
                Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
            }
        )
    }

    // MARK: - Card Views

    private func cardView(card: PlayingCard) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.95))
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)

            VStack(spacing: 2) {
                Text(card.rankString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(card.suitColor == .red ? Color.red : Color.black)

                Text(card.suitString)
                    .font(.system(size: 28))
            }

            // Corner indicators
            VStack {
                HStack {
                    cornerLabel(card: card)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    cornerLabel(card: card)
                        .rotationEffect(.degrees(180))
                }
            }
            .padding(8)
        }
        .frame(width: 100, height: 140)
    }

    private func cornerLabel(card: PlayingCard) -> some View {
        VStack(spacing: 0) {
            Text(card.rankString)
                .font(.system(size: 12, weight: .bold))
            Text(card.suitString)
                .font(.system(size: 10))
        }
        .foregroundStyle(card.suitColor == .red ? Color.red : Color.black)
    }

    private func cardBackView(color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [color, color.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: color.opacity(0.3), radius: 6, y: 3)

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .padding(6)

            // Diamond pattern
            Image(systemName: "suit.diamond.fill")
                .font(.system(size: 30))
                .foregroundStyle(.white.opacity(0.15))
        }
        .frame(width: 100, height: 140)
    }

    // MARK: - War Flash Overlay

    private var warFlashOverlay: some View {
        Color.orange.opacity(0.15)
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }

    // MARK: - Restart

    private func restart() {
        cardFlip1 = 180
        cardFlip2 = 180
        engine.startGame()
    }
}

#Preview {
    WarView()
        .preferredColorScheme(.dark)
}
