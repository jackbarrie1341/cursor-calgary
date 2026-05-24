import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = OnboardingInput()
    @State private var step: OnboardingStep = .intro

    private var isCurrentStepValid: Bool {
        switch step {
        case .intro:
            true
        case .income:
            input.monthlyIncomeCents > 0
        case .budget:
            input.monthlyBudgetCents > 0
        case .buddy:
            !input.buddyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .friendCode:
            input.isUsernameValid
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.976, green: 0.961, blue: 0.925)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $step) {
                    ForEach(OnboardingStep.allCases) { step in
                        stepContent(for: step)
                            .tag(step)
                            .padding(.horizontal, 22)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy(duration: 0.28), value: step)

                bottomControls
            }
        }
        .font(DoodleFont.body)
        .doodleTracking()
        .onAppear {
            if input.username.isEmpty {
                input.username = suggestedUsername
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Set up Pawket")
                    .font(DoodleFont.title2)
                    .doodleTracking(-0.8)
                Spacer()
                Text("\(step.index + 1)/\(OnboardingStep.allCases.count)")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { item in
                    Capsule()
                        .fill(item.index <= step.index ? Color.accentColor : Color.black.opacity(0.12))
                        .frame(height: 7)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private func stepContent(for step: OnboardingStep) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                buddyStage(for: step)

                VStack(alignment: .leading, spacing: 14) {
                    Text(step.title)
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(step.subtitle)
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                inputPanel(for: step)
            }
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
    }

    private func buddyStage(for step: OnboardingStep) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.72))

            Circle()
                .fill(step.tint.opacity(0.18))
                .frame(width: 186, height: 186)
                .offset(x: 52, y: -6)

            BuddyImageView(
                mood: step.mood,
                overrideAssetName: nil,
                fallbackSymbolName: step.mood.symbolName,
                fallbackColor: step.tint,
                hatAssetKey: step.hatAssetKey,
                hatSymbolName: step.hatSymbolName,
                fillColor: Color(hue: 0.04, saturation: 0.48, brightness: 1.0),
                size: 178
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func inputPanel(for step: OnboardingStep) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            switch step {
            case .intro:
                infoRow(title: "Daily target", detail: "Your monthly budget becomes a simple daily allowance.")
                infoRow(title: "Buddy mood", detail: "Your cat reacts to how much of that allowance is used.")
                infoRow(title: "Private by default", detail: "Friends see mood and streaks, not transaction details.")
            case .income:
                moneyField(
                    title: "Monthly income",
                    detail: "This helps frame the setup. Your daily target comes from the spending budget next.",
                    value: $input.monthlyIncome
                )
            case .budget:
                moneyField(
                    title: "Monthly spending budget",
                    detail: "This is what Pawket divides across the month to set your daily target.",
                    value: $input.monthlyBudget
                )
            case .buddy:
                Text("Buddy name")
                    .font(DoodleFont.headline)
                TextField("Bean", text: $input.buddyName)
                    .textInputAutocapitalization(.words)
                    .textFieldStyle(.roundedBorder)
                    .font(DoodleFont.body)
                Text("You can change the cat color and hats later in settings.")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            case .friendCode:
                Text("Friend code")
                    .font(DoodleFont.headline)
                TextField("buddy_code", text: $input.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .font(DoodleFont.body)
                    .onChange(of: input.username) { _, newValue in
                        input.username = sanitizeUsername(newValue)
                    }
                Text("Use 3-20 lowercase letters, numbers, or underscores. Friends can add you with this code.")
                    .font(DoodleFont.caption)
                    .foregroundStyle(usernameHelpColor)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func moneyField(title: String, detail: String, value: Binding<Decimal>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(DoodleFont.headline)
            Text(detail)
                .font(DoodleFont.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField(title, value: value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .font(DoodleFont.title2)
        }
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

    private var bottomControls: some View {
        HStack(spacing: 12) {
            if step != .intro {
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        step = step.previous
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 46, height: 46)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Back")
            }

            Button {
                advance()
            } label: {
                Text(step == .friendCode ? "Finish setup" : "Continue")
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
            }
            .buttonStyle(.borderedProminent)
            .font(DoodleFont.headline)
            .doodleTracking(-0.7)
            .disabled(!isCurrentStepValid || appState.isLoading)
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .background(.ultraThinMaterial)
    }

    private var usernameHelpColor: Color {
        input.username.isEmpty || input.isUsernameValid ? .secondary : .red
    }

    private var suggestedUsername: String {
        let base = appState.currentUsername.isEmpty ? "buddy" : appState.currentUsername
        let sanitized = sanitizeUsername(base)
        return sanitized.count >= 3 ? sanitized : "buddy"
    }

    private func sanitizeUsername(_ value: String) -> String {
        let lowercased = value.lowercased()
        let allowed = lowercased.filter { character in
            character.isLetter || character.isNumber || character == "_"
        }
        return String(allowed.prefix(20))
    }

    private func advance() {
        guard isCurrentStepValid else { return }
        if step == .friendCode {
            input.displayName = appState.currentDisplayName
            Task {
                await appState.completeOnboarding(input)
            }
            return
        }

        withAnimation(.snappy(duration: 0.25)) {
            step = step.next
        }
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case intro
    case income
    case budget
    case buddy
    case friendCode

    var id: Int { rawValue }
    var index: Int { rawValue }

    var title: String {
        switch self {
        case .intro: "Meet your money buddy"
        case .income: "What comes in each month?"
        case .budget: "Set your spending lane"
        case .buddy: "Name your buddy"
        case .friendCode: "Choose your friend code"
        }
    }

    var subtitle: String {
        switch self {
        case .intro:
            "Pawket turns your budget into a cat mood you can understand at a glance."
        case .income:
            "Start with your usual monthly take-home income. This keeps the setup grounded."
        case .budget:
            "Pick the amount you want available for flexible spending each month."
        case .buddy:
            "This is the name you will see on the home screen, widgets, and Live Activity."
        case .friendCode:
            "Friends can find you by code. They only see your buddy mood and streak."
        }
    }

    var mood: BuddyMood {
        switch self {
        case .intro: .happy
        case .income: .sick
        case .budget: .nervous
        case .buddy: .happy
        case .friendCode: .sick
        }
    }

    var tint: Color {
        switch self {
        case .intro: Color(red: 0.30, green: 0.72, blue: 0.38)
        case .income: Color(red: 0.05, green: 0.62, blue: 0.30)
        case .budget: Color(red: 0.92, green: 0.58, blue: 0.20)
        case .buddy: Color(red: 0.35, green: 0.55, blue: 0.96)
        case .friendCode: Color(red: 0.54, green: 0.36, blue: 0.88)
        }
    }

    var hatAssetKey: String? {
        switch self {
        case .intro: "hat_party 1"
        case .income: "hat_yanknobrim"
        case .budget: "hat_headphones"
        case .buddy: "hat_santa"
        case .friendCode: "hat_joyboy"
        }
    }

    var hatSymbolName: String? {
        switch self {
        case .intro: "party.popper"
        case .income: "crown"
        case .budget: "heart"
        case .buddy: "graduationcap"
        case .friendCode: "sparkles"
        }
    }

    var next: OnboardingStep {
        OnboardingStep(rawValue: min(rawValue + 1, Self.allCases.count - 1)) ?? self
    }

    var previous: OnboardingStep {
        OnboardingStep(rawValue: max(rawValue - 1, 0)) ?? self
    }
}
