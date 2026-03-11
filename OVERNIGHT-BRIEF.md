# Overnight Brief — Snake vs Snake 🐍⚔️🐍

## Goal
Add a new **Snake vs Snake** game to the 2P Games app. Two snakes on one screen, each controlled by a different player. Classic arcade gameplay — eat food to grow, avoid walls/yourself/the other snake. Last snake alive wins.

## Game Design

### Controls
- **Player 1 (Blue):** Swipe gestures on the LEFT half of the screen to change direction (up/down/left/right)
- **Player 2 (Red/Orange):** Swipe gestures on the RIGHT half of the screen
- Each player's touch zone is clearly divided with a subtle vertical line or gradient

### Gameplay
- Grid-based movement (like classic Snake)
- Grid size: ~20x30 cells (adapt to screen size, landscape or portrait)
- Both snakes start at opposite corners, moving in opposite directions
- Food spawns randomly — eating it grows the snake by 1 segment
- **Speed increases** slightly every 5 food items eaten (total across both players)
- Game ends when a snake hits: a wall, itself, or the other snake
- If both die simultaneously → draw
- Score display: show each player's length at top of screen

### Visuals
- Dark background (near black, like #1A1A2E)
- Player 1 snake: bright blue/cyan gradient segments with glow
- Player 2 snake: bright orange/red gradient segments with glow
- Food: pulsing green circle/apple emoji
- Grid lines: very subtle (10% opacity)
- Death animation: snake segments scatter/explode with particle effect
- Smooth movement with interpolation between grid cells (not jerky)
- Score/length display for each player, color-coded

### Sound & Haptics
- Use the existing SoundManager and HapticManager
- Eat food: light haptic + satisfying chomp sound
- Death: heavy haptic + crash sound
- Speed up: subtle notification haptic

## Technical Requirements

### File Structure
Create `TwoPlayerGames/Games/SnakeVsSnake/SnakeVsSnakeView.swift`
- Use SwiftUI with a Canvas or TimelineView for smooth 60fps rendering
- Game loop via Timer or DisplayLink pattern

### Integration with App
1. Add `case snakeVsSnake` to `HomeView.GameType` enum
2. Add a GameCard entry in HomeView's `games` array:
   - Title: "Snake vs Snake"
   - Subtitle: "Classic arcade duel"
   - Icon: "arrow.trianglehead.swap" or similar SF Symbol
   - Gradient: green-ish tones `[Color(red: 0.1, green: 0.8, blue: 0.4), Color(red: 0.05, green: 0.55, blue: 0.25)]`
3. Add the navigation destination in the `.fullScreenCover` or wherever games are presented
4. Support the existing GameOverlay (pause menu) pattern — check how other games use `isPaused` and `@Environment(\.scenePhase)`

### Patterns to Follow
- Look at existing games (DotsAndBoxesView, TicTacToeView, PingPongScene) for patterns
- Use `@Environment(\.dismiss)` for back navigation  
- Support the pause overlay pattern (GameOverlay)
- Use the existing color scheme / design language

### Build Number
- Bump `CURRENT_PROJECT_VERSION` in the .pbxproj to **15**

## After Implementation
1. Make sure it compiles: `xcodebuild build -project TwoPlayerGames.xcodeproj -scheme TwoPlayerGames -sdk iphonesimulator -destination "platform=iOS Simulator,name=iPhone 16" -quiet`
2. Commit all changes with a descriptive message
3. Push to main
4. Run: `openclaw system event --text "Done: Snake vs Snake game built — dual-snake arcade duel with swipe controls, speed scaling, death animations" --mode now`
