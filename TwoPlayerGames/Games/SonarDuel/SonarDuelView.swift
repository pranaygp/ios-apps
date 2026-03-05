import SwiftUI
import SpriteKit

// MARK: - Phase

enum SonarDuelPhase: Equatable {
    case lobby
    case countdown(Int)
    case playing
    case gameOver(winner: PlayerRole)
}

// MARK: - Game Controller

@MainActor
class SonarDuelGameController: ObservableObject {
    @Published var gameState: GameState?
    @Published var phase: SonarDuelPhase = .lobby
    @Published var selectedAction: PlayerAction?
    @Published var turnTimeRemaining: Double = 5.0
    @Published var isActionLocked = false
    @Published var showDisconnectAlert = false

    var networkManager: SonarDuelNetworkManager!
    private(set) var myRole: PlayerRole = .host

    private var turnTimer: Timer?
    private var countdownTimer: Timer?
    private var scene: SonarDuelScene?
    private var bubbleTimer: Timer?

    var myPlayer: PlayerState? {
        guard let state = gameState else { return nil }
        return myRole == .host ? state.hostPlayer : state.guestPlayer
    }

    var enemyPlayer: PlayerState? {
        guard let state = gameState else { return nil }
        return myRole == .host ? state.guestPlayer : state.hostPlayer
    }

    func attach(network: SonarDuelNetworkManager) {
        self.networkManager = network
        network.onMessageReceived = { [weak self] message in
            self?.handleReceivedMessage(message)
        }
    }

    func setScene(_ scene: SonarDuelScene) {
        self.scene = scene
        if let state = gameState {
            scene.updateGameState(state, myRole: myRole, events: [])
        }
    }

    // MARK: - Host starts

    func hostStartGame() {
        myRole = .host
        let state = GameState.newGame()
        gameState = state
        networkManager.send(.gameStart(state: state))
        beginCountdown()
    }

    // MARK: - Countdown

    private func beginCountdown() {
        phase = .countdown(3)
        SoundManager.playCountdown()

        countdownTimer?.invalidate()
        var remaining = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                remaining -= 1
                if remaining > 0 {
                    self.phase = .countdown(remaining)
                    SoundManager.playCountdown()
                } else {
                    timer.invalidate()
                    SoundManager.playGo()
                    self.startPlaying()
                }
            }
        }
    }

    private func startPlaying() {
        phase = .playing
        isActionLocked = false
        selectedAction = nil
        if let state = gameState {
            scene?.updateGameState(state, myRole: myRole, events: [])
        }
        startTurnTimer()
        startBubbleTimer()
    }

    // MARK: - Actions

    func selectAction(_ action: PlayerAction) {
        guard !isActionLocked, case .playing = phase else { return }
        selectedAction = action
        HapticManager.impact(.light)
    }

    func lockInAction() {
        guard let action = selectedAction, !isActionLocked, case .playing = phase else { return }
        isActionLocked = true
        HapticManager.impact(.medium)

        gameState?.submitAction(action, for: myRole)
        networkManager.send(.action(action, from: myRole))

        if myRole == .host {
            checkBothActionsReady()
        }
    }

    // MARK: - Turn Resolution

    private func checkBothActionsReady() {
        guard myRole == .host, var state = gameState, state.bothActionsSubmitted else { return }
        stopTurnTimer()

        state.resolveTurn()
        gameState = state

        networkManager.send(.stateSync(state))

        scene?.updateGameState(state, myRole: myRole, events: state.events)
        processEventHaptics(state.events)

        if case .gameOver(let winner) = state.phase {
            handleGameOver(winner: winner)
        } else {
            scheduleNextTurn()
        }
    }

    private func processEventHaptics(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .torpedoHit(let target, _), .mineDetonated(_, let target):
                if target == myRole { HapticManager.notification(.error) }
            case .torpedoFired(let role, _):
                if role == myRole { HapticManager.impact(.medium) }
            case .pinged(let role, _):
                if role == myRole { HapticManager.impact(.light) }
            default: break
            }
        }
    }

    private func scheduleNextTurn() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.startNextTurn()
        }
    }

    private func startNextTurn() {
        isActionLocked = false
        selectedAction = nil
        phase = .playing
        startTurnTimer()
    }

    // MARK: - Timer

    private func startTurnTimer() {
        turnTimeRemaining = 5.0
        stopTurnTimer()
        turnTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.turnTimeRemaining -= 0.1
                if self.turnTimeRemaining <= 0 {
                    self.turnTimeRemaining = 0
                    self.autoSubmitAction()
                }
            }
        }
    }

    private func stopTurnTimer() {
        turnTimer?.invalidate()
        turnTimer = nil
    }

    private func stopAllTimers() {
        stopTurnTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        bubbleTimer?.invalidate()
        bubbleTimer = nil
    }

    private func startBubbleTimer() {
        bubbleTimer?.invalidate()
        bubbleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.scene?.spawnAmbientBubble()
            }
        }
    }

    private func autoSubmitAction() {
        guard !isActionLocked else { return }
        if selectedAction == nil { selectedAction = .none }
        lockInAction()
    }

    // MARK: - Network Messages

    func handleReceivedMessage(_ message: NetworkMessage) {
        switch message {
        case .gameStart(let state):
            myRole = .guest
            gameState = state
            beginCountdown()

        case .action(let action, let from):
            gameState?.submitAction(action, for: from)
            if myRole == .host { checkBothActionsReady() }

        case .stateSync(let state):
            if myRole == .guest {
                gameState = state
                scene?.updateGameState(state, myRole: myRole, events: state.events)
                processEventHaptics(state.events)

                if case .gameOver(let winner) = state.phase {
                    handleGameOver(winner: winner)
                } else {
                    scheduleNextTurn()
                }
            }

        case .rematch:
            if myRole == .host { hostStartGame() }

        case .disconnect:
            showDisconnectAlert = true
            stopAllTimers()
        }
    }

    // MARK: - Game Over

    private func handleGameOver(winner: PlayerRole) {
        stopAllTimers()
        let iWon = winner == myRole
        phase = .gameOver(winner: winner)

        if iWon {
            HapticManager.notification(.success)
            SoundManager.playWin()
            GameCenterManager.shared.reportWin(for: .sonarDuel)
            SessionTracker.shared.recordWin(
                player: myRole == .host ? 1 : 2,
                gameType: "Sonar Duel"
            )
        } else {
            HapticManager.notification(.error)
        }
    }

    func requestRematch() {
        networkManager.send(.rematch)
        if myRole == .host { hostStartGame() }
    }

    func cleanup() {
        stopAllTimers()
        networkManager?.disconnect()
    }
}

// MARK: - Main View

struct SonarDuelView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var networkManager = SonarDuelNetworkManager()
    @StateObject private var controller = SonarDuelGameController()

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.08, blue: 0.18)
                .ignoresSafeArea()

            switch controller.phase {
            case .lobby:
                SonarDuelLobbyView(
                    networkManager: networkManager,
                    onGameStart: { controller.hostStartGame() },
                    onBack: { controller.cleanup(); dismiss() }
                )
                .transition(.opacity)

            case .countdown(let count):
                countdownView(count: count)
                    .transition(.opacity)

            case .playing, .gameOver:
                SonarDuelGameView(controller: controller, onExit: {
                    controller.cleanup()
                    dismiss()
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: phaseCategory)
        .onAppear { controller.attach(network: networkManager) }
        .onDisappear { controller.cleanup() }
        .alert("Disconnected", isPresented: $controller.showDisconnectAlert) {
            Button("Return to Home") { controller.cleanup(); dismiss() }
        } message: {
            Text("Your opponent has disconnected.")
        }
    }

    private var phaseCategory: Int {
        switch controller.phase {
        case .lobby: return 0
        case .countdown: return 1
        case .playing: return 2
        case .gameOver: return 3
        }
    }

    private func countdownView(count: Int) -> some View {
        VStack(spacing: 24) {
            Text("BATTLE STATIONS")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .tracking(4)

            Text("\(count)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: count)

            if let name = networkManager.connectedPeerName {
                Text("vs \(name)")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Game View (Scene + HUD + Actions)

struct SonarDuelGameView: View {
    @ObservedObject var controller: SonarDuelGameController
    let onExit: () -> Void

    @State private var scene: SonarDuelScene?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.04, green: 0.08, blue: 0.18)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topHUD
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    if let scene {
                        SpriteView(scene: scene, options: [.allowsTransparency])
                            .frame(maxWidth: .infinity)
                            .frame(height: geo.size.height * 0.55)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 8)
                    }

                    if case .playing = controller.phase {
                        actionPanel
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }

                    Spacer(minLength: 0)
                }

                if case .gameOver(let winner) = controller.phase {
                    gameOverOverlay(iWon: winner == controller.myRole)
                }
            }
            .onAppear {
                let s = SonarDuelScene(size: CGSize(width: geo.size.width - 16, height: geo.size.height * 0.55))
                s.scaleMode = .aspectFit
                scene = s
                controller.setScene(s)
            }
        }
    }

    // MARK: - Top HUD

    private var topHUD: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("YOU")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8).opacity(0.7))
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < (controller.myPlayer?.hp ?? 3) ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(i < (controller.myPlayer?.hp ?? 3) ? Color(red: 0.2, green: 0.85, blue: 0.8) : Color.gray.opacity(0.3))
                    }
                }
            }

            Spacer()

            VStack(spacing: 2) {
                Text("TURN \(controller.gameState?.turnNumber ?? 1)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(timerColor)
                            .frame(width: geo.size.width * max(0, controller.turnTimeRemaining / 5.0))
                            .animation(.linear(duration: 0.1), value: controller.turnTimeRemaining)
                    }
                }
                .frame(width: 80, height: 4)

                if controller.isActionLocked {
                    Text("LOCKED IN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.4))
                } else {
                    Text(String(format: "%.1fs", max(0, controller.turnTimeRemaining)))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(timerColor)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("ENEMY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.red.opacity(0.7))
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Image(systemName: i < (controller.enemyPlayer?.hp ?? 3) ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundStyle(i < (controller.enemyPlayer?.hp ?? 3) ? Color.red : Color.gray.opacity(0.3))
                    }
                }
            }
        }
    }

    private var timerColor: Color {
        if controller.turnTimeRemaining > 3 { return Color(red: 0.2, green: 0.85, blue: 0.8) }
        if controller.turnTimeRemaining > 1.5 { return .yellow }
        return .red
    }

    // MARK: - Action Panel

    private var actionPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                // D-pad
                VStack(spacing: 4) {
                    Text("MOVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    VStack(spacing: 2) {
                        dpadButton(direction: .up, icon: "chevron.up")
                        HStack(spacing: 2) {
                            dpadButton(direction: .left, icon: "chevron.left")
                            ZStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.white.opacity(0.03))
                                    .frame(width: 40, height: 40)
                                if case .move = controller.selectedAction {
                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                                }
                            }
                            dpadButton(direction: .right, icon: "chevron.right")
                        }
                        dpadButton(direction: .down, icon: "chevron.down")
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        actionButton(
                            action: .ping, title: "SONAR",
                            icon: "dot.radiowaves.left.and.right",
                            color: Color(red: 0.1, green: 0.9, blue: 0.4),
                            subtitle: "Reveal 5×5"
                        )
                        actionButton(
                            action: .dropMine, title: "MINE",
                            icon: "circle.dotted",
                            color: Color(red: 1.0, green: 0.4, blue: 0.1),
                            subtitle: "\(controller.myPlayer?.minesPlaced ?? 0)/\(controller.myPlayer?.maxMines ?? 3)",
                            disabled: (controller.myPlayer?.minesPlaced ?? 0) >= (controller.myPlayer?.maxMines ?? 3)
                        )
                    }
                    VStack(spacing: 2) {
                        Text("TORPEDO")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        HStack(spacing: 4) {
                            torpedoButton(direction: .left, icon: "arrow.left")
                            torpedoButton(direction: .up, icon: "arrow.up")
                            torpedoButton(direction: .down, icon: "arrow.down")
                            torpedoButton(direction: .right, icon: "arrow.right")
                        }
                    }
                }
            }

            Button { controller.lockInAction() } label: {
                HStack {
                    Image(systemName: controller.isActionLocked ? "lock.fill" : "lock.open.fill")
                        .font(.system(size: 14))
                    Text(lockInLabel)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(controller.isActionLocked ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(lockInColor))
            }
            .disabled(controller.isActionLocked || controller.selectedAction == nil)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.03))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    private var lockInLabel: String {
        if controller.isActionLocked { return "LOCKED IN" }
        if controller.selectedAction != nil { return "LOCK IN ACTION" }
        return "SELECT ACTION"
    }

    private var lockInColor: Color {
        if controller.isActionLocked { return Color(red: 0.2, green: 0.9, blue: 0.4) }
        if controller.selectedAction != nil { return Color(red: 0.2, green: 0.85, blue: 0.8) }
        return Color.white.opacity(0.1)
    }

    private func dpadButton(direction: Direction, icon: String) -> some View {
        let isSelected: Bool = {
            if case .move(let d) = controller.selectedAction { return d == direction }
            return false
        }()
        return Button { controller.selectAction(.move(direction)) } label: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color(red: 0.2, green: 0.85, blue: 0.8) : Color.white.opacity(0.08))
                )
        }
        .disabled(controller.isActionLocked)
    }

    private func actionButton(action: PlayerAction, title: String, icon: String, color: Color, subtitle: String, disabled: Bool = false) -> some View {
        let isSelected = controller.selectedAction == action
        return Button { controller.selectAction(action) } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 18))
                Text(title).font(.system(size: 9, weight: .bold, design: .monospaced))
                Text(subtitle).font(.system(size: 8))
                    .foregroundStyle(isSelected ? color : .white.opacity(0.3))
            }
            .foregroundStyle(isSelected ? color : .white.opacity(0.6))
            .frame(width: 72, height: 64)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.15) : Color.white.opacity(0.05))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1.5))
            )
        }
        .disabled(controller.isActionLocked || disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }

    private func torpedoButton(direction: Direction, icon: String) -> some View {
        let isSelected: Bool = {
            if case .fireTorpedo(let d) = controller.selectedAction { return d == direction }
            return false
        }()
        let color = Color(red: 1.0, green: 0.7, blue: 0.1)
        return Button { controller.selectAction(.fireTorpedo(direction)) } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .black : color.opacity(0.7))
                .frame(width: 36, height: 30)
                .background(RoundedRectangle(cornerRadius: 6).fill(isSelected ? color : color.opacity(0.1)))
        }
        .disabled(controller.isActionLocked)
    }

    // MARK: - Game Over

    private func gameOverOverlay(iWon: Bool) -> some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: iWon ? "trophy.fill" : "xmark.shield.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(iWon ? Color.yellow : Color.red)

                Text(iWon ? "VICTORY!" : "DEFEATED")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Text(iWon ? "Enemy submarine destroyed" : "Your submarine was sunk")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))

                HStack(spacing: 30) {
                    VStack(spacing: 4) {
                        Text("YOU").font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(max(0, controller.myPlayer?.hp ?? 0)) HP")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                    }
                    Text("vs").foregroundStyle(.white.opacity(0.3))
                    VStack(spacing: 4) {
                        Text("ENEMY").font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(max(0, controller.enemyPlayer?.hp ?? 0)) HP")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 8)

                HStack(spacing: 16) {
                    Button { controller.requestRematch() } label: {
                        Text("REMATCH")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.2, green: 0.85, blue: 0.8)))
                    }
                    Button { onExit() } label: {
                        Text("EXIT")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 24).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))
                    }
                }
            }
            .padding(24)
        }
        .transition(.opacity)
    }
}
