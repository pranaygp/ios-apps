import SwiftUI

// MARK: - Tutorial Content

struct TutorialContent {
    let title: String
    let emoji: String
    let rules: [String]
    let controls: String
}

extension TutorialContent {
    static let pingPong = TutorialContent(
        title: "Ping Pong",
        emoji: "\u{1F3D3}",
        rules: [
            "Deflect the ball past your opponent's paddle",
            "First player to 5 points wins",
            "The ball speeds up as the rally goes on"
        ],
        controls: "Drag your finger to move your paddle"
    )

    static let airHockey = TutorialContent(
        title: "Air Hockey",
        emoji: "\u{1F3D2}",
        rules: [
            "Hit the puck into your opponent's goal",
            "First player to 7 goals wins",
            "Stay on your side of the table"
        ],
        controls: "Drag your mallet to hit the puck"
    )

    static let ticTacToe = TutorialContent(
        title: "Tic Tac Toe",
        emoji: "\u{274C}",
        rules: [
            "Players take turns placing X or O",
            "Get 3 in a row to win (horizontal, vertical, or diagonal)",
            "If the board fills up with no winner, it's a draw"
        ],
        controls: "Tap an empty cell to place your mark"
    )

    static let connectFour = TutorialContent(
        title: "Connect Four",
        emoji: "\u{1F534}",
        rules: [
            "Drop your piece into any column",
            "Get 4 in a row to win (horizontal, vertical, or diagonal)",
            "Plan ahead to block your opponent"
        ],
        controls: "Tap a column to drop your piece"
    )

    static let reactionTime = TutorialContent(
        title: "Reaction Time",
        emoji: "\u{26A1}",
        rules: [
            "Wait for the screen to flash green",
            "Tap your side as fast as you can when it does",
            "Tapping too early gives your opponent a point",
            "First to 3 wins"
        ],
        controls: "Tap your half of the screen when you see green"
    )

    static let simonSays = TutorialContent(
        title: "Simon Says",
        emoji: "\u{1F3B5}",
        rules: [
            "One player creates a pattern by tapping colored buttons",
            "The other player must repeat the exact pattern",
            "Get it wrong and your opponent scores",
            "First to 3 points wins"
        ],
        controls: "Tap the colored buttons to create or repeat patterns"
    )

    static let tugOfWar = TutorialContent(
        title: "Tug of War",
        emoji: "\u{1F4AA}",
        rules: [
            "Tap your side as fast as you can to pull the rope",
            "Pull the rope past the winning line to score a point",
            "First to 3 round wins takes the match"
        ],
        controls: "Tap rapidly on your side of the screen"
    )

    static let memoryMatch = TutorialContent(
        title: "Memory Match",
        emoji: "\u{1F9E0}",
        rules: [
            "Take turns flipping two cards at a time",
            "Find a matching pair to score and go again",
            "If the cards don't match, it's the other player's turn",
            "Most pairs when all cards are matched wins"
        ],
        controls: "Tap cards to flip them over"
    )

    static let colorConquest = TutorialContent(
        title: "Color Conquest",
        emoji: "\u{1F3A8}",
        rules: [
            "Tap tiles on your side to claim them",
            "Tap opponent's tiles to steal them",
            "Use your bomb power-up to blast a whole area",
            "Most tiles when time runs out wins"
        ],
        controls: "Tap tiles on the grid to claim or steal them"
    )

    static let sonarDuel = TutorialContent(
        title: "Sonar Duel",
        emoji: "\u{1F6F3}\u{FE0F}",
        rules: [
            "Hunt your opponent's hidden submarine on the grid",
            "Use sonar pings to detect nearby subs",
            "Fire torpedoes to hit and sink the enemy",
            "First to sink the opponent's sub wins"
        ],
        controls: "Tap grid cells to scan or fire"
    )

    static let dotsAndBoxes = TutorialContent(
        title: "Dots & Boxes",
        emoji: "\u{1F4E6}",
        rules: [
            "Take turns drawing a line between two dots",
            "Complete the 4th side of a box to claim it and go again",
            "The player with the most boxes when the grid is full wins"
        ],
        controls: "Tap between two dots to draw a line"
    )

    static let snakeVsSnake = TutorialContent(
        title: "Snake vs Snake",
        emoji: "\u{1F40D}",
        rules: [
            "Both snakes move at the same time",
            "Eat food to grow longer",
            "Crash into a wall, yourself, or the other snake and you lose",
            "Last snake alive wins"
        ],
        controls: "Swipe in your half of the screen to change direction"
    )

    static let war = TutorialContent(
        title: "War",
        emoji: "\u{1F0CF}",
        rules: [
            "Each player taps to flip their top card",
            "Higher card wins both cards",
            "If cards tie, it's WAR — 3 cards go face-down, then flip again",
            "Win all 52 cards to win the game"
        ],
        controls: "Tap your side to flip your card"
    )

    static let wordChain = TutorialContent(
        title: "Word Chain",
        emoji: "\u{1F4DA}",
        rules: [
            "Each word must start with the last letter of the previous word",
            "Words must be at least 3 letters long",
            "No repeating words — each word can only be used once",
            "If the timer runs out on your turn, you lose!"
        ],
        controls: "Type your word and tap submit or press return"
    )

    static let mazeRace = TutorialContent(
        title: "Maze Race",
        emoji: "\u{1F3C1}",
        rules: [
            "Both players race through the same maze at the same time",
            "Navigate from the top-left corner to the flag at bottom-right",
            "Walls block your path — find the route through!",
            "First to 2 round wins takes the match"
        ],
        controls: "Swipe or tap adjacent cells to move through the maze"
    )

    static let battleship = TutorialContent(
        title: "Battleship",
        emoji: "\u{1F6A2}",
        rules: [
            "Each player secretly places 5 ships on their grid",
            "Take turns firing shots at the enemy's waters",
            "Red = hit, white = miss — sink all 5 ships to win",
            "Pass the device between turns to keep boards hidden"
        ],
        controls: "Tap grid cells to place ships or fire shots"
    )
}

// MARK: - Tutorial Overlay View

struct TutorialOverlayView: View {
    let content: TutorialContent
    let onDismiss: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(showContent ? 0.8 : 0)
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.3), value: showContent)
                .onTapGesture { dismiss() }

            VStack(spacing: 20) {
                // Emoji + Title
                Text(content.emoji)
                    .font(.system(size: 52))
                    .accessibilityLabel(content.title)

                Text(content.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                // Rules
                VStack(alignment: .leading, spacing: 10) {
                    Text("How to Play")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.5)

                    ForEach(Array(content.rules.enumerated()), id: \.offset) { _, rule in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(rule)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Controls
                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                    Text(content.controls)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 4)

                // Dismiss button
                Button(action: { dismiss() }) {
                    Text("Got it!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.blue)
                                .shadow(color: .blue.opacity(0.3), radius: 8, y: 4)
                        )
                }
                .accessibilityLabel("Dismiss tutorial")
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 300)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
            )
            .scaleEffect(showContent ? 1 : 0.8)
            .opacity(showContent ? 1 : 0)
            .offset(y: showContent ? 0 : 30)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showContent)
        }
        .onAppear { showContent = true }
    }

    private func dismiss() {
        HapticManager.impact(.light)
        SoundManager.playButtonTap()
        withAnimation(.easeOut(duration: 0.2)) {
            showContent = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onDismiss()
        }
    }
}

// MARK: - Tutorial Info Button

struct TutorialInfoButton: View {
    let action: () -> Void

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    SoundManager.playButtonTap()
                    action()
                }) {
                    Image(systemName: "questionmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .accessibilityLabel("How to play")
                .padding(.leading, 8)
                Spacer()
            }
            Spacer()
        }
    }
}
