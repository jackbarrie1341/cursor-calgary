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
                buddyName: input.buddyName,
                displayName: input.displayName,
                username: input.normalizedUsername
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

    func getFriends() async throws -> [FriendBuddy] {
        let response: FriendsResponse = try await send(
            path: "/friends",
            method: "GET",
            body: Optional<EmptyBody>.none
        )
        return response.friends
    }

    func searchFriends(query: String) async throws -> [FriendSearchResult] {
        let response: FriendSearchResponse = try await send(
            path: "/friends/search",
            method: "GET",
            queryItems: [URLQueryItem(name: "q", value: query)],
            body: Optional<EmptyBody>.none
        )
        return response.results
    }

    func addFriend(username: String) async throws -> FriendBuddy {
        let response: AddFriendResponse = try await send(
            path: "/friends",
            method: "POST",
            body: AddFriendRequest(username: username)
        )
        return response.friend
    }

    func getSpending() async throws -> SpendingResponse {
        try await send(
            path: "/spending",
            method: "GET",
            body: Optional<EmptyBody>.none
        )
    }

    func updateCatColor(hue: Double, saturation: Double, brightness: Double) async throws {
        let _: BuddyState = try await send(
            path: "/profile/color",
            method: "PATCH",
            body: CatColorRequest(
                catFillHue: hue,
                catFillSaturation: saturation,
                catFillBrightness: brightness
            )
        )
    }

    func getHats() async throws -> HatsResponse {
        try await send(
            path: "/hats",
            method: "GET",
            body: Optional<EmptyBody>.none
        )
    }

    func updateEquippedHat(hatId: String?) async throws -> HatsResponse {
        try await send(
            path: "/hats/equipped",
            method: "PATCH",
            body: EquippedHatRequest(hatId: hatId)
        )
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Body?
    ) async throws -> Response {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw BackendError.invalidResponse
        }

        var request = URLRequest(url: url)
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
    let displayName: String
    let username: String
}

private struct ExchangePublicTokenRequest: Encodable {
    let publicToken: String
}

private struct AddFriendRequest: Encodable {
    let username: String
}

private struct CatColorRequest: Encodable {
    let catFillHue: Double
    let catFillSaturation: Double
    let catFillBrightness: Double
}

private struct EquippedHatRequest: Encodable {
    let hatId: String?

    enum CodingKeys: String, CodingKey {
        case hatId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let hatId {
            try container.encode(hatId, forKey: .hatId)
        } else {
            try container.encodeNil(forKey: .hatId)
        }
    }
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
