# Overnight Brief — Duel Draw

## What to Build
**Duel Draw** — A competitive 2-player drawing/guessing game. One player draws a given word while the other watches and tries to guess it. Players take turns being the drawer/guesser. Most correct guesses wins.

## Design
- **Split-screen**: Player 1 on top (inverted), Player 2 on bottom — like all other 2P games in the app
- **Turn-based roles**: Each round, one player is the Drawer and the other is the Guesser. Roles alternate each round.
- **Drawing phase**:
  - Drawer sees the secret word at the top of their area (hidden from guesser)
  - Drawer gets a canvas to draw on with finger — simple line drawing
  - Color palette: 5-6 colors (black, red, blue, green, orange, purple) + eraser
  - 2-3 brush sizes (thin, medium, thick)
  - Clear button to reset canvas
  - 30-second timer per round
- **Guessing phase**:
  - Guesser sees the drawing appear in real-time (mirrored from drawer's canvas)
  - Guesser has a text field to type guesses
  - Each guess shows as a bubble (wrong guesses in red, correct in green)
  - On correct guess: both players see ✅ celebration, guesser gets points
  - If timer runs out: reveal the word, no points
- **Word bank**: Built-in list of ~100 simple, drawable words (cat, house, sun, tree, car, airplane, pizza, guitar, etc.)
- **Scoring**: 1 point per correct guess + time bonus (faster = more points). 8 rounds total (4 per player as drawer).
- **Visual style**: Clean, playful — white canvas, colorful UI, fun animations on correct guesses
- **No audio needed** — purely visual + haptic

## Technical Notes
- Follow the same patterns as existing games (GameView protocol, player scores, game state management)
- Drawing: Use SwiftUI Canvas or a custom Path-based drawing view that captures touch/drag gestures
- Mirror the drawing: both players see the same canvas content (use a shared @State array of line strokes)
- Word list: simple array of strings, pick randomly without repeats within a game
- Text input for guessing: use TextField with onSubmit
- Since both players are on the same device (split screen), hide the secret word from the guesser's view — show it ONLY in the drawer's half
- Add tutorial overlay (HowToPlayOverlay) like all other games
- Add to ContentView/HomeView game list with appropriate icon (🎨)

## Build Requirements
- Must compile without errors on iOS 17+ / Xcode
- Increment CURRENT_PROJECT_VERSION to **22** in the .pbxproj
- Commit with message: "Add Duel Draw: competitive 2P drawing and guessing game (build 22)"
- Push to main branch
- Use git config: `-c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp"`

## Quality Bar
- Smooth drawing experience (no lag on strokes)
- Clear role distinction (drawer vs guesser UI should be obviously different)
- Fun word list that's easy to draw
- Satisfying correct-guess animations
- The core loop should feel like a mini Pictionary — quick, fun, replayable
