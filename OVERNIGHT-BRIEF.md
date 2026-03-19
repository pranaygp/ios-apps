# Overnight Brief — Rhythm Tap

## What to Build
**Rhythm Tap** — A competitive 2-player rhythm/music game. Notes fall down lanes and players must tap them in time to the beat. Higher accuracy = more points. First to reach a score threshold or highest score when the song ends wins.

## Design
- **Split-screen**: Player 1 on top (inverted), Player 2 on bottom — like all other 2P games in the app
- **3 lanes per player**: Left, Center, Right columns where note targets fall
- **Hit zones**: Circular/rectangular targets at the bottom of each player's area
- **Notes**: Colored circles/shapes that fall from the top toward the hit zones
- **Timing window**: Perfect (100pts), Good (50pts), Miss (0pts) — show feedback text
- **Beat generation**: Procedurally generated patterns synced to a BPM (no audio files needed — use haptic feedback as the "beat"). Start at 100 BPM, increase difficulty over time
- **Visual style**: Neon/arcade aesthetic — dark background, glowing lanes, colorful notes. Think Guitar Hero meets a retro arcade
- **Round**: 60 seconds per round, best of 3 rounds
- **Haptics**: Tap feedback on hits, strong pulse on Perfect hits
- **Score display**: Running score for each player, combo counter for consecutive hits

## Technical Notes
- Follow the same patterns as existing games (GameView protocol, player scores, game state management)
- Use SwiftUI animations for falling notes (`.offset` + `withAnimation`)
- Timer-driven: use `Timer.publish` or `CADisplayLink` equivalent for smooth note movement
- No audio dependencies — purely visual + haptic rhythm game
- Each note is a struct with lane, timing, and speed
- Hit detection: when player taps a lane, check if any note is within the hit zone ± timing window
- Add tutorial overlay (HowToPlayOverlay) like all other games
- Add to ContentView game list with appropriate icon (🎵)

## Build Requirements
- Must compile without errors on iOS 17+ / Xcode
- Increment CURRENT_PROJECT_VERSION to **21** in the .pbxproj
- Commit with message: "Add Rhythm Tap: competitive 2P rhythm game (build 21)"
- Push to main branch
- Use git config: `-c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp"`

## Quality Bar
- Smooth 60fps note animations
- Responsive tap detection (no noticeable lag)
- Clear visual feedback for Perfect/Good/Miss
- Increasing difficulty (BPM ramps up through the round)
- Fun and replayable — the core loop should feel satisfying
