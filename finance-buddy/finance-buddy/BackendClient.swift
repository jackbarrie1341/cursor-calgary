import Foundation

struct BackendClient {
    let baseURL: URL
    var accessToken: String?

    func getBuddy() async throws -> BuddyState {
        try await send(path: "/buddy", method: "GET", body: Optional<EmptyBody>.none)
    }

    func completeOnboarding(_ input: OnboardingInput) async throws -> BuddyState {
        try await send(
            path: "/onboarding",
            method: "POST",
            body: OnboardingRequest(
                monthlyIncomeCents: input.monthlyIncomeCents,
                monthlyBudgetCents: input.monthlyBudgetCents,
                buddyName: input.buddyName
            )
        )
    }

    func createLinkToken() async throws -> String {
        let response: LinkTokenResponse = try await send(
            path: "/plaid/create_link_token",
            method: "POST",
            body: EmptyBody()
        )
        return response.linkToken
    }

    func exchangePublicToken(_ publicToken: String) async throws -> BuddyState {
        try await send(
            path: "/plaid/exchange_public_token",
            method: "POST",
            body: ExchangePublicTokenRequest(publicToken: publicToken)
        )
    }

    func refreshTransactions() async throws {
        let _: EmptyResponse = try await send(
            path: "/transactions/refresh",
            method: "POST",
            body: EmptyBody()
        )
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Request failed"
            throw BackendError.server(statusCode: httpResponse.statusCode, message: message)
        }

        if data.isEmpty {
            return EmptyResponse() as! Response
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }
}

private struct OnboardingRequest: Encodable {
    let monthlyIncomeCents: Int
    let monthlyBudgetCents: Int
    let buddyName: String
}

private struct ExchangePublicTokenRequest: Encodable {
    let publicToken: String
}

private struct EmptyBody: Codable {}
private struct EmptyResponse: Codable {}

enum BackendError: LocalizedError {
    case invalidResponse
    case server(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The backend did not return an HTTP response."
        case let .server(statusCode, message):
            "Backend error \(statusCode): \(message)"
        }
    }
}
