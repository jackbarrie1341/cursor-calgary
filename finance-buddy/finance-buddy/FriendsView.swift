import SwiftUI

struct FriendsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""
    @State private var isShowingSearch = false
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .center) {
                    Text("Friends")
                        .font(DoodleFont.largeTitle)
                        .doodleTracking(-1.2)

                    Spacer()

                    Button {
                        isShowingSearch = true
                    } label: {
                        Image("pawsearchlogo")
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 34, height: 34)
                            .frame(width: 48, height: 48)
                            .background(Color(.systemBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Find a buddy")
                }

                VStack(alignment: .leading, spacing: 12) {
                    if appState.friends.isEmpty {
                        emptyState
                    } else {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(appState.friends) { friend in
                                FriendCard(friend: friend)
                            }
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
        .sheet(isPresented: $isShowingSearch) {
            NavigationStack {
                searchCard
                    .padding()
                    .navigationTitle("Find a buddy")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                isShowingSearch = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    Image("pawsearchlogo")
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .frame(width: 34, height: 34)
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
            Text("Tap the paw button to add someone by buddy code.")
                .font(DoodleFont.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FriendCard: View {
    let friend: FriendBuddy

    var body: some View {
        VStack(spacing: 10) {
            Text(friend.buddyName)
                .font(DoodleFont.title3)
                .doodleTracking(-0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            BuddyImageView(
                mood: friend.mood,
                overrideAssetName: nil,
                fallbackSymbolName: friend.mood.symbolName,
                fallbackColor: friend.mood.color,
                hatAssetKey: friend.hatAssetKey,
                hatSymbolName: friend.hatSymbolName,
                fillColor: friend.catFillColor,
                size: 96
            )

            Text("@\(friend.username)")
                .font(DoodleFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(spacing: 8) {
                Text(friend.mood.title)
                    .font(DoodleFont.caption)
                    .foregroundStyle(friend.mood.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 4)

                Label("\(friend.streak)", systemImage: "flame")
                    .font(DoodleFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 212)
        .padding(16)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MoodBadge: View {
    let mood: BuddyMood

    var body: some View {
        Image(systemName: mood.symbolName)
            .font(.system(size: 26, weight: .semibold))
            .foregroundStyle(mood.color)
            .frame(width: 48, height: 48)
            .background(mood.color.opacity(0.14), in: Circle())
    }
}

private extension FriendBuddy {
    var catFillColor: Color {
        Color(
            hue: catFillHue ?? 0.04,
            saturation: catFillSaturation ?? 0.48,
            brightness: catFillBrightness ?? 1.0
        )
    }
}
