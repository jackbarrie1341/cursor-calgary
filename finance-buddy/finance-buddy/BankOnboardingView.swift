import SwiftUI

struct BankOnboardingView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect your bank")
                    .font(DoodleFont.largeTitle)
                    .doodleTracking(-1.2)
                Text("Use Plaid Sandbox to link a test account. Transactions will update your buddy’s mood.")
                    .font(DoodleFont.body)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 12) {
                Label("Choose a non-OAuth Sandbox institution.", systemImage: "building.columns")
                Label("Use user_transactions_dynamic with any password.", systemImage: "person.text.rectangle")
                Label("Refresh transactions later to simulate spending.", systemImage: "arrow.clockwise")
            }
            .font(DoodleFont.headline)

            Spacer()

            Button {
                Task {
                    await appState.connectBank()
                }
            } label: {
                Label("Connect with Plaid", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .font(DoodleFont.headline)
            .doodleTracking(-0.7)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
