import SwiftUI

struct SonarDuelLobbyView: View {
    @ObservedObject var networkManager: SonarDuelNetworkManager
    let onGameStart: () -> Void
    let onBack: () -> Void

    @State private var mode: LobbyMode = .choosing
    @State private var pulseScale: CGFloat = 1.0
    @State private var radarAngle: Double = 0

    enum LobbyMode {
        case choosing
        case hosting
        case browsing
    }

    var body: some View {
        ZStack {
            // Background
            Color(red: 0.04, green: 0.08, blue: 0.18)
                .ignoresSafeArea()

            // Radar background effect
            radarBackground

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button {
                        HapticManager.impact(.light)
                        if mode == .choosing {
                            onBack()
                        } else {
                            networkManager.stopHosting()
                            networkManager.stopBrowsing()
                            mode = .choosing
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                    Text("SONAR DUEL")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .tracking(4)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()

                if networkManager.isConnected {
                    connectedView
                } else {
                    switch mode {
                    case .choosing:
                        choosingView
                    case .hosting:
                        hostingView
                    case .browsing:
                        browsingView
                    }
                }

                Spacer()
            }
        }
    }

    // MARK: - Radar Background

    private var radarBackground: some View {
        ZStack {
            // Concentric circles
            ForEach(1..<5) { i in
                Circle()
                    .stroke(Color(red: 0.1, green: 0.4, blue: 0.3).opacity(0.15), lineWidth: 1)
                    .frame(width: CGFloat(i) * 100, height: CGFloat(i) * 100)
            }

            // Sweep line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.3), Color.clear],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(width: 2, height: 200)
                .offset(y: -100)
                .rotationEffect(.degrees(radarAngle))
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                radarAngle = 360
            }
        }
    }

    // MARK: - Mode Views

    private var choosingView: some View {
        VStack(spacing: 24) {
            // Submarine icon
            Image(systemName: "sailboat.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        pulseScale = 1.1
                    }
                }

            Text("LAN Submarine Battle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Both players must be on the same WiFi network")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 14) {
                lobbyButton(title: "Host Game", subtitle: "Create a room", icon: "antenna.radiowaves.left.and.right", color: Color(red: 0.2, green: 0.85, blue: 0.8)) {
                    HapticManager.impact(.medium)
                    mode = .hosting
                    networkManager.startHosting()
                }

                lobbyButton(title: "Join Game", subtitle: "Find a room", icon: "magnifyingglass", color: Color(red: 0.4, green: 0.7, blue: 1.0)) {
                    HapticManager.impact(.medium)
                    mode = .browsing
                    networkManager.startBrowsing()
                }
            }
            .padding(.horizontal, 40)
        }
    }

    private var hostingView: some View {
        VStack(spacing: 20) {
            // Pulsing broadcast indicator
            ZStack {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color(red: 0.2, green: 0.85, blue: 0.8).opacity(0.3), lineWidth: 2)
                        .frame(width: 60 + CGFloat(i) * 30, height: 60 + CGFloat(i) * 30)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.3),
                            value: pulseScale
                        )
                }

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 28))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
            }

            Text("Hosting Game...")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            Text("Waiting for opponent to join")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.4))

            ProgressView()
                .tint(Color(red: 0.2, green: 0.85, blue: 0.8))
        }
    }

    private var browsingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(Color(red: 0.4, green: 0.7, blue: 1.0))

            Text("Available Games")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)

            if networkManager.availableHosts.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color(red: 0.4, green: 0.7, blue: 1.0))
                    Text("Searching for hosts...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(networkManager.availableHosts, id: \.displayName) { host in
                        Button {
                            HapticManager.impact(.medium)
                            networkManager.joinHost(host)
                        } label: {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                                Text(host.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("Join")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.8))
                            }
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(red: 0.2, green: 0.85, blue: 0.8).opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }

    private var connectedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.2, green: 0.9, blue: 0.4))

            Text("Connected!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            if let name = networkManager.connectedPeerName {
                Text("Opponent: \(name)")
                    .font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if networkManager.isHost {
                Button {
                    HapticManager.impact(.heavy)
                    SoundManager.playButtonTap()
                    onGameStart()
                } label: {
                    Text("START BATTLE")
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(red: 0.2, green: 0.85, blue: 0.8))
                        )
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                        .tint(.white)
                    Text("Waiting for host to start...")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Helpers

    private func lobbyButton(title: String, subtitle: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(color)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.white.opacity(0.2))
                    .font(.system(size: 13, weight: .semibold))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(color.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(GameCardButtonStyle())
    }
}
