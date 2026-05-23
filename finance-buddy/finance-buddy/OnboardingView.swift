import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = OnboardingInput()

    var body: some View {
        Form {
            Section {
                DecimalField(title: "Monthly income", value: $input.monthlyIncome)
                DecimalField(title: "Monthly budget", value: $input.monthlyBudget)
                TextField("Buddy name", text: $input.buddyName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Button {
                    Task {
                        await appState.completeOnboarding(input)
                    }
                } label: {
                    Label("Start", systemImage: "checkmark.circle")
                }
                .disabled(input.monthlyBudgetCents <= 0 || input.buddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct DecimalField: View {
    let title: String
    @Binding var value: Decimal

    var body: some View {
        TextField(title, value: $value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
            .keyboardType(.decimalPad)
    }
}
