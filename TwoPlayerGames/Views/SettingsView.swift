import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = GameSettings.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Sound Effects", isOn: $settings.soundEnabled)
                    Toggle("Haptic Feedback", isOn: $settings.hapticsEnabled)
                } header: {
                    Text("General")
                }

                Section {
                    Stepper("Win Score: \(settings.pingPongWinScore)", value: $settings.pingPongWinScore, in: 1...15)

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
                } header: {
                    Text("Air Hockey")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.ticTacToeWinScore)", value: $settings.ticTacToeWinScore, in: 1...10)
                } header: {
                    Text("Tic Tac Toe")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.connectFourWinScore)", value: $settings.connectFourWinScore, in: 1...10)
                } header: {
                    Text("Connect Four")
                }

                Section {
                    Stepper("Win Score: \(settings.reactionTimeWinScore)", value: $settings.reactionTimeWinScore, in: 1...15)
                } header: {
                    Text("Reaction Time")
                }

                Section {
                    Stepper("Rounds to Win: \(settings.simonSaysWinScore)", value: $settings.simonSaysWinScore, in: 1...10)
                } header: {
                    Text("Simon Says")
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
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
