import SwiftUI

struct BankOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            Color(red: 0.976, green: 0.961, blue: 0.925)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 18)

                buddyStage

                VStack(alignment: .leading, spacing: 14) {
                    Text("Let your buddy watch your spending")
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Connect your account so Pawket can update your daily budget status automatically.")
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    infoRow(title: "Automatic updates", detail: "Your buddy reacts when new spending comes in.")
                    infoRow(title: "Private with friends", detail: "Friends see mood and streaks, not your transaction list.")
                    infoRow(title: "You stay in control", detail: "You can refresh, disconnect, or sign out any time.")
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Spacer()

                Button {
                    Task {
                        await appState.connectBank()
                    }
                } label: {
                    Text("Choose my account")
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
                .disabled(appState.isLoading)

                Text("Pawket uses a secure connection provider. Your login details are not stored in the app.")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(22)
        }
        .font(DoodleFont.body)
        .doodleTracking()
    }

    private var buddyStage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.72))

            Circle()
                .fill(Color(red: 0.35, green: 0.55, blue: 0.96).opacity(0.18))
                .frame(width: 190, height: 190)
                .offset(x: 50, y: -8)

            BuddyImageView(
                mood: .happy,
                overrideAssetName: nil,
                fallbackSymbolName: BuddyMood.happy.symbolName,
                fallbackColor: Color(red: 0.30, green: 0.72, blue: 0.38),
                hatAssetKey: "Hat_Sprout",
                hatSymbolName: "leaf",
                size: 184
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 245)
        .accessibilityHidden(true)
    }

    private func infoRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 12, height: 12)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DoodleFont.headline)
                Text(detail)
                    .font(DoodleFont.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
