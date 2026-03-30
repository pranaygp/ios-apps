import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = GameSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sound Effects", isOn: $settings.soundEnabled)
                    if settings.soundEnabled {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .foregroundStyle(.secondary)
                            Slider(value: $settings.soundVolume, in: 0...1, step: 0.1)
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Sound Volume")
                        .accessibilityValue("\(Int(settings.soundVolume * 100))%")
                    }
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                } header: {
                    Text("General")
                }

                Section {
                    Stepper("Win Score: \(settings.pingPongWinScore)", value: $settings.pingPongWinScore, in: 1...15)
                        .accessibilityValue("\(settings.pingPongWinScore)")

                    Picker("Ball Speed", selection: $settings.pongBallSpeed) {
                        Text("Slow").tag(0)
                        Text("Normal").tag(1)
                        Text("Fast").tag(2)
                    }
                } header: {
                    Text("Ping Pong")
                }

                Section {
                    Stepper("Win Score: \(settings.airHockeyWinScore)", value: $settings.airHockeyWinScore, in: 1...15)
                        .accessibilityValue("\(settings.airHockeyWinScore)")
                } header: {
                    Text("Air Hockey")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.ticTacToeWinScore)", value: $settings.ticTacToeWinScore, in: 1...10)
                        .accessibilityValue("\(settings.ticTacToeWinScore)")
                } header: {
                    Text("Tic Tac Toe")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.connectFourWinScore)", value: $settings.connectFourWinScore, in: 1...10)
                        .accessibilityValue("\(settings.connectFourWinScore)")
                } header: {
                    Text("Connect Four")
                }

                Section {
                    Stepper("Win Score: \(settings.reactionTimeWinScore)", value: $settings.reactionTimeWinScore, in: 1...15)
                        .accessibilityValue("\(settings.reactionTimeWinScore)")
                } header: {
                    Text("Reaction Time")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.simonSaysWinScore)", value: $settings.simonSaysWinScore, in: 1...10)
                        .accessibilityValue("\(settings.simonSaysWinScore)")
                } header: {
                    Text("Simon Says")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.tugOfWarWinScore)", value: $settings.tugOfWarWinScore, in: 1...10)
                        .accessibilityValue("\(settings.tugOfWarWinScore)")
                } header: {
                    Text("Tug of War")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)

                    Link(destination: URL(string: "https://github.com/pranaygp/ios-apps")!) {
                        HStack {
                            Text("Source Code")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityLabel("Source code on GitHub")

                    HStack {
                        Spacer()
                        Text("Made with \u{2764}\u{FE0F} by Pranay")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .accessibilityLabel("Made with love by Pranay")
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
