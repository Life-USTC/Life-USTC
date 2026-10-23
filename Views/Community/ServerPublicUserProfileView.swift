import SwiftUI

@MainActor
struct ServerPublicUserProfileView: View {
    let identifier: String
    @Bindable private var account = ServerAccountStore.shared
    @State private var model = ServerPublicUserProfileModel()
    @State private var selectedDay: ServerPublicUserProfile.ContributionDay?

    var body: some View {
        List {
            if let profile = model.profile {
                Section {
                    HStack(spacing: 12) {
                        avatar(profile.user.image)
                            .frame(width: 48, height: 48)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.user.name ?? profile.user.username ?? "User".localized)
                                .font(.headline)
                            if let username = profile.user.username {
                                Text("@\(username)").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    LabeledContent("Joined", value: profile.user.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                Section("Contributions") {
                    LabeledContent("Comments", value: profile.user.counts.comments.formatted())
                    LabeledContent("Uploaded Files", value: profile.user.counts.uploads.formatted())
                    LabeledContent("Homework Created", value: profile.user.counts.homeworksCreated.formatted())
                    LabeledContent("Total Contributions", value: profile.totalContributions.formatted())
                }
                if !profile.weeks.isEmpty {
                    Section("Contribution History") {
                        ScrollView(.horizontal) {
                            HStack(alignment: .top, spacing: 4) {
                                ForEach(Array(profile.weeks.enumerated()), id: \.offset) { _, week in
                                    VStack(spacing: 4) {
                                        ForEach(week) { day in
                                            Button { selectedDay = day } label: {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(day.count > 0 ? Color.accentColor : Color.secondary.opacity(0.15))
                                                    .frame(width: 22, height: 22)
                                            }
                                            .buttonStyle(.plain)
                                            .accessibilityLabel(Text(contributionLabel(day)))
                                            .accessibilityIdentifier("contribution_day_\(day.date)")
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        if let selectedDay {
                            Text(contributionLabel(selectedDay)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else if model.isLoading {
                ProgressView("Loading profile…")
            }
            if let error = model.error {
                Section {
                    Text(error).font(.caption).foregroundStyle(.red)
                    Button("Retry") { Task { await model.load(identifier: identifier) } }
                        .accessibilityIdentifier("public_profile_retry")
                }
            }
        }
        .navigationTitle("Community Profile")
        .task(id: "\(identifier):\(account.sessionRevision)") {
            selectedDay = nil
            await model.load(identifier: identifier)
        }
        .refreshable { await model.load(identifier: identifier) }
    }

    @ViewBuilder
    private func avatar(_ image: String?) -> some View {
        if let image, let url = URL(string: image) {
            AsyncImage(url: url) { loaded in
                loaded.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
            }
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
        }
    }

    private func contributionLabel(_ day: ServerPublicUserProfile.ContributionDay) -> String {
        String(format: "%@: %@ contributions".localized, day.date, day.count.formatted())
    }
}

@MainActor @Observable
final class ServerPublicUserProfileModel {
    private let client: ServerClient
    private var revision: UUID?
    private var identifier: String?
    private var snapshot: ServerPublicUserProfile?
    private var loading = false
    private var failure: String?
    private var generation = 0

    init(client: ServerClient = .shared) { self.client = client }

    var profile: ServerPublicUserProfile? { revision == client.sessionRevision ? snapshot : nil }
    var isLoading: Bool { revision == client.sessionRevision && loading }
    var error: String? { revision == client.sessionRevision ? failure : nil }

    func load(identifier: String) async {
        if revision != client.sessionRevision || self.identifier != identifier { snapshot = nil }
        self.identifier = identifier
        revision = client.sessionRevision
        let expectedRevision = client.sessionRevision
        generation += 1
        let currentGeneration = generation
        loading = true
        failure = nil
        defer { if currentGeneration == generation { loading = false } }
        do {
            let profile = try await client.fetchPublicUserProfile(identifier: identifier)
            guard currentGeneration == generation, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            snapshot = profile
        } catch is CancellationError {
            return
        } catch {
            guard currentGeneration == generation, expectedRevision == client.sessionRevision, !Task.isCancelled else { return }
            failure = error.localizedDescription
        }
    }
}
