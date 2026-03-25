import SwiftUI

struct GridlockView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionTracker: SessionTracker
    @EnvironmentObject var statsManager: GameStatsManager
    @EnvironmentObject var profileManager: PlayerProfileManager

    @StateObject private var engine = GridlockGameEngine()
    @State private var action: GridlockAction = .none
    @State private var isPaused = false
    @State private var showTutorial = false
    @State private var showResult = false
    @State private var winner: Int = 0
    @State private var showAutomation = false
    @AppStorage("hasSeenTutorial_Gridlock") private var hasSeenTutorial = false

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.07)
    private let hexSize: CGFloat = 22

    var body: some View {
        GameTransitionView {
            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Top bar
                    topBar

                    // Hex grid
                    HexGridView(
                        engine: engine,
                        currentPlayer: engine.currentPlayer,
                        hexSize: hexSize,
                        action: action,
                        onHexTap: handleHexTap
                    )

                    // Bottom action bar
                    bottomBar
                }

                // Turn transition overlay
                if case .transition(let nextPlayer) = engine.phase {
                    turnTransitionOverlay(nextPlayer: nextPlayer)
                }

                // Build menu
                if action == .buildMenu {
                    buildMenuOverlay
                }

                // Deploy menu
                if action == .deployMenu {
                    deployMenuOverlay
                }

                // Automation editor
                if showAutomation {
                    AutomationEditorView(
                        engine: engine,
                        player: engine.currentPlayer,
                        onDismiss: { showAutomation = false }
                    )
                    .transition(.move(edge: .bottom))
                }

                // Game overlays
                GameOverlay(
                    onBack: { dismiss() },
                    onPause: { isPaused = true }
                )

                TutorialInfoButton { showTutorial = true }

                if showTutorial {
                    TutorialOverlayView(content: .gridlock) {
                        showTutorial = false
                        hasSeenTutorial = true
                    }
                }

                if isPaused {
                    PauseOverlay(
                        score1: playerScore(1),
                        score2: playerScore(2),
                        player1Color: .cyan,
                        player2Color: .red,
                        onResume: { isPaused = false },
                        onRestart: { restartGame() },
                        onExit: { dismiss() }
                    )
                }

                if showResult {
                    if winner > 0 {
                        WinnerOverlay(
                            winner: winner,
                            onPlayAgain: { restartGame() },
                            onExit: { dismiss() }
                        )
                    } else {
                        DrawOverlay(
                            onPlayAgain: { restartGame() },
                            onExit: { dismiss() }
                        )
                    }
                }
            }
        }
        .onAppear {
            engine.startNewGame()
            if !hasSeenTutorial {
                showTutorial = true
            }
        }
        .onDisappear {
            engine.stopTimers()
        }
        .onChange(of: engine.phase) { _, newPhase in
            if case .gameOver(let w) = newPhase {
                engine.stopTimers()
                winner = w
                if w > 0 {
                    sessionTracker.recordWin(player: w, gameType: "Gridlock")
                    statsManager.recordWin(player: w, game: "Gridlock")
                    SoundManager.playWin()
                } else {
                    statsManager.recordDraw(game: "Gridlock")
                    SoundManager.playDraw()
                }
                HapticManager.notification(.success)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showResult = true
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Player indicator
                playerIndicator

                Spacer()

                // Timer
                timerView

                Spacer()

                // AP Battery
                apBattery
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Resources bar
            resourceBar
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)
        )
    }

    private var playerIndicator: some View {
        let color: Color = engine.currentPlayer == 1 ? .cyan : .red
        let name = engine.currentPlayer == 1 ? profileManager.player1.name : profileManager.player2.name
        let emoji = engine.currentPlayer == 1 ? profileManager.player1.emoji : profileManager.player2.emoji

        return HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 16))
            Text(name)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        )
    }

    private var timerView: some View {
        let minutes = Int(engine.gameTimeRemaining) / 60
        let seconds = Int(engine.gameTimeRemaining) % 60
        let isUrgent = engine.gameTimeRemaining < 60

        return Text(String(format: "%d:%02d", minutes, seconds))
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(isUrgent ? .red : .white.opacity(0.7))
            .scaleEffect(isUrgent ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isUrgent)
    }

    private var apBattery: some View {
        let ap = engine.currentAP()
        let maxAP = 10
        let color: Color = engine.currentPlayer == 1 ? .cyan : .red

        return HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12))
                .foregroundStyle(color)

            // Battery segments
            HStack(spacing: 1.5) {
                ForEach(0..<maxAP, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(i < ap ? color : color.opacity(0.15))
                        .frame(width: 5, height: 14)
                }
            }

            Text("\(ap)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
                .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
        )
    }

    private var resourceBar: some View {
        let res = engine.currentResources()

        return HStack(spacing: 12) {
            resourceBadge(emoji: "🔩", value: res.iron, color: ResourceType.iron.color)
            resourceBadge(emoji: "💎", value: res.crystal, color: ResourceType.crystal.color)
            resourceBadge(emoji: "⛽", value: res.fuel, color: ResourceType.fuel.color)
            resourceBadge(emoji: "📡", value: res.data, color: ResourceType.data.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }

    private func resourceBadge(emoji: String, value: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(emoji)
                .font(.system(size: 11))
            Text("\(value)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.1))
        )
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 10) {
            actionButton(title: "Build", icon: "hammer.fill", color: .orange) {
                action = action == .buildMenu ? .none : .buildMenu
            }

            actionButton(title: "Deploy", icon: "figure.walk", color: .yellow) {
                action = action == .deployMenu ? .none : .deployMenu
            }

            actionButton(title: "Auto", icon: "point.3.connected.trianglepath.dotted", color: .cyan) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAutomation = true
                }
            }

            Spacer()

            // End Turn button
            Button {
                action = .none
                engine.endTurn()
            } label: {
                HStack(spacing: 6) {
                    Text("END TURN")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .overlay(Capsule().stroke(Color.purple.opacity(0.4), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        )
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
            }
            .foregroundStyle(color)
            .frame(width: 52, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Turn Transition

    private func turnTransitionOverlay(nextPlayer: Int) -> some View {
        let color: Color = nextPlayer == 1 ? .cyan : .red
        let name = nextPlayer == 1 ? profileManager.player1.name : profileManager.player2.name
        let emoji = nextPlayer == 1 ? profileManager.player1.emoji : profileManager.player2.emoji

        return ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("PASS DEVICE TO")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(4)

                Text(emoji)
                    .font(.system(size: 60))

                Text(name)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)

                Text("Player \(nextPlayer)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color.opacity(0.6))

                Button {
                    engine.startNextPlayerTurn()
                    action = .none
                    HapticManager.impact(.medium)
                } label: {
                    HStack(spacing: 8) {
                        Text("TAP TO START TURN")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                        Image(systemName: "play.fill")
                    }
                    .foregroundStyle(color)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(color.opacity(0.15))
                            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1.5))
                    )
                }
                .padding(.top, 20)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Build Menu

    private var buildMenuOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                // Handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)

                Text("BUILD")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.orange)
                    .tracking(3)
                    .padding(.bottom, 8)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach([BuildingType.extractor, .relay, .factory, .turret, .sensor], id: \.rawValue) { type in
                        buildingCard(type: type)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

                Button {
                    action = .none
                    HapticManager.impact(.light)
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 70)
        }
        .transition(.move(edge: .bottom))
    }

    private func buildingCard(type: BuildingType) -> some View {
        let cost = type.resourceCost
        let canAfford = engine.currentResources().canAfford(cost) && engine.currentAP() >= type.apCost

        return Button {
            action = .placingBuilding(type)
            HapticManager.impact(.light)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(type.color)

                Text(type.displayName)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                // Cost
                VStack(spacing: 1) {
                    if cost.iron > 0 {
                        Text("🔩\(cost.iron)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    if cost.crystal > 0 {
                        Text("💎\(cost.crystal)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    if cost.data > 0 {
                        Text("📡\(cost.data)")
                            .font(.system(size: 9, design: .monospaced))
                    }
                }
                .foregroundStyle(.white.opacity(0.5))

                Text("\(type.apCost) AP")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(canAfford ? type.color.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(canAfford ? type.color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .opacity(canAfford ? 1.0 : 0.4)
        }
        .disabled(!canAfford)
    }

    // MARK: - Deploy Menu

    private var deployMenuOverlay: some View {
        VStack {
            Spacer()

            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.vertical, 8)

                Text("DEPLOY UNIT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .tracking(3)
                    .padding(.bottom, 8)

                if !engine.buildings.contains(where: { $0.type == .factory && $0.owner == engine.currentPlayer }) {
                    Text("Build a Factory first!")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 20)
                } else {
                    HStack(spacing: 12) {
                        ForEach([UnitType.scout, .soldier, .tank], id: \.rawValue) { type in
                            unitCard(type: type)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }

                Button {
                    action = .none
                    HapticManager.impact(.light)
                } label: {
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.08, green: 0.08, blue: 0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 70)
        }
        .transition(.move(edge: .bottom))
    }

    private func unitCard(type: UnitType) -> some View {
        let cost = type.resourceCost
        let canAfford = engine.canDeployUnit(type)

        return Button {
            action = .placingUnit(type)
            HapticManager.impact(.light)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(type.color)

                Text(type.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Text("❤️\(type.hp)")
                    Text("⚔️\(type.attack)")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

                VStack(spacing: 1) {
                    if cost.iron > 0 { Text("🔩\(cost.iron)").font(.system(size: 9, design: .monospaced)) }
                    if cost.crystal > 0 { Text("💎\(cost.crystal)").font(.system(size: 9, design: .monospaced)) }
                    if cost.fuel > 0 { Text("⛽\(cost.fuel)").font(.system(size: 9, design: .monospaced)) }
                }
                .foregroundStyle(.white.opacity(0.5))

                Text("1 AP")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(canAfford ? type.color.opacity(0.1) : Color.gray.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(canAfford ? type.color.opacity(0.3) : Color.gray.opacity(0.1), lineWidth: 1)
                    )
            )
            .opacity(canAfford ? 1.0 : 0.4)
        }
        .disabled(!canAfford)
    }

    // MARK: - Hex Tap Handler

    private func handleHexTap(_ coord: HexCoord) {
        switch action {
        case .placingBuilding(let type):
            if engine.placeBuilding(type, at: coord) {
                action = .none
            }
        case .placingUnit(let type):
            if engine.deployUnit(type, at: coord) {
                action = .none
            }
        case .selectingTarget(let unitId):
            engine.assignTarget(unitId: unitId, target: coord)
            action = .none
            HapticManager.impact(.light)
        default:
            // Tap on own unit to assign target
            let ownUnits = engine.units(at: coord).filter { $0.owner == engine.currentPlayer }
            if let unit = ownUnits.first {
                action = .selectingTarget(unit.id)
                HapticManager.impact(.light)
            }
        }
    }

    // MARK: - Helpers

    private func playerScore(_ player: Int) -> Int {
        engine.playerStates[player]?.resources.total ?? 0
    }

    private func restartGame() {
        showResult = false
        winner = 0
        action = .none
        engine.startNewGame()
    }
}
