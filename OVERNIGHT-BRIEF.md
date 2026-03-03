# Overnight Improvement Brief — 2 Player Games iOS App

## Context
This is a SwiftUI + SpriteKit iOS app with 3 games: Ping Pong, Air Hockey, and Tic Tac Toe.
It's distributed via TestFlight under bundle ID `com.windsorsoft.TwoPlayerGames`.
The app currently works but feels like a prototype — the goal is to make it feel **production-ready and fun**.

## Project Structure
- `TwoPlayerGames/` — main app
  - `TwoPlayerGamesApp.swift` — entry point
  - `Views/HomeView.swift` — home/menu screen
  - `Views/GameOverlay.swift` — score overlay during games
  - `Games/PingPong/` — Ping Pong (SpriteKit)
  - `Games/AirHockey/` — Air Hockey (SpriteKit)
  - `Games/TicTacToe/` — Tic Tac Toe (SwiftUI)
  - `Utilities/HapticManager.swift` — haptic feedback
  - `Utilities/SoundManager.swift` — sound effects (system sounds)
- Target: iOS 17.0+, portrait only, iPhone + iPad
- Team: Windsor Software Inc. (55V8CMUR8N)

## Known Issues to Fix
1. **Ping Pong**: Ball angle physics were recently improved but may need more tuning — test it
2. **Air Hockey**: Momentum transfer was just added — the puck should feel weighty and responsive
3. **Touch targets**: Paddles should be easy to grab with a finger (40pt+ touch area)
4. **General polish**: Transitions between screens feel abrupt

## What to Build/Improve

### 1. Visual Polish (HIGH PRIORITY)
- Better home screen design — make it look like a real game app, not a prototype
- Animated backgrounds or subtle particle effects
- Smooth transitions between screens
- Better color palette — cohesive dark theme with accent colors
- Score displays should look great (not just text overlays)
- Victory/game-over screen with animations
- Add a subtle glow/trail effect to the pong ball and air hockey puck

### 2. More Games (HIGH PRIORITY)
Add at least 2-3 more games. Ideas:
- **Connect Four** — classic drop-disc game (SwiftUI)
- **Dots and Boxes** — draw lines, claim boxes
- **Tank Battle** — each player controls a tank, shoot each other (SpriteKit)
- **Finger Sumo / Thumb Wrestling** — physics-based pushing game
- **Reaction Time** — who can tap fastest when the screen changes color
- **Memory Match** — take turns flipping cards
Pick whichever are most fun and feasible. Quality > quantity.

### 3. Game Settings
- Adjustable win score for each game
- Difficulty/speed settings for Pong
- Sound on/off toggle
- Haptics on/off toggle  
- Settings accessible from home screen AND during games

### 4. Local Multiplayer over Network (STRETCH GOAL)
- Use **MultipeerConnectivity** framework for WiFi/Bluetooth P2P
- Start with one game that supports it (e.g., Tic Tac Toe is simplest)
- Host/Join flow — one device creates game, other joins
- Each player sees their own perspective
- This is a stretch goal — only if time permits after the above

### 5. Sound & Haptics
- Custom sound effects (use system sounds or generate with AudioToolbox)
- Different sounds for different events (hit, score, win, lose)
- Satisfying haptics on every interaction
- Background ambient sound option

### 6. General Production Quality
- App icon is already set (don't change it)
- Launch screen / splash animation
- Smooth 60fps — profile and optimize if needed
- No crashes, no warnings
- Clean code, good structure

## Technical Notes
- Build with `xcodebuild` to verify — target iOS 17.0
- Test in iPhone 16 simulator (already booted: `56D068B8-7417-4074-B503-97438DCE6D2F`)
- Keep bundle ID as `com.windsorsoft.TwoPlayerGames`
- Portrait orientation only (iPad supports all orientations for multitasking compliance)
- Git commits: use `-c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp"`
- Push to `main` branch when done

## When Done
1. Make sure it builds clean with no warnings
2. Commit and push all changes
3. Run: `openclaw system event --text "Done: Overnight game improvements complete — [brief summary]" --mode now`
