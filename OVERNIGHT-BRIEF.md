# Overnight Brief — Mancala (Build 29)

## Goal
Add a Mancala game to the 2P Games app. Classic Kalah rules (6 pits per side, 4 stones each, capture mechanic).

## Rules (Kalah variant)
- Board: 2 rows of 6 pits, 1 store (mancala) per player on their right
- Start: 4 stones in each of the 12 pits
- On your turn: pick up all stones from one of YOUR pits, sow counter-clockwise one stone per pit (including your own store, skip opponent's store)
- Extra turn: if your last stone lands in your own store, you go again
- Capture: if your last stone lands in an empty pit ON YOUR SIDE, capture that stone plus all stones in the opposite pit → move all to your store
- Game ends when one side is completely empty; remaining stones on the other side go to that player's store
- Winner: most stones in store

## Implementation Requirements

### File Structure
- `TwoPlayerGames/Games/Mancala/MancalaView.swift` — main game view
- `TwoPlayerGames/Games/Mancala/MancalaGame.swift` — game logic model

### Visual Design
- Wooden board aesthetic (warm browns, wood grain feel)
- Oval pits with stone counts
- Stones should be colorful circles/pebbles (vary colors slightly)
- Smooth sowing animation: stones drop into pits one at a time with slight delay
- Highlight last-landed pit
- Player 2's side should be at the top (standard 2P split-screen orientation)
- Player 1's store on the right, Player 2's store on the left (when viewed from each player's perspective)
- Haptic feedback on stone pickup and drops

### Integration
- Add to HomeView under the **Strategy** category (alongside Checkers, Reversi, Battleship, etc.)
- Add tutorial overlay (TutorialOverlayView) with rules explanation
- Integrate with PlayerProfileManager for stats tracking (wins/losses)
- Support the existing game navigation pattern (back button, pause menu)
- Register in GameDefinition/game registry

### Quality Checklist
- [ ] Game logic is correct (extra turns, captures, game end)
- [ ] Both players can play (P1 bottom, P2 top)
- [ ] Animations are smooth
- [ ] Tutorial overlay works
- [ ] Stats tracking integrated
- [ ] No build errors
- [ ] Committed and pushed

## Build Steps
1. Implement game logic model
2. Build SwiftUI view with animations
3. Add tutorial overlay
4. Register in HomeView under Strategy category
5. Bump CURRENT_PROJECT_VERSION to 29
6. Build to verify no errors: `xcodebuild -project TwoPlayerGames.xcodeproj -scheme TwoPlayerGames -sdk iphoneos -destination generic/platform=iOS -allowProvisioningUpdates DEVELOPMENT_TEAM=55V8CMUR8N build`
7. If build succeeds, commit and push: `git -c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp" add -A && git -c commit.gpgsign=false -c user.name="Clawdius" -c user.email="clawdbot@pranay.gp" commit -m "Add Mancala: classic 2P stone-sowing strategy game (build 29)"`
8. Push: `git push origin main`
9. Archive for TestFlight: `xcodebuild archive -project TwoPlayerGames.xcodeproj -scheme TwoPlayerGames -archivePath /tmp/2PGames.xcarchive -sdk iphoneos -allowProvisioningUpdates DEVELOPMENT_TEAM=55V8CMUR8N`
10. Upload: `xcodebuild -exportArchive -archivePath /tmp/2PGames.xcarchive -exportPath /tmp/2PGames-export -exportOptionsPlist /tmp/ExportOptions.plist -allowProvisioningUpdates`

## Reference
Look at existing games for patterns:
- `TwoPlayerGames/Games/Checkers/` — good example of board game with grid layout
- `TwoPlayerGames/Games/Reversi/` — similar turn-based strategy pattern
- `TwoPlayerGames/Views/TutorialOverlayView.swift` — tutorial overlay integration
- `TwoPlayerGames/Views/HomeView.swift` — game registration and categories
