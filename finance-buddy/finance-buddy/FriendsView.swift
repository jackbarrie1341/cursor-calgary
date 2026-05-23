import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Friends")
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)
                    Text("Add buddies by code. Friends only see mood and streak.")
                        .font(DoodleFont.body)
                        .foregroundStyle(.secondary)
                }

                searchCard

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your buddy crew")
                        .font(DoodleFont.title2)
                        .doodleTracking(-0.9)

                    if appState.friends.isEmpty {
                        emptyState
                    } else {
                        ForEach(appState.friends) { friend in
                            FriendRow(friend: friend)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await appState.loadFriends()
        }
        .refreshable {
            await appState.loadFriends()
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find a buddy")
                .font(DoodleFont.headline)

            HStack {
                TextField("buddy_code", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task {
                            await appState.searchFriends(query: query)
                        }
                    }

                Button {
                    Task {
                        await appState.searchFriends(query: query)
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Search")
            }

            ForEach(appState.friendSearchResults) { result in
                HStack(spacing: 12) {
                    MoodBadge(mood: result.mood)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.displayName.isEmpty ? result.buddyName : result.displayName)
                            .font(DoodleFont.headline)
                        Text("@\(result.username) · \(result.buddyName)")
                            .font(DoodleFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(result.isFriend ? "Added" : "Add") {
                        Task {
                            await appState.addFriend(username: result.username)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(result.isFriend)
                }
                .padding(12)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No friends yet")
                .font(DoodleFont.headline)
            Text("Search for a buddy code to add someone. Dollar amounts never appear here.")
                .font(DoodleFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FriendRow: View {
    let friend: FriendBuddy

    var body: some View {
        HStack(spacing: 14) {
            MoodBadge(mood: friend.mood)

            VStack(alignment: .leading, spacing: 4) {
                Text(friend.buddyName)
                    .font(DoodleFont.title3)
                    .doodleTracking(-0.8)
                Text("@\(friend.username)")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(friend.mood.title)
                    .font(DoodleFont.headline)
                Label("\(friend.streak)", systemImage: "flame")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MoodBadge: View {
    let mood: BuddyMood

    var body: some View {
        Image(systemName: mood.symbolName)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 48, height: 48)
            .background(color.opacity(0.14), in: Circle())
    }

    private var color: Color {
        switch mood {
        case .happy: .green
        case .nervous: .yellow
        case .hungry: .orange
        case .sick: .red
        }
    }
}
