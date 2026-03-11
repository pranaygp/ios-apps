# Overnight Brief — Dots & Boxes

## Goal
Add a new game: **Dots & Boxes** — the classic pencil-and-paper strategy game.

## Game Rules
- Grid of dots (start with 5×5 = 25 dots, so 4×4 boxes)
- Players take turns tapping to draw a line between two adjacent dots (horizontal or vertical)
- When a player completes the fourth side of a box, they claim that box (colored in their color) and get another turn
- Game ends when all boxes are claimed
- Player with the most boxes wins

## Design
- Player 1 = Blue, Player 2 = Red (match existing game color scheme)
- Dots rendered as circles, lines drawn between them on tap
- Highlight which line will be drawn on tap/hover proximity
- Completed boxes fill with the player's color (with a subtle animation)
- Score display at top showing box count for each player
- Current player indicator
- End game screen showing winner with box counts

## Technical
- Follow the existing game pattern (look at TicTacToe or ConnectFour for structure)
- Each game is a SwiftUI View in its own folder under `TwoPlayerGames/Games/`
- Register the new game in the main game list/menu
- Use the existing GameCenterManager for leaderboard integration if applicable
- Support the existing pause button UX (long-press, center-right position)
- Make sure it compiles cleanly with the existing Xcode project

## UX Polish
- Satisfying line-drawing animation (line appears with a quick stroke animation)
- Box fill animation when completed (subtle scale + fade in)
- Haptic feedback on line placement and box completion
- "Extra turn!" indicator when a player completes a box
- Clear visual feedback for whose turn it is
- Grid should be centered and sized appropriately for different iPhone screens

## After Implementation
1. Make sure it compiles: `xcodebuild -project TwoPlayerGames.xcodeproj -scheme TwoPlayerGames -sdk iphonesimulator build`
2. Commit all changes with a descriptive message
3. Push to main
4. Notify via: `openclaw system event --message "🎮 Dots & Boxes implementation complete — ready for TestFlight build"`
