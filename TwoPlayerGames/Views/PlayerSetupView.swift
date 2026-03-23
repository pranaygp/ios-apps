import SwiftUI

struct PlayerSetupView: View {
    @EnvironmentObject var profileManager: PlayerProfileManager
    @Environment(\.dismiss) private var dismiss

    @State private var name1: String = ""
    @State private var name2: String = ""
    @State private var emoji1: String = ""
    @State private var emoji2: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    playerEditor(
                        label: "Player 1",
                        color: .blue,
                        name: $name1,
                        emoji: $emoji1
                    )

                    Divider()
                        .overlay(Color.white.opacity(0.1))

                    playerEditor(
                        label: "Player 2",
                        color: .red,
                        name: $name2,
                        emoji: $emoji2
                    )
                }
                .padding(24)
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmed1 = name1.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmed2 = name2.trimmingCharacters(in: .whitespacesAndNewlines)
                        profileManager.player1 = PlayerProfile(
                            name: trimmed1.isEmpty ? "Player 1" : trimmed1,
                            emoji: emoji1
                        )
                        profileManager.player2 = PlayerProfile(
                            name: trimmed2.isEmpty ? "Player 2" : trimmed2,
                            emoji: emoji2
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                name1 = profileManager.player1.name
                name2 = profileManager.player2.name
                emoji1 = profileManager.player1.emoji
                emoji2 = profileManager.player2.emoji
            }
        }
    }

    private func playerEditor(label: String, color: Color, name: Binding<String>, emoji: Binding<String>) -> some View {
        VStack(spacing: 16) {
            // Avatar
            Text(emoji.wrappedValue)
                .font(.system(size: 56))
                .frame(width: 88, height: 88)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .overlay(
                            Circle().stroke(color.opacity(0.3), lineWidth: 2)
                        )
                )

            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(2)

            // Name field
            TextField("Enter name", text: name)
                .font(.system(size: 18, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(color.opacity(0.2), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 240)

            // Emoji picker
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
                ForEach(PlayerProfile.availableEmojis, id: \.self) { e in
                    Button {
                        HapticManager.impact(.light)
                        emoji.wrappedValue = e
                    } label: {
                        Text(e)
                            .font(.system(size: 28))
                            .frame(width: 48, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(emoji.wrappedValue == e ? color.opacity(0.25) : Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(emoji.wrappedValue == e ? color.opacity(0.5) : Color.clear, lineWidth: 2)
                                    )
                            )
                    }
                }
            }
            .frame(maxWidth: 320)
        }
    }
}
