import SwiftUI

struct ThemePickerView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var statsManager: GameStatsManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Games played counter
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundStyle(themeManager.currentTheme.accentColor)
                        Text("\(statsManager.totalGamesPlayed) games played")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )

                    // Theme grid
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(ThemeManager.allThemes) { theme in
                            let unlocked = themeManager.isUnlocked(theme)
                            let selected = themeManager.currentTheme.id == theme.id

                            Button {
                                if unlocked {
                                    HapticManager.impact(.light)
                                    themeManager.selectTheme(theme)
                                }
                            } label: {
                                themeCard(theme: theme, unlocked: unlocked, selected: selected)
                            }
                            .buttonStyle(.plain)
                            .opacity(unlocked ? 1.0 : 0.6)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(white: 0.06).ignoresSafeArea())
            .navigationTitle("Themes")
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

    private func themeCard(theme: AppTheme, unlocked: Bool, selected: Bool) -> some View {
        VStack(spacing: 10) {
            // Color preview
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.primaryColor)
                    .frame(height: 40)
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.secondaryColor)
                    .frame(height: 40)
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.accentColor)
                    .frame(height: 40)
            }

            // Background preview strip
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.backgroundColor)
                .frame(height: 16)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )

            // Name + status
            HStack {
                Text(theme.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textColor)

                Spacer()

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.system(size: 16))
                } else if !unlocked {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.white.opacity(0.4))
                        .font(.system(size: 14))
                }
            }

            if !unlocked {
                Text("Play \(themeManager.gamesNeededToUnlock(theme)) more games")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    selected ? theme.accentColor.opacity(0.6) : Color.white.opacity(0.08),
                    lineWidth: selected ? 2 : 1
                )
        )
    }
}

// MARK: - Theme Unlock Toast

struct ThemeUnlockToast: View {
    let themeName: String
    let isVisible: Bool

    var body: some View {
        if isVisible {
            VStack {
                Spacer()

                HStack(spacing: 10) {
                    Text("\u{1F3A8}")
                        .font(.system(size: 22))
                    Text("New theme unlocked: \(themeName)!")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .padding(.bottom, 60)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isVisible)
        }
    }
}

#Preview {
    ThemePickerView()
        .preferredColorScheme(.dark)
        .environmentObject(ThemeManager.shared)
        .environmentObject(GameStatsManager.shared)
}
