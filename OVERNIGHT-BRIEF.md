# Overnight Improvement Brief — 2P Games iOS App (v2)

## Context
This is a SwiftUI + SpriteKit iOS app with 6 games: Ping Pong, Air Hockey, Tic Tac Toe, Connect Four, Reaction Time, and Simon Says.
Bundle ID: `com.windsorsoft.TwoPlayerGames`. Distributed via TestFlight.
Target: iOS 17.0+, portrait only, iPhone + iPad.
Team: Windsor Software Inc. (B5ZCBUNYZ8).

The app already has a Game Center integration (GameCenterManager.swift) — don't remove or break it.

## Project Structure
- `TwoPlayerGames/` — main app
  - `TwoPlayerGamesApp.swift` — entry point (has Game Center auth)
  - `Views/HomeView.swift` — home/menu screen (has trophy button for Game Center)
  - `Views/GameOverlay.swift` — score overlay, WinnerOverlay, DrawOverlay, confetti
  - `Views/SettingsView.swift` — app settings
  - `Games/PingPong/` — Ping Pong (SpriteKit)
  - `Games/AirHockey/` — Air Hockey (SpriteKit)
  - `Games/TicTacToe/` — Tic Tac Toe (SwiftUI)
  - `Games/ConnectFour/` — Connect Four (SwiftUI)
  - `Games/ReactionTime/` — Reaction Time (SwiftUI)
  - `Games/SimonSays/` — Simon Says (SwiftUI)
  - `Utilities/HapticManager.swift` — haptic feedback
  - `Utilities/SoundManager.swift` — sound effects
  - `Utilities/GameSettings.swift` — settings (scores, speed, sound/haptics toggles)
  - `Utilities/GameCenterManager.swift` — Game Center integration (leaderboards, achievements)
  - `TwoPlayerGames.entitlements` — Game Center entitlement

## PRIORITY 1: Session Score Tracking

Build a **session scoreboard** that tracks Player 1 vs Player 2 wins/losses across all games played in a single app session.

### Requirements:
- Create a `SessionTracker` (ObservableObject) that persists across game sessions within one app launch
- Track: total P1 wins, total P2 wins, wins per game type, games played count
- Show a **session scoreboard** on the home screen — a compact card showing "P1: 5 — P2: 3" (or similar)
- The scoreboard should be tappable to show a detailed breakdown (which games each player won)
- Session resets when the app is force-quit (it's session-level, not persistent)
- After each game ends (in WinnerOverlay), update the session tracker
- Add a "Reset Session" button somewhere accessible

## PRIORITY 2: Pause/Exit UX Improvements

The current exit experience is just an X button. Improve it:

### Pause Menu:
- Tapping the X (or a new pause icon) should **pause the game** and show a pause overlay
- For SpriteKit games: actually pause the scene (`scene.isPaused = true`)
- Pause overlay should show:
  - "Paused" title
  - **Resume** button (go back to game)
  - **Restart** button (reset current game)
  - **Exit to Menu** button (go back to home)
  - Current score display
- The pause menu should have the same frosted glass style as other overlays
- Prevent accidental exits — no more instant dismiss on X tap

### iOS Integration:
- Handle app backgrounding: auto-pause when app goes to background (`scenePhase`)
- Resume properly when coming back to foreground
- Support the Dynamic Island / Live Activity showing current game score (stretch goal — skip if too complex)

## PRIORITY 3: New Creative Games (add 3-4 new games)

Research-inspired ideas for **same-device 2-player** games. Pick the best 3-4 and implement them well:

### Game Ideas (pick from these or come up with better ones):

1. **Tap Race / Tug of War** — Split screen vertically. Each player taps their half as fast as possible. A bar/rope in the middle moves toward whoever is tapping faster. First to pull it to their side wins. Simple, intense, great party game. Think of it like a tug-of-war rope visual.

2. **Territory / Color Conquest** — Grid of neutral squares. Each player taps squares on their half to claim them (they turn blue/red). Some squares are worth more points. Timer counts down. Most territory when time runs out wins. Could add power-ups (bomb that claims a 3x3 area, shield that protects squares).

3. **Finger Sumo / Bumper Push** — Each player controls a circle (like air hockey paddles) but the goal is to push the OTHER player's circle off the screen/out of a ring. Physics-based. Best of 3 rounds. Think sumo wrestling with fingers.

4. **Duel Draw** — One player draws a prompt, the other guesses. Then swap. Built-in word list. Timer. Points for correct guesses. Like Pictionary but split-screen on one phone.

5. **Memory Match Duel** — Classic memory/concentration card game but competitive. Players take turns flipping 2 cards. If they match, you keep them and go again. Most pairs wins. Cards should have fun icons/emojis.

6. **Reflex Duel / Quick Draw** — Wild West style. Screen shows "WAIT..." for a random time, then "DRAW!" — first player to tap their side wins the round. If you tap during "WAIT", you lose that round. Best of 5.

7. **Rhythm Tap Battle** — Targets fall from both ends of the screen toward the middle. Each player taps when targets hit the line. Accuracy determines points. Increasingly fast. Like Guitar Hero but competitive on one phone.

8. **Maze Race** — Split screen. Two identical randomly-generated mazes. Both players navigate with swipe gestures simultaneously. First to reach the exit wins.

Choose games that:
- Work great on a single phone screen (portrait, split-screen or alternating turns)
- Have satisfying haptics and sound
- Are quick rounds (30 seconds to 2 minutes per game)
- Are genuinely fun and feel different from the existing 6 games

For each new game:
- Create a new folder under `Games/`
- Add the game card to HomeView's game list with a fitting icon, title, subtitle, and gradient colors
- Add the game type to the GameType enum
- Add a win score setting in GameSettings
- Wire up WinnerOverlay with the correct gameType for Game Center
- Add a matching leaderboard ID in GameCenterManager

## PRIORITY 4: Visual Polish & Feel

- **Transitions**: Smooth enter/exit animations for all game screens
- **Haptics**: Make sure EVERY interaction has appropriate haptic feedback
- **Sound**: Different sound effects for different events across all games
- **Home screen**: If it looks like it could use a refresh with the new games, improve it
- **Dark theme**: Keep the cohesive dark theme with accent colors
- **Score banners**: All games should use FrostedScoreBanner consistently
- **Celebrate wins**: WinnerOverlay and confetti should feel satisfying everywhere

## Technical Notes
- Build with `xcodebuild -project TwoPlayerGames.xcodeproj -scheme TwoPlayerGames -sdk iphonesimulator -destination "id=56D068B8-7417-4074-B503-97438DCE6D2F" build`
- Test in iPhone 16 simulator (already booted: `56D068B8-7417-4074-B503-97438DCE6D2F`)
- Keep bundle ID as `com.windsorsoft.TwoPlayerGames`
- Portrait orientation only
- Git commits: use `-c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp"`
- Push to `main` branch when done
- DO NOT remove or break the existing Game Center integration
- DO NOT change the app icon

## When Done
1. Make sure it builds clean with no warnings
2. Commit and push all changes
3. Run: `openclaw system event --text "Done: Overnight 2P Games improvements — [brief summary of what was built/improved]" --mode now`
