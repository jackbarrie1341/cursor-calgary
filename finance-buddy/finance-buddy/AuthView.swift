import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appState: AppState
    @State private var mode: AuthMode = .create
    @State private var input = AuthInput()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(mode.title)
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                    Text("Create an account with your email and password, then connect Plaid Sandbox.")
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                }

                Picker("Mode", selection: $mode) {
                    ForEach(AuthMode.allCases) { mode in
                        Text(mode.segmentTitle).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                VStack(spacing: 14) {
                    if mode == .create {
                        TextField("Your name", text: $input.name)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Email", text: $input.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)

                    SecureField("Password", text: $input.password)
                        .textContentType(mode == .create ? .newPassword : .password)
                        .textFieldStyle(.roundedBorder)
                }

                Button {
                    Task {
                        switch mode {
                        case .create:
                            await appState.signUp(input)
                        case .signIn:
                            await appState.signIn(input)
                        }
                    }
                } label: {
                    Label(mode.buttonTitle, systemImage: mode == .create ? "person.badge.plus" : "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .font(DoodleFont.headline)
                .doodleTracking(-0.7)
                .disabled(mode == .create ? !input.isValidForSignUp : !input.isValidForSignIn)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private enum AuthMode: String, CaseIterable, Identifiable {
    case create
    case signIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create: "Create your account"
        case .signIn: "Welcome back"
        }
    }

    var segmentTitle: String {
        switch self {
        case .create: "Create"
        case .signIn: "Log in"
        }
    }

    var buttonTitle: String {
        switch self {
        case .create: "Create account"
        case .signIn: "Log in"
        }
    }
}
