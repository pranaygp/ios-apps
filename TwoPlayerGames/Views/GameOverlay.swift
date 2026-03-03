import SwiftUI

struct GameOverlay: View {
    let onBack: () -> Void

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    HapticManager.impact(.light)
                    onBack()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)

                Spacer()
            }
            Spacer()
        }
    }
}

struct WinnerOverlay: View {
    let winner: Int
    let onPlayAgain: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("🏆")
                    .font(.system(size: 64))

                Text("Player \(winner) Wins!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 16) {
                    Button(action: onPlayAgain) {
                        Text("Play Again")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue)
                            )
                    }

                    Button(action: onExit) {
                        Text("Exit")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.white.opacity(0.15))
                            )
                    }
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.12))
            )
        }
    }
}
