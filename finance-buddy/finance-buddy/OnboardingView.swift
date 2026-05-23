import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = OnboardingInput()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Set your daily allowance")
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                    Text("Finance Buddy turns your monthly budget into a daily target and reacts when spending changes.")
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 16) {
                    moneyQuestion(
                        title: "What is your monthly income?",
                        subtitle: "This helps frame the budget, but the buddy uses your spending budget.",
                        value: $input.monthlyIncome
                    )

                    moneyQuestion(
                        title: "What is your monthly spending budget?",
                        subtitle: "We divide this by the days in the month to set today’s allowance.",
                        value: $input.monthlyBudget
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your buddy code")
                            .font(DoodleFont.headline)
                        Text("Friends can add you with this. They will only see your buddy’s mood and streak.")
                            .font(DoodleFont.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("buddy_code", text: $input.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textFieldStyle(.roundedBorder)
                        Text("3–20 characters. Use lowercase letters, numbers, or underscore.")
                            .font(DoodleFont.caption)
                            .foregroundStyle(usernameHelpColor)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("What should your buddy be called?")
                            .font(DoodleFont.headline)
                        TextField("Buddy name", text: $input.buddyName)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Button {
                    input.displayName = appState.currentDisplayName
                    Task {
                        await appState.completeOnboarding(input)
                    }
                } label: {
                    Label("Continue to bank connection", systemImage: "arrow.right.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
                .disabled(
                    input.monthlyBudgetCents <= 0 ||
                    input.buddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    !input.isUsernameValid
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func moneyQuestion(title: String, subtitle: String, value: Binding<Decimal>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DoodleFont.headline)
            Text(subtitle)
                .font(DoodleFont.subheadline)
                .foregroundStyle(.secondary)
            TextField(title, value: value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var usernameHelpColor: Color {
        input.username.isEmpty || input.isUsernameValid ? .secondary : .red
    }
}
